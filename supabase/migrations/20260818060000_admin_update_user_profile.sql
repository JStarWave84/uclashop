-- Migration: admin_update_user_profile
-- RPC SECURITY DEFINER para actualizar perfiles desde la edge function
-- admin-update-user. Al ejecutarse como definer salta RLS (puede editar a
-- cualquier usuario), pero mantiene el JWT del request: auth.uid() sigue
-- siendo el del caller, así el trigger protect_profile_role (que exige
-- is_admin() para asignar el rol 'admin') funciona correctamente.
--
-- Uso desde la edge function con adminContextClient (JWT del admin en
-- Authorization) para que auth.uid() sea el del admin.
-- - Admin: puede editar nombre y rol de cualquier usuario.
-- - Usuario no-admin: solo puede editar su propio nombre.

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