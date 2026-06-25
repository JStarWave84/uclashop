-- Migration: RPC function for anonymous order creation (SECURITY DEFINER)
-- Bypasses RLS on orders and order_items for checkout flow.

CREATE OR REPLACE FUNCTION public.place_order(
  p_total numeric,
  p_first_name text,
  p_last_name text,
  p_ci text,
  p_phone text,
  p_email text,
  p_payment_reference text DEFAULT NULL,
  p_items jsonb DEFAULT '[]',
  p_receipt_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  v_item jsonb;
  v_result jsonb;
BEGIN
  INSERT INTO public.orders (
    total, customer_first_name, customer_last_name, customer_ci,
    customer_phone, customer_email, payment_reference, payment_receipt_url
  ) VALUES (
    p_total, p_first_name, p_last_name, p_ci,
    p_phone, p_email, p_payment_reference, p_receipt_url
  )
  RETURNING id INTO v_order_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    INSERT INTO public.order_items (
      order_id, product_id, product_name_snapshot, price_snapshot, quantity
    ) VALUES (
      v_order_id,
      (v_item->>'product_id')::uuid,
      v_item->>'product_name_snapshot',
      (v_item->>'price_snapshot')::numeric,
      (v_item->>'quantity')::int
    );
  END LOOP;

  v_result := jsonb_build_object('id', v_order_id);
  RETURN v_result;
END;
$$;
