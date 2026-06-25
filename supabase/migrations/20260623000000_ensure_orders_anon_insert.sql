-- Migration: fix orders INSERT for anonymous users by using auth.role() directly
-- The is_anon() function may not work correctly in all RLS contexts

DROP POLICY IF EXISTS orders_allow_insert_anonymous ON public.orders;

CREATE POLICY orders_allow_insert_anonymous ON public.orders
  FOR INSERT
  WITH CHECK ( auth.role() = 'anon' OR auth.role() = 'authenticated' );
