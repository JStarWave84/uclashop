-- Migration: allow anonymous SELECT on active payment_accounts
-- So customers can see payment info at checkout

CREATE POLICY payment_accounts_public_select_active ON public.payment_accounts
  FOR SELECT
  USING ( is_active = true OR public.is_admin() );

COMMENT ON POLICY payment_accounts_public_select_active ON public.payment_accounts IS 'Anyone can view active payment accounts. Admins see all.';
