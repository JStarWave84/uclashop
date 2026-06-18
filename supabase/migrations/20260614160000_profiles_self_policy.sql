-- Migration: allow users to select/update their own profile to avoid recursion in public.is_admin()

-- Create SELECT policy for a user to read their own profile
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'profiles_self_select'
  ) THEN
    CREATE POLICY profiles_self_select ON public.profiles
      FOR SELECT
      USING ( id = auth.uid()::uuid );
  END IF;
END$$;

-- Allow users to update their own profile (if desired)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'profiles_self_update'
  ) THEN
    CREATE POLICY profiles_self_update ON public.profiles
      FOR UPDATE
      USING ( id = auth.uid()::uuid )
      WITH CHECK ( id = auth.uid()::uuid );
  END IF;
END$$;

-- Allow users to insert their own profile (useful when auth creates users)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'public' AND tablename = 'profiles' AND policyname = 'profiles_insert_self'
  ) THEN
    CREATE POLICY profiles_insert_self ON public.profiles
      FOR INSERT
      WITH CHECK ( id = auth.uid()::uuid );
  END IF;
END$$;
