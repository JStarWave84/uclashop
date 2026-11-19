-- Migration: stock en tienda vs. depósito
--
-- El stock existente (products.stock / product_variants.stock) PASA A SER el
-- stock en TIENDA, que es el único vendible en la web. Se agrega una columna
-- nueva para el stock en DEPÓSITO, que no está a la venta hasta transferirse.
--
-- NO se modifican tablas de órdenes ni la lógica de pedidos:
--   - order_items_before_insert_or_update valida contra products.stock /
--     product_variants.stock (tienda) -> sigue igual.
--   - decrement_stock_on_paid descuenta tienda -> sigue igual.
--   - place_order no se toca.
--
-- Con variantes, ambas cantidades se administran por variante y se propagan
-- al producto con el trigger de sincronización (ahora también depósito).

BEGIN;

-- ====================================================================
-- 1) Columnas nuevas (stock actual = tienda, depósito arranca en 0)
-- ====================================================================
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS stock_warehouse integer NOT NULL DEFAULT 0
  CHECK (stock_warehouse >= 0);

ALTER TABLE public.product_variants
  ADD COLUMN IF NOT EXISTS stock_warehouse integer NOT NULL DEFAULT 0
  CHECK (stock_warehouse >= 0);

COMMENT ON COLUMN public.products.stock IS
  'Stock disponible en tienda: es el único stock vendible en la web. El total físico es stock + stock_warehouse.';
COMMENT ON COLUMN public.products.stock_warehouse IS
  'Stock en depósito. No se puede vender en la web hasta transferirse a tienda.';
COMMENT ON COLUMN public.product_variants.stock IS
  'Stock en tienda de esta variante: es el único stock vendible en la web.';
COMMENT ON COLUMN public.product_variants.stock_warehouse IS
  'Stock en depósito de esta variante. No se puede vender hasta transferirse a tienda.';

-- ====================================================================
-- 2) Sincronización: el producto refleja también el depósito agregado
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
      ), 0),
      stock_warehouse = COALESCE((
        SELECT SUM(pv.stock_warehouse) FROM public.product_variants pv WHERE pv.product_id = v_product_id
      ), 0)
  WHERE p.id = v_product_id;

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.sync_product_variant_stock IS
  'Mantiene products.stock = SUM(variants.stock) (tienda) y products.stock_warehouse = SUM(variants.stock_warehouse) (depósito), además de has_variants.';

-- ====================================================================
-- 3) Transferencia atómica entre depósito y tienda
-- ====================================================================
CREATE OR REPLACE FUNCTION public.transfer_stock(
  p_product_id uuid,
  p_variant_id uuid,
  p_quantity integer,
  p_to_store boolean
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_product      public.products%ROWTYPE;
  v_variant      public.product_variants%ROWTYPE;
  v_store        integer;
  v_warehouse    integer;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = 'P0001';
  END IF;
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'La cantidad debe ser mayor que cero' USING ERRCODE = 'P0001';
  END IF;
  IF p_to_store IS NULL THEN
    RAISE EXCEPTION 'Dirección de transferencia inválida' USING ERRCODE = 'P0001';
  END IF;

  SELECT * INTO v_product FROM public.products WHERE id = p_product_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Producto no encontrado' USING ERRCODE = 'P0002';
  END IF;

  IF NOT (
    public.is_admin()
    OR public.is_verified_store_member(v_product.store_id)
  ) THEN
    RAISE EXCEPTION 'Sin permiso para transferir stock de este producto' USING ERRCODE = 'P0001';
  END IF;

  IF p_variant_id IS NOT NULL THEN
    SELECT * INTO v_variant
    FROM public.product_variants
    WHERE id = p_variant_id AND product_id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Variante no encontrada en este producto' USING ERRCODE = 'P0002';
    END IF;

    IF p_to_store THEN
      IF v_variant.stock_warehouse < p_quantity THEN
        RAISE EXCEPTION 'No hay suficiente stock en depósito (disponible: %)', v_variant.stock_warehouse USING ERRCODE = 'P0001';
      END IF;
      UPDATE public.product_variants
      SET stock = stock + p_quantity,
          stock_warehouse = stock_warehouse - p_quantity
      WHERE id = p_variant_id;
    ELSE
      IF v_variant.stock < p_quantity THEN
        RAISE EXCEPTION 'No hay suficiente stock en tienda (disponible: %)', v_variant.stock USING ERRCODE = 'P0001';
      END IF;
      UPDATE public.product_variants
      SET stock = stock - p_quantity,
          stock_warehouse = stock_warehouse + p_quantity
      WHERE id = p_variant_id;
    END IF;

    SELECT stock, stock_warehouse INTO v_store, v_warehouse
    FROM public.product_variants WHERE id = p_variant_id;
  ELSE
    IF v_product.has_variants THEN
      RAISE EXCEPTION 'Este producto tiene variantes: transferí el stock por variante' USING ERRCODE = 'P0001';
    END IF;

    IF p_to_store THEN
      IF v_product.stock_warehouse < p_quantity THEN
        RAISE EXCEPTION 'No hay suficiente stock en depósito (disponible: %)', v_product.stock_warehouse USING ERRCODE = 'P0001';
      END IF;
      UPDATE public.products
      SET stock = stock + p_quantity,
          stock_warehouse = stock_warehouse - p_quantity
      WHERE id = p_product_id;
    ELSE
      IF v_product.stock < p_quantity THEN
        RAISE EXCEPTION 'No hay suficiente stock en tienda (disponible: %)', v_product.stock USING ERRCODE = 'P0001';
      END IF;
      UPDATE public.products
      SET stock = stock - p_quantity,
          stock_warehouse = stock_warehouse + p_quantity
      WHERE id = p_product_id;
    END IF;

    SELECT stock, stock_warehouse INTO v_store, v_warehouse
    FROM public.products WHERE id = p_product_id;
  END IF;

  RETURN jsonb_build_object(
    'stock', v_store,
    'stock_warehouse', v_warehouse,
    'total', v_store + v_warehouse
  );
END;
$$;

COMMENT ON FUNCTION public.transfer_stock(uuid, uuid, integer, boolean) IS
  'Mueve cantidad entre depósito y tienda de forma atómica, por producto simple o por variante. Solo admin o miembro verificado de la tienda del producto.';

COMMIT;
