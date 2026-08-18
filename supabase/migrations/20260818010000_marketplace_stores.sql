-- Migration: marketplace refactor (stores + roles)
-- - Creates stores and store_members tables
-- - Adds products.store_id (products now belong to a store)
-- - Drops products.contact_phone (WhatsApp phone now lives on the store)
-- - Wipes existing shop data (products, sessions, orders, payment accounts)
-- - Seeds the "Tienda de la UCLA" store owned by the Centro de Estudiantes (admins)
-- - Replaces products RLS with store-aware policies
-- - Protects store verification flags and profile roles from self-escalation

BEGIN;

-- ====================================================================
-- 0) Wipe existing shop data (destructive, per decision)
-- ====================================================================
TRUNCATE TABLE public.order_items,
             public.orders,
             public.product_payment_accounts,
             public.product_sessions,
             public.payment_accounts,
             public.products,
             public.sales_sessions
  RESTART IDENTITY CASCADE;

-- ====================================================================
-- 1) stores
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.stores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  slug text NOT NULL UNIQUE,
  description text,
  phone text,
  logo_path text,
  is_verified boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stores_is_verified ON public.stores(is_verified);
CREATE INDEX IF NOT EXISTS idx_stores_is_active ON public.stores(is_active);

COMMENT ON TABLE public.stores IS 'Stores in the marketplace. is_verified must be true to publish products.';

-- ====================================================================
-- 2) store_members (owner / staff). One store per user.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.store_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role_in_store text NOT NULL DEFAULT 'staff' CHECK (role_in_store IN ('owner','staff')),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (store_id, user_id),
  UNIQUE (user_id)
);

CREATE INDEX IF NOT EXISTS idx_store_members_store_id ON public.store_members(store_id);

COMMENT ON TABLE public.store_members IS 'Which users manage a store. role_in_store owner|staff. A user belongs to at most one store.';

-- ====================================================================
-- 3) products now belong to a store; drop per-product WhatsApp number
-- ====================================================================
ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES public.stores(id) ON DELETE CASCADE;

ALTER TABLE public.products
  DROP COLUMN IF EXISTS contact_phone;

UPDATE public.products SET store_id = NULL WHERE store_id IS NULL;

ALTER TABLE public.products
  ALTER COLUMN store_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS idx_products_store_id ON public.products(store_id);

COMMENT ON COLUMN public.products.store_id IS 'Owning store. Products are visible to the public only when the store is verified.';

-- ====================================================================
-- 4) Seed: Tienda de la UCLA (owned by the Centro de Estudiantes / admins)
-- ====================================================================
INSERT INTO public.stores (name, slug, description, phone, is_verified, is_active, created_by, created_at)
SELECT
  'Tienda de la UCLA',
  'tienda-de-la-ucla',
  'Productos oficiales del Centro de Estudiantes de la Universidad Centroccidental Lisandro Alvarado.',
  NULL,
  true,
  true,
  NULL,
  now()
WHERE NOT EXISTS (SELECT 1 FROM public.stores WHERE slug = 'tienda-de-la-ucla');

INSERT INTO public.store_members (store_id, user_id, role_in_store, created_at)
SELECT s.id, p.id, 'owner', now()
FROM public.stores s
JOIN public.profiles p ON p.role = 'admin'
WHERE s.slug = 'tienda-de-la-ucla'
ON CONFLICT (store_id, user_id) DO NOTHING;

-- ====================================================================
-- 5) RLS helpers
-- ====================================================================
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

-- ====================================================================
-- 6) Row Level Security
-- ====================================================================

-- stores: public sees verified; members see/manage their own; admin full
ALTER TABLE public.stores ENABLE ROW LEVEL SECURITY;

CREATE POLICY stores_public_select ON public.stores
  FOR SELECT
  USING ( is_verified = true );

CREATE POLICY stores_admin_all ON public.stores
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

CREATE POLICY stores_member_select ON public.stores
  FOR SELECT
  USING ( id = public.my_store_id() );

CREATE POLICY stores_member_update ON public.stores
  FOR UPDATE
  USING ( id = public.my_store_id() )
  WITH CHECK ( id = public.my_store_id() );

-- store_members: admin full; members can read their store's members
ALTER TABLE public.store_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY store_members_admin_all ON public.store_members
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

CREATE POLICY store_members_member_select ON public.store_members
  FOR SELECT
  USING ( store_id = public.my_store_id() );

-- products: replace previous policies with store-aware ones
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS products_public_select ON public.products;
DROP POLICY IF EXISTS products_admin_full ON public.products;

CREATE POLICY products_public_select ON public.products
  FOR SELECT
  USING (
    public.is_admin()
    OR ( is_active = true AND EXISTS(
      SELECT 1 FROM public.stores s WHERE s.id = products.store_id AND s.is_verified
    ))
  );

CREATE POLICY products_admin_all ON public.products
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

CREATE POLICY products_store_all ON public.products
  FOR ALL
  USING (
    store_id = public.my_store_id() AND public.is_verified_store_member(store_id)
  )
  WITH CHECK (
    store_id = public.my_store_id() AND public.is_verified_store_member(store_id)
  );

-- ====================================================================
-- 7) Safety triggers (prevent self-escalation / self-verification)
-- ====================================================================
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
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'Solo el Centro de Estudiantes puede cambiar la verificación o el estado de una tienda';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_stores_protect_verification ON public.stores;
CREATE TRIGGER trg_stores_protect_verification
  BEFORE UPDATE ON public.stores
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_store_verification();

CREATE OR REPLACE FUNCTION public.protect_profile_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role = 'admin' AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'No podés asignarte el rol de administrador';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_protect_role ON public.profiles;
CREATE TRIGGER trg_profiles_protect_role
  BEFORE UPDATE OF role ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_profile_role();

-- ====================================================================
-- 8) get_order_for_confirmation now returns the store WhatsApp number
--    (products.contact_phone was removed)
-- ====================================================================
CREATE OR REPLACE FUNCTION public.get_order_for_confirmation(
  p_order_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_order jsonb;
  v_items jsonb;
BEGIN
  SELECT to_jsonb(o.*)
  INTO v_order
  FROM public.orders o
  WHERE o.id = p_order_id;

  IF v_order IS NULL THEN
    RAISE EXCEPTION 'Order not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT COALESCE(
    jsonb_agg(
      to_jsonb(oi.*) || jsonb_build_object('contact_phone', s.phone)
      ORDER BY oi.created_at
    ),
    '[]'::jsonb
  )
  INTO v_items
  FROM public.order_items oi
  LEFT JOIN public.products p ON p.id = oi.product_id
  LEFT JOIN public.stores s ON s.id = p.store_id
  WHERE oi.order_id = p_order_id;

  RETURN jsonb_build_object(
    'order', v_order,
    'items', v_items
  );
END;
$$;

COMMIT;