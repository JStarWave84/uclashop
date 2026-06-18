-- Migration: create profiles backfill, FK and trigger to auto-create profiles
-- Filename: supabase/migrations/20260614120000_profiles_trigger.sql

-- Backfill existing auth.users into public.profiles (idempotent)
INSERT INTO public.profiles (id, full_name, role, created_at)
SELECT
  u.id,
  COALESCE(
    NULLIF(TRIM(COALESCE(u.raw_user_meta_data->>'full_name', '')), ''),
    u.email
  ) AS full_name,
  NULL AS role,
  now() as created_at
FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = u.id);

-- Add FK constraint profiles.id -> auth.users.id to enforce integrity
-- This will succeed because of the backfill above; if any orphan profiles exist, this will fail.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints tc
    JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name AND tc.table_schema = kcu.table_schema
    WHERE tc.table_schema = 'public' AND tc.table_name = 'profiles' AND tc.constraint_type = 'FOREIGN KEY' AND kcu.column_name = 'id'
  ) THEN
    ALTER TABLE IF EXISTS public.profiles
      ADD CONSTRAINT profiles_auth_user_fk
      FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
  END IF;
END$$;

-- Create the helper function in public schema to insert a profile when a new auth.user is created.
CREATE OR REPLACE FUNCTION public.handle_user_insert_create_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, created_at)
  VALUES (
    NEW.id,
    COALESCE(
      NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'full_name', '')), ''),
      NEW.email
    ),
    NULL,
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- Create trigger on auth.users AFTER INSERT to call the public function
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON t.tgrelid = c.oid
    JOIN pg_namespace n ON c.relnamespace = n.oid
    WHERE t.tgname = 'trigger_create_profile_on_user_insert' AND n.nspname = 'auth'
  ) THEN
    CREATE TRIGGER trigger_create_profile_on_user_insert
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_user_insert_create_profile();
  END IF;
END$$;

-- Notes: The function is SECURITY DEFINER so that it can run with sufficient privileges
-- when executed by the auth system. Role assignment defaults to NULL; change if you want a default role.
