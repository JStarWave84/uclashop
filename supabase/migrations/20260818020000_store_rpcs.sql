-- Migration: store registration + membership RPCs
-- - Updated handle_user_insert_create_profile: role = 'store' when signup
--   metadata includes account_type = 'store'
-- - create_store(...): SECURITY DEFINER, called right after auth.signUp.
--   Creates the store + owner membership. Profile role is already set by the
--   auth trigger from metadata.
-- - add_store_member(email) / remove_store_member(user_id): owner only.

BEGIN;

-- ====================================================================
-- 1) Profile trigger: assign role based on signup metadata
-- ====================================================================
CREATE OR REPLACE FUNCTION public.handle_user_insert_create_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role, created_at)
  VALUES (
    NEW.id,
    COALESCE(
      NULLIF(TRIM(COALESCE(NEW.raw_user_meta_data->>'full_name', '')), ''),
      NEW.email
    ),
    CASE WHEN NEW.raw_user_meta_data->>'account_type' = 'store' THEN 'store' ELSE NULL END,
    now()
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

-- ====================================================================
-- 2) create_store: called by the new store user after signUp
-- ====================================================================
CREATE OR REPLACE FUNCTION public.create_store(
  p_name text,
  p_slug text,
  p_description text DEFAULT NULL,
  p_phone text DEFAULT NULL,
  p_logo_path text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_store_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (SELECT 1 FROM public.stores WHERE slug = p_slug) THEN
    RAISE EXCEPTION 'El slug ya está en uso' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.stores (name, slug, description, phone, logo_path, is_verified, is_active, created_by)
  VALUES (p_name, p_slug, p_description, p_phone, p_logo_path, false, true, auth.uid()::uuid)
  RETURNING id INTO v_store_id;

  INSERT INTO public.store_members (store_id, user_id, role_in_store)
  VALUES (v_store_id, auth.uid()::uuid, 'owner');

  UPDATE public.profiles SET role = 'store' WHERE id = auth.uid()::uuid AND role IS NULL;

  RETURN v_store_id;
END;
$$;

-- ====================================================================
-- 3) add_store_member: owner invites an existing registered user by email
-- ====================================================================
CREATE OR REPLACE FUNCTION public.add_store_member(p_email text)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_store_id uuid;
  v_role text;
  v_user_id uuid;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = 'P0001';
  END IF;

  v_store_id := public.my_store_id();
  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'No pertenecés a una tienda' USING ERRCODE = 'P0001';
  END IF;

  SELECT role_in_store INTO v_role
  FROM public.store_members
  WHERE store_id = v_store_id AND user_id = auth.uid()::uuid;

  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Solo el dueño puede invitar miembros' USING ERRCODE = 'P0001';
  END IF;

  SELECT id INTO v_user_id FROM auth.users WHERE email = p_email;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No existe una cuenta registrada con ese correo' USING ERRCODE = 'P0001';
  END IF;

  IF EXISTS (SELECT 1 FROM public.store_members WHERE user_id = v_user_id) THEN
    RAISE EXCEPTION 'Ese usuario ya pertenece a una tienda' USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.store_members (store_id, user_id, role_in_store)
  VALUES (v_store_id, v_user_id, 'staff');

  RETURN v_user_id;
END;
$$;

-- ====================================================================
-- 4) remove_store_member: owner removes staff (cannot remove themselves)
-- ====================================================================
CREATE OR REPLACE FUNCTION public.remove_store_member(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_store_id uuid;
  v_role text;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = 'P0001';
  END IF;

  IF p_user_id = auth.uid()::uuid THEN
    RAISE EXCEPTION 'No podés removerte a vos mismo' USING ERRCODE = 'P0001';
  END IF;

  v_store_id := public.my_store_id();
  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'No pertenecés a una tienda' USING ERRCODE = 'P0001';
  END IF;

  SELECT role_in_store INTO v_role
  FROM public.store_members
  WHERE store_id = v_store_id AND user_id = auth.uid()::uuid;

  IF v_role IS DISTINCT FROM 'owner' THEN
    RAISE EXCEPTION 'Solo el dueño puede remover miembros' USING ERRCODE = 'P0001';
  END IF;

  DELETE FROM public.store_members
  WHERE store_id = v_store_id AND user_id = p_user_id;
END;
$$;

-- ====================================================================
-- 5) get_store_members: members list with email + name for the caller's store
--    (profiles is not readable by store users via RLS, so this is a
--     SECURITY DEFINER helper scoped to the caller's own store)
-- ====================================================================
CREATE OR REPLACE FUNCTION public.get_store_members()
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_store_id uuid;
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'No autenticado' USING ERRCODE = 'P0001';
  END IF;

  v_store_id := public.my_store_id();
  IF v_store_id IS NULL THEN
    RAISE EXCEPTION 'No pertenecés a una tienda' USING ERRCODE = 'P0001';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'user_id', sm.user_id,
      'role_in_store', sm.role_in_store,
      'full_name', p.full_name,
      'email', u.email,
      'created_at', sm.created_at
    ) ORDER BY sm.created_at
  ), '[]'::jsonb)
  INTO v_result
  FROM public.store_members sm
  JOIN public.profiles p ON p.id = sm.user_id
  JOIN auth.users u ON u.id = sm.user_id
  WHERE sm.store_id = v_store_id;

  RETURN v_result;
END;
$$;

COMMIT;