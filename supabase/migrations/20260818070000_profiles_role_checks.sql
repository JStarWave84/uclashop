-- Migration: profiles role invariants
-- - Normalize + CHECK constraint on profiles.role (NULL | 'admin' | 'store')
-- - Protect the last admin from being demoted or deleted
-- - Validate p_role in admin_update_user_profile

BEGIN;

-- 1) Normalize any unexpected role values before adding the constraint
UPDATE public.profiles
SET role = NULL
WHERE role IS NOT NULL AND role NOT IN ('admin', 'store');

-- 2) CHECK constraint: only NULL, 'admin' or 'store' are valid
ALTER TABLE public.profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IS NULL OR role IN ('admin', 'store'));

-- 3) Protect the last admin from demotion
CREATE OR REPLACE FUNCTION public.protect_last_admin_role()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF OLD.role = 'admin'
     AND NEW.role IS DISTINCT FROM 'admin'
     AND (SELECT count(*) FROM public.profiles WHERE role = 'admin') <= 1 THEN
    RAISE EXCEPTION 'No se puede quitar el último administrador';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_protect_last_admin ON public.profiles;
CREATE TRIGGER trg_profiles_protect_last_admin
  BEFORE UPDATE OF role ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_last_admin_role();

-- 4) Protect the last admin from deletion. Fires via ON DELETE CASCADE when
--    the corresponding auth.users row is deleted (e.g. GoTrue admin API).
CREATE OR REPLACE FUNCTION public.protect_last_admin_delete()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF OLD.role = 'admin'
     AND (SELECT count(*) FROM public.profiles WHERE role = 'admin') <= 1 THEN
    RAISE EXCEPTION 'No se puede eliminar el último administrador';
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_protect_delete_admin ON public.profiles;
CREATE TRIGGER trg_profiles_protect_delete_admin
  BEFORE DELETE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_last_admin_delete();

-- 5) Harden admin_update_user_profile: only valid roles can be assigned
CREATE OR REPLACE FUNCTION public.admin_update_user_profile(
  p_user_id uuid,
  p_full_name text DEFAULT NULL,
  p_role text DEFAULT NULL,
  p_set_role boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_is_admin boolean := public.is_admin();
  v_is_self boolean := auth.uid() = p_user_id;
BEGIN
  IF NOT v_is_admin AND NOT v_is_self THEN
    RAISE EXCEPTION 'No tenés permiso para editar este usuario' USING ERRCODE = 'P0001';
  END IF;

  IF p_set_role AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Solo un administrador puede cambiar el rol' USING ERRCODE = 'P0001';
  END IF;

  IF p_set_role AND p_role IS NOT NULL AND p_role NOT IN ('admin', 'store') THEN
    RAISE EXCEPTION 'Rol inválido' USING ERRCODE = 'P0001';
  END IF;

  IF p_full_name IS NOT NULL THEN
    UPDATE public.profiles
    SET full_name = p_full_name
    WHERE id = p_user_id;
  END IF;

  IF p_set_role AND v_is_admin THEN
    UPDATE public.profiles
    SET role = p_role
    WHERE id = p_user_id;
  END IF;
END;
$$;

COMMIT;