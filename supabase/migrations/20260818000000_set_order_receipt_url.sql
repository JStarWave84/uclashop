-- Migration: RPC to attach a receipt object path to an order after checkout upload.
-- SECURITY DEFINER so anonymous checkout clients can update orders.payment_receipt_url
-- without bypassing RLS on the rest of the orders table.

CREATE OR REPLACE FUNCTION public.set_order_receipt_url(
  p_order_id uuid,
  p_receipt_url text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.orders
  SET payment_receipt_url = p_receipt_url
  WHERE id = p_order_id;
END;
$$;