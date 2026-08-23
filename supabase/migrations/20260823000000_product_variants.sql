-- Migration: product variants (complex inventory)
-- - products.has_variants flag
-- - product_variants table: flexible JSONB attributes ({ "Color": "Rojo", "Talla": "M" }),
--   optional price override (null = use product price) and per-variant stock
--   (no CHECK >= 0 so backorder deductions at pay-time can go negative, mirroring
--   the documented products.stock behaviour).
-- - Sync trigger keeps products.stock = SUM(variants.stock) and maintains has_variants.
-- - Guard trigger blocks direct writes to products.stock while the product has variants.
-- - Drops products_stock_check so oversold backorders can actually be marked paid
--   (previously the CHECK >= 0 made decrement fail and blocked the status update).

-- ====================================================================
-- 1) products.has_variants + remove stock CHECK (backorders may go negative)
-- ====================================================================
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS has_variants boolean NOT NULL DEFAULT false;

ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_stock_check;

COMMENT ON COLUMN public.products.has_variants IS 'True when the product is sold via product_variants; stock is managed per variant.';

-- ====================================================================
-- 2) product_variants
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.product_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  attributes jsonb NOT NULL DEFAULT '{}'::jsonb,
  price numeric(12,2) CHECK (price IS NULL OR price >= 0),
  stock integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, attributes)
);

CREATE INDEX IF NOT EXISTS idx_product_variants_product_id ON public.product_variants(product_id);

COMMENT ON TABLE public.product_variants IS 'Sellable variants of a product (e.g. color/size combos). Each variant owns its stock and optional price.';
COMMENT ON COLUMN public.product_variants.attributes IS 'Attribute map, e.g. {"Color": "Rojo", "Talla": "M"}. Unique per product.';
COMMENT ON COLUMN public.product_variants.price IS 'Optional price override; NULL means use products.price.';
COMMENT ON COLUMN public.product_variants.stock IS 'Stock for this variant only. May go negative for allowed backorders.';

-- ====================================================================
-- 3) Sync trigger: products.stock = SUM(product_variants.stock),
--    has_variants = EXISTS(any variant)
-- ====================================================================
CREATE OR REPLACE FUNCTION public.sync_product_variant_stock()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_product_id uuid;
BEGIN
  v_product_id := COALESCE(NEW.product_id, OLD.product_id);

  UPDATE public.products p
  SET has_variants = EXISTS (
        SELECT 1 FROM public.product_variants pv WHERE pv.product_id = v_product_id
      ),
      stock = COALESCE((
        SELECT SUM(pv.stock) FROM public.product_variants pv WHERE pv.product_id = v_product_id
      ), 0)
  WHERE p.id = v_product_id;

  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_product_variants_sync_stock
AFTER INSERT OR UPDATE OR DELETE ON public.product_variants
FOR EACH ROW
EXECUTE FUNCTION public.sync_product_variant_stock();

COMMENT ON FUNCTION public.sync_product_variant_stock IS 'Keeps products.stock equal to the sum of its variant stocks and maintains products.has_variants. Runs as definer so any permitted variant write propagates regardless of caller RLS on products.';

-- ====================================================================
-- 4) Guard: while a product has variants, products.stock can only be written
--    with the exact current variant sum (i.e. by the sync trigger / admin ops).
-- ====================================================================
CREATE OR REPLACE FUNCTION public.guard_products_stock_with_variants()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_expected integer;
BEGIN
  IF NEW.has_variants AND NEW.stock IS DISTINCT FROM OLD.stock THEN
    SELECT COALESCE(SUM(stock), 0) INTO v_expected
    FROM public.product_variants
    WHERE product_id = NEW.id;

    IF NEW.stock IS DISTINCT FROM v_expected THEN
      RAISE EXCEPTION 'El stock de un producto con variantes se administra por variante (total actual: %)', v_expected;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_products_guard_variant_stock
BEFORE UPDATE ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.guard_products_stock_with_variants();

COMMENT ON FUNCTION public.guard_products_stock_with_variants IS 'Prevents manual drift of products.stock while the product has variants; only writes matching SUM(variants.stock) are accepted.';

-- ====================================================================
-- 5) RLS (mirrors products policies)
-- ====================================================================
ALTER TABLE public.product_variants ENABLE ROW LEVEL SECURITY;

CREATE POLICY product_variants_public_select ON public.product_variants
  FOR SELECT
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.products p
      JOIN public.stores s ON s.id = p.store_id
      WHERE p.id = product_variants.product_id
        AND p.is_active
        AND s.is_verified
    )
  );

CREATE POLICY product_variants_admin_all ON public.product_variants
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

CREATE POLICY product_variants_store_all ON public.product_variants
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = product_variants.product_id
        AND p.store_id = public.my_store_id()
        AND public.is_verified_store_member(p.store_id)
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.products p
      WHERE p.id = product_variants.product_id
        AND p.store_id = public.my_store_id()
        AND public.is_verified_store_member(p.store_id)
    )
  );
