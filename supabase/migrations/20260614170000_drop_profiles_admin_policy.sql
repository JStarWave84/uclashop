-- Migration: remove recursive profiles_admin policy that calls public.is_admin()
-- This policy caused recursion because public.is_admin() selects from public.profiles
-- while public.profiles had an RLS policy that called public.is_admin() -> stack overflow.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'profiles_admin'
  ) THEN
    EXECUTE 'DROP POLICY IF EXISTS profiles_admin ON public.profiles';
  END IF;
END$$;

-- After this migration, rely on per-user policies (profiles_self_select/update/insert)
-- to allow the auth.uid() to be read/modified. Admins can be managed via service_role
-- operations or via a separate management function if necessary.
