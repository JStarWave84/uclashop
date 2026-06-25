-- Migration: make refresh_order_payment_account SECURITY DEFINER
-- Allows the trigger to UPDATE orders even when called by anonymous users at checkout.
-- Without this, RLS blocks the UPDATE because anonymous users have INSERT-only on orders.

CREATE OR REPLACE FUNCTION public.refresh_order_payment_account(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_payment_account uuid;
BEGIN
  SELECT ppa.payment_account_id
  INTO v_payment_account
  FROM public.order_items oi
  JOIN public.product_payment_accounts ppa ON ppa.product_id = oi.product_id AND ppa.is_primary
  WHERE oi.order_id = p_order_id
  LIMIT 1;

  IF v_payment_account IS NULL THEN
    SELECT id INTO v_payment_account FROM public.payment_accounts
      WHERE is_active = true ORDER BY created_at LIMIT 1;
  END IF;

  IF v_payment_account IS DISTINCT FROM (SELECT payment_account_id FROM public.orders WHERE id = p_order_id) THEN
    UPDATE public.orders SET payment_account_id = v_payment_account WHERE id = p_order_id;
  END IF;
END;
$$;
