-- Migration: Allow supabase_auth_admin (GoTrue) to execute the ON DELETE
-- cascades triggered by auth.admin.deleteUser() on public tables that
-- reference users. Without these policies RLS blocks the cascade and GoTrue
-- returns "Database error deleting user".

-- GRANTs (idempotent by nature)
GRANT DELETE ON public.profiles TO supabase_auth_admin;
GRANT DELETE ON public.store_members TO supabase_auth_admin;
GRANT UPDATE ON public.stores TO supabase_auth_admin;

-- Policies (idempotent, guarded like existing migrations)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
      AND policyname = 'profiles_auth_admin_delete'
  ) THEN
    CREATE POLICY profiles_auth_admin_delete ON public.profiles
      FOR DELETE
      TO supabase_auth_admin
      USING (true);
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'store_members'
      AND policyname = 'store_members_auth_admin_delete'
  ) THEN
    CREATE POLICY store_members_auth_admin_delete ON public.store_members
      FOR DELETE
      TO supabase_auth_admin
      USING (true);
  END IF;
END$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'stores'
      AND policyname = 'stores_auth_admin_update'
  ) THEN
    CREATE POLICY stores_auth_admin_update ON public.stores
      FOR UPDATE
      TO supabase_auth_admin
      USING (true)
      WITH CHECK (true);
  END IF;
END$$;
