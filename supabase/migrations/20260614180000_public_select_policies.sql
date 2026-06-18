-- Migration: add public SELECT policies for shop-facing tables
-- Anonymous clients need to read sales_sessions (open ones) and
-- product_sessions to display jornada details in the shop.

-- sales_sessions: public can SELECT open sessions; admins see all
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'sales_sessions' AND policyname = 'sales_sessions_public_select'
  ) THEN
    CREATE POLICY sales_sessions_public_select ON public.sales_sessions
      FOR SELECT
      USING ( is_open = true OR public.is_admin() );
  END IF;
END$$;

-- product_sessions: public can SELECT product_ids linked to open sessions only
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'product_sessions' AND policyname = 'product_sessions_public_select'
  ) THEN
    CREATE POLICY product_sessions_public_select ON public.product_sessions
      FOR SELECT
      USING (
        public.is_admin()
        OR EXISTS (
          SELECT 1 FROM public.sales_sessions ss
          WHERE ss.id = session_id AND ss.is_open = true
        )
      );
  END IF;
END$$;
