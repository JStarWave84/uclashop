-- Migration: per-product WhatsApp contact number + remove global payment_settings
-- - Adds products.contact_phone (WhatsApp contact per product)
-- - get_order_for_confirmation now returns contact_phone per item
-- - Drops the global payment_settings table (replaced by per-product contact numbers)

-- 1) Per-product contact number (WhatsApp)
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS contact_phone text;

COMMENT ON COLUMN public.products.contact_phone IS 'WhatsApp contact number for this product (used to send orders via WhatsApp).';

-- 2) Include contact_phone in the order confirmation payload
CREATE OR REPLACE FUNCTION public.get_order_for_confirmation(
  p_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_order jsonb;
  v_items jsonb;
BEGIN
  SELECT to_jsonb(o.*)
  INTO v_order
  FROM public.orders o
  WHERE o.id = p_order_id;

  IF v_order IS NULL THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      to_jsonb(oi.*) || jsonb_build_object('contact_phone', p.contact_phone)
      ORDER BY oi.created_at
    ),
    '[]'::jsonb
  )
  INTO v_items
  FROM public.order_items oi
  LEFT JOIN public.products p ON p.id = oi.product_id
  WHERE oi.order_id = p_order_id;

  RETURN jsonb_build_object(
    'order', v_order,
    'items', v_items
  );
END;
$$;

-- 3) Drop global payment settings (no longer used)
DROP TABLE IF EXISTS public.payment_settings;