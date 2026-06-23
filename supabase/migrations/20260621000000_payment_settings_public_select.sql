-- Migration: allow public SELECT on payment_settings
-- Anonymous customers need to read global fallback payment info at checkout

CREATE POLICY payment_settings_public_select ON public.payment_settings
  FOR SELECT
  USING (true);
