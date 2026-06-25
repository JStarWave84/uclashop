-- Migration: use auth.role() directly in orders INSERT policy
-- The is_anon() helper may not evaluate correctly in all RLS contexts

DROP POLICY IF EXISTS orders_allow_insert_anonymous ON public.orders;

CREATE POLICY orders_allow_insert_anonymous ON public.orders
  FOR INSERT
  WITH CHECK ( auth.role() = 'anon' OR auth.role() = 'authenticated' );
