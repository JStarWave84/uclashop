-- Fix: RLS helper functions must run as SECURITY DEFINER so their internal
-- queries bypass RLS. Without this, a policy that calls my_store_id() triggers
-- infinite recursion (store_members policy -> my_store_id -> store_members ...)
-- causing "stack depth limit exceeded" (SQLSTATE 54001) on any public query.

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()::uuid
      AND p.role = 'admin'
  );
$$;

CREATE OR REPLACE FUNCTION public.is_store_member(p_store_id uuid)
RETURNS boolean
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.store_members sm
    WHERE sm.store_id = p_store_id AND sm.user_id = auth.uid()::uuid
  );
$$;

CREATE OR REPLACE FUNCTION public.my_store_id()
RETURNS uuid
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT store_id FROM public.store_members WHERE user_id = auth.uid()::uuid LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.is_verified_store_member(p_store_id uuid)
RETURNS boolean
LANGUAGE sql STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS(
    SELECT 1
    FROM public.store_members sm
    JOIN public.stores s ON s.id = sm.store_id
    WHERE sm.store_id = p_store_id
      AND sm.user_id = auth.uid()::uuid
      AND s.is_verified
  );
$$;