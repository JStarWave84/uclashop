-- Migration: drop deliveries feature
-- The deliveries section was removed from the admin dashboard and no code
-- creates delivery records, so the table and its RLS policy are no longer used.

DROP POLICY IF EXISTS deliveries_admin ON public.deliveries;
DROP TABLE IF EXISTS public.deliveries;