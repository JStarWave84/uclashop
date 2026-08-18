-- Migration: admin-managed users
-- - admin_add_store_member(user_id, store_id, role_in_store): admin can add
--   any existing user to any store (including the admin's own store).
-- - admin_remove_store_member(user_id): admin removes a user from any store.
-- - admin_list_users(): admin lists all auth users with profile + membership.
-- All are SECURITY DEFINER and only callable by is_admin().

BEGIN;

-- ====================================================================
-- 1) admin_add_store_member: admin adds a user to any store
-- ====================================================================
CREATE OR REPLACE FUNCTION public.admin_add_store_member(
  p_user_id uuid,
  p_store_id uuid,
  p_role_in_store text DEFAULT 'staff'
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede asignar miembros' USING ERRCODE = 'P0001';
  END IF;

  IF p_role_in_store IS NULL OR p_role_in_store NOT IN ('owner', 'staff') THEN
    RAISE EXCEPTION 'Rol inválido' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.stores WHERE id = p_store_id) THEN
    RAISE EXCEPTION 'La tienda no existe' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'El usuario no existe' USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (SELECT 1 FROM public.store_members WHERE user_id = p_user_id) THEN
    RAISE EXCEPTION 'Ese usuario ya pertenece a una tienda' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.store_members (store_id, user_id, role_in_store)
  VALUES (p_store_id, p_user_id, p_role_in_store);

  -- Members get the 'store' profile role so they can reach /tienda/*
  UPDATE public.profiles SET role = 'store' WHERE id = p_user_id AND role IS NULL;
END;
$$;

-- ====================================================================
-- 2) admin_remove_store_member: admin removes a user from any store
-- ====================================================================
CREATE OR REPLACE FUNCTION public.admin_remove_store_member(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede remover miembros' USING ERRCODE = 'P0001';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.store_members WHERE user_id = p_user_id) THEN
    RAISE EXCEPTION 'Ese usuario no pertenece a ninguna tienda' USING ERRCODE = 'P0001';
  END IF;

  DELETE FROM public.store_members WHERE user_id = p_user_id;
END;
$$;

-- ====================================================================
-- 3) admin_list_users: admin lists users with profile + membership
-- ====================================================================
CREATE OR REPLACE FUNCTION public.admin_list_users()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo un administrador puede listar usuarios' USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'user_id', u.id,
      'email', u.email,
      'full_name', p.full_name,
      'role', p.role,
      'store_id', sm.store_id,
      'store_name', s.name,
      'store_slug', s.slug,
      'role_in_store', sm.role_in_store,
      'created_at', p.created_at
    ) ORDER BY u.email
  ), '[]'::jsonb)
  INTO v_result
  FROM auth.users u
  LEFT JOIN public.profiles p ON p.id = u.id
  LEFT JOIN public.store_members sm ON sm.user_id = u.id
  LEFT JOIN public.stores s ON s.id = sm.store_id;

  RETURN v_result;
END;
$$;

COMMIT;