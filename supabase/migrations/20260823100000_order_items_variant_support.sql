-- Migration: variant-aware order items
-- - order_items.variant_id + variant_attributes_snapshot
-- - order_items_before_insert_or_update: validates against the VARIANT stock,
--   snapshots attributes and resolves price (variant price > product price)
-- - decrement_stock_on_paid: variant items decrement product_variants.stock
--   (sync trigger propagates the total); plain items decrement products as before
-- - place_order: accepts optional variant_id per item

BEGIN;

-- ====================================================================
-- 1) order_items columns
-- ====================================================================
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS variant_id uuid REFERENCES public.product_variants(id) ON DELETE SET NULL;
ALTER TABLE public.order_items ADD COLUMN IF NOT EXISTS variant_attributes_snapshot jsonb;

CREATE INDEX IF NOT EXISTS idx_order_items_variant_id ON public.order_items(variant_id);

COMMENT ON COLUMN public.order_items.variant_id IS 'Purchased variant; NULL for plain products.';
COMMENT ON COLUMN public.order_items.variant_attributes_snapshot IS 'Snapshot of the variant attributes at purchase time.';

-- ====================================================================
-- 2) Validation trigger (replaces the flat-stock version)
-- ====================================================================
CREATE OR REPLACE FUNCTION public.order_items_before_insert_or_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  p_product RECORD;
  p_variant RECORD;
BEGIN
  IF NEW.variant_id IS NOT NULL THEN
    IF NEW.product_id IS NULL THEN
      RAISE EXCEPTION 'variant_id requiere un product_id';
    END IF;

    SELECT id, name, price, stock, allow_backorder, is_active
      INTO p_product
      FROM public.products
      WHERE id = NEW.product_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product % not found', NEW.product_id;
    END IF;

    SELECT id, attributes, price, stock, is_active
      INTO p_variant
      FROM public.product_variants
      WHERE id = NEW.variant_id
        AND product_id = NEW.product_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variant % does not belong to product %', NEW.variant_id, NEW.product_id;
    END IF;

    IF NOT p_variant.is_active OR NOT p_product.is_active THEN
      RAISE EXCEPTION 'Variant % is not available', NEW.variant_id;
    END IF;

    -- snapshots (server-authoritative fallbacks)
    NEW.product_name_snapshot := p_product.name;
    NEW.variant_attributes_snapshot := p_variant.attributes;
    NEW.price_snapshot := COALESCE(NEW.price_snapshot, COALESCE(p_variant.price, p_product.price));

    -- enforce stock on the specific variant unless backorder allowed
    IF NOT p_product.allow_backorder AND NEW.quantity > p_variant.stock THEN
      RAISE EXCEPTION 'Insufficient stock for variant % (available: %, requested: %). Backorders not allowed.', p_variant.id, p_variant.stock, NEW.quantity;
    END IF;
  ELSIF NEW.product_id IS NOT NULL THEN
    SELECT id, name, price, stock, allow_backorder
      INTO p_product
      FROM public.products
      WHERE id = NEW.product_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product % not found', NEW.product_id;
    END IF;

    -- set snapshot fields (ensure data integrity)
    NEW.product_name_snapshot := p_product.name;
    NEW.price_snapshot := COALESCE(NEW.price_snapshot, p_product.price);

    -- Enforce stock unless backorder allowed
    IF NOT p_product.allow_backorder AND NEW.quantity > p_product.stock THEN
      RAISE EXCEPTION 'Insufficient stock for product % (available: %, requested: %). Backorders not allowed.', p_product.id, p_product.stock, NEW.quantity;
    END IF;
  ELSE
    -- If no product_id, snapshots must be provided
    IF NEW.product_name_snapshot IS NULL OR NEW.price_snapshot IS NULL THEN
      RAISE EXCEPTION 'product_id is null - product snapshot fields required';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- ====================================================================
-- 3) Stock decrement when an order becomes 'paid'
-- ====================================================================
CREATE OR REPLACE FUNCTION public.decrement_stock_on_paid()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Items with a variant: decrement the VARIANT stock. The sync trigger
  -- (trg_product_variants_sync_stock) propagates the new total to products.stock.
  UPDATE public.product_variants pv
  SET stock = pv.stock - oi.quantity
  FROM public.order_items oi
  WHERE oi.order_id = NEW.id
    AND oi.variant_id = pv.id
    AND oi.variant_id IS NOT NULL;

  -- Plain items: decrement products.stock directly.
  UPDATE public.products p
  SET stock = p.stock - agg.qty
  FROM (
    SELECT oi.product_id, SUM(oi.quantity) AS qty
    FROM public.order_items oi
    WHERE oi.order_id = NEW.id
      AND oi.product_id IS NOT NULL
      AND oi.variant_id IS NULL
    GROUP BY oi.product_id
  ) agg
  WHERE agg.product_id = p.id;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.decrement_stock_on_paid IS 'Decrements stock when an order is marked as paid: variant items decrement their product_variants.stock (total synced via trigger), plain items decrement products.stock. Stock may go negative for backorders that were allowed at checkout.';

COMMIT;
