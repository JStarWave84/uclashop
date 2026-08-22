-- Migration: Exempt internal roles from the store protection trigger.
--
-- The trg_stores_protect_verification trigger raises an exception whenever
-- stores.created_by changes without an admin context. When GoTrue deletes an
-- auth user (supabase_auth_admin), the FK `stores_created_by_fkey
-- ON DELETE SET NULL` performs that UPDATE and the trigger aborts the whole
-- deletion with "Database error deleting user".
--
-- Internal roles (supabase_auth_admin, service_role) are trusted system
-- roles; client-facing roles keep the existing protection.

CREATE OR REPLACE FUNCTION public.protect_store_verification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (NEW.is_verified IS DISTINCT FROM OLD.is_verified
      OR NEW.is_active IS DISTINCT FROM OLD.is_active
      OR NEW.created_by IS DISTINCT FROM OLD.created_by)
     AND NOT public.is_admin()
     AND session_user NOT IN ('supabase_auth_admin', 'service_role') THEN
    RAISE EXCEPTION 'Solo el Centro de Estudiantes puede cambiar la verificación o el estado de una tienda';
  END IF;
  RETURN NEW;
END;
$$;
