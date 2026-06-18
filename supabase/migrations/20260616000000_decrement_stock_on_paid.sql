-- Migration: decrement product stock when order status changes to 'paid'
-- Trigger fires BEFORE UPDATE only when status transitions TO 'paid'

CREATE OR REPLACE FUNCTION public.decrement_stock_on_paid()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.products p
  SET stock = p.stock - oi.quantity
  FROM public.order_items oi
  WHERE oi.order_id = NEW.id
    AND oi.product_id = p.id
    AND oi.product_id IS NOT NULL;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orders_decrement_stock_on_paid
BEFORE UPDATE ON public.orders
FOR EACH ROW
WHEN (NEW.status = 'paid' AND OLD.status IS DISTINCT FROM 'paid')
EXECUTE FUNCTION public.decrement_stock_on_paid();

COMMENT ON FUNCTION public.decrement_stock_on_paid IS 'Decrements products.stock by order_items.quantity when an order is marked as paid. Stock may go negative for backorders that were allowed at checkout.';
