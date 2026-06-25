-- Migration: fix anonymous INSERT on orders by removing FOR ALL policy
-- FOR ALL WITH CHECK (is_admin()) blocks anonymous INSERT.
-- Admin-only SELECT/UPDATE/DELETE are handled by separate policies.

DROP POLICY IF EXISTS orders_admin_all ON public.orders;
DROP POLICY IF EXISTS orders_insert_admin ON public.orders;

CREATE POLICY orders_select_admin ON public.orders
  FOR SELECT
  USING (public.is_admin());

CREATE POLICY orders_update_admin ON public.orders
  FOR UPDATE
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY orders_delete_admin ON public.orders
  FOR DELETE
  USING (public.is_admin());
