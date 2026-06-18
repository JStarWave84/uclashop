-- Migration: initial schema for UCLAShop ecommerce (Supabase / PostgreSQL)
-- Filename: supabase/migrations/20260614T000000_init.sql

-- Enable extension for UUID generation (used for defaults)
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Helper security functions
-- is_admin() - true when current JWT corresponds to a profiles row with role = 'admin'
-- is_anon() - helper: role 'anon' for unauthenticated clients in Supabase
CREATE OR REPLACE FUNCTION public.is_anon()
RETURNS boolean
LANGUAGE sql STABLE
AS $$
  SELECT auth.role() = 'anon';
$$;

-- Note: the is_admin() helper references the public.profiles table; to avoid
-- dependency errors during migration we declare it after the profiles table
-- is created (see below).

-- ====================================================================
-- 1) profiles
-- Admin profiles. id should correspond to auth.users.id
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY,
  full_name text,
  role text, -- e.g. 'admin'
  created_at timestamptz DEFAULT now()
);

COMMENT ON TABLE public.profiles IS 'Admin profiles. id references auth.users(id).';

-- is_admin() - true when current JWT corresponds to a profiles row with role = 'admin'
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql STABLE
AS $$
  SELECT EXISTS(
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()::uuid
      AND p.role = 'admin'
  );
$$;

-- ====================================================================
-- 2) products
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  price numeric(12,2) NOT NULL CHECK (price >= 0),
  stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
  allow_backorder boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.products IS 'Products offered in events and regular sales.';

-- ====================================================================
-- 3) sales_sessions (jornadas / eventos)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.sales_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  start_date timestamptz NOT NULL,
  end_date timestamptz NOT NULL,
  is_open boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.sales_sessions IS 'Sales sessions (jornadas / eventos).';

-- ====================================================================
-- 4) product_sessions (many-to-many product <-> session)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.product_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.sales_sessions(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, session_id)
);

CREATE INDEX IF NOT EXISTS idx_product_sessions_product_id ON public.product_sessions(product_id);
CREATE INDEX IF NOT EXISTS idx_product_sessions_session_id ON public.product_sessions(session_id);

COMMENT ON TABLE public.product_sessions IS 'Which products are available in which sales sessions.';

-- ====================================================================
-- 5) payment_accounts
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.payment_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  holder_name text,
  bank text,
  phone text,
  ci text,
  account_type text CHECK (account_type IN ('personal','juridica','institucional')),
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.payment_accounts IS 'Accounts where customers can send manual payments (Pago móvil, etc.).';

-- ====================================================================
-- 6) product_payment_accounts
-- Map product -> payment_accounts (some products use specific accounts)
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.product_payment_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  payment_account_id uuid NOT NULL REFERENCES public.payment_accounts(id) ON DELETE CASCADE,
  is_primary boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (product_id, payment_account_id)
);

CREATE INDEX IF NOT EXISTS idx_product_payment_accounts_product_id ON public.product_payment_accounts(product_id);
CREATE INDEX IF NOT EXISTS idx_product_payment_accounts_payment_account_id ON public.product_payment_accounts(payment_account_id);

COMMENT ON TABLE public.product_payment_accounts IS 'Preferred payment accounts per product; used to auto-assign payment_account to an order.';

-- ====================================================================
-- 7) orders
-- Checkout direct: clients create orders (anonymous). Payment manual.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  status text NOT NULL DEFAULT 'pending_payment' CHECK (status IN ('pending_payment','paid','in_delivery','delivered','rejected')),
  total numeric(12,2) NOT NULL CHECK (total >= 0),
  customer_first_name text NOT NULL,
  customer_last_name text,
  customer_ci text,
  customer_phone text NOT NULL,
  customer_email text,
  payment_reference text,
  payment_receipt_url text,
  payment_account_id uuid REFERENCES public.payment_accounts(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orders_payment_account_id ON public.orders(payment_account_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON public.orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON public.orders(created_at);

COMMENT ON TABLE public.orders IS 'Order header. Created by anonymous customers at checkout.';

-- Trigger to maintain updated_at on orders
CREATE OR REPLACE FUNCTION public.trigger_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_orders_set_updated_at
BEFORE UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.trigger_set_updated_at();

-- ====================================================================
-- 8) order_items
-- Order lines keep snapshot of product name and price at order time.
-- Enforce stock/backorder at insertion (best-effort).
-- product_id ON DELETE SET NULL to preserve order history.
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  product_name_snapshot text NOT NULL,
  price_snapshot numeric(12,2) NOT NULL CHECK (price_snapshot >= 0),
  quantity integer NOT NULL CHECK (quantity > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_order_items_product_id ON public.order_items(product_id);

COMMENT ON TABLE public.order_items IS 'Order lines; snapshots of product name and price for historical correctness.';

-- Trigger: populate snapshot and enforce stock/backorder
CREATE OR REPLACE FUNCTION public.order_items_before_insert_or_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  p_product RECORD;
BEGIN
  IF NEW.product_id IS NOT NULL THEN
    SELECT id, name, price, stock, allow_backorder
      INTO p_product
      FROM public.products
      WHERE id = NEW.product_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product % not found', NEW.product_id;
    END IF;

    -- set snapshot fields (ensure data integrity)
    NEW.product_name_snapshot := p_product.name;
    NEW.price_snapshot := COALESCE(NEW.price_snapshot, p_product.price);

    -- Enforce stock unless backorder allowed
    IF NOT p_product.allow_backorder AND NEW.quantity > p_product.stock THEN
      RAISE EXCEPTION 'Insufficient stock for product % (available: %, requested: %). Backorders not allowed.', p_product.id, p_product.stock, NEW.quantity;
    END IF;
  ELSE
    -- If no product_id, snapshots must be provided
    IF NEW.product_name_snapshot IS NULL OR NEW.price_snapshot IS NULL THEN
      RAISE EXCEPTION 'product_id is null - product snapshot fields required';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_order_items_before_ins_upd
BEFORE INSERT OR UPDATE ON public.order_items
FOR EACH ROW
EXECUTE FUNCTION public.order_items_before_insert_or_update();

-- ====================================================================
-- 9) deliveries
-- Managed by admins
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'preparing' CHECK (status IN ('preparing','out_for_delivery','delivered')),
  delivered_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_deliveries_order_id ON public.deliveries(order_id);
CREATE INDEX IF NOT EXISTS idx_deliveries_status ON public.deliveries(status);

COMMENT ON TABLE public.deliveries IS 'Delivery tracking for orders (managed by admins).';

-- ====================================================================
-- 10) payment_settings (global fallback) - ADMIN ONLY
-- ====================================================================
CREATE TABLE IF NOT EXISTS public.payment_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bank text,
  phone text,
  ci text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.payment_settings IS 'Global fallback payment information (admin only).';

-- ====================================================================
-- Functions & triggers to auto-assign payment_account for an order
-- Prefer product_payment_accounts.is_primary for items in the order
-- Fallback to first active payment_account
-- ====================================================================
CREATE OR REPLACE FUNCTION public.refresh_order_payment_account(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_payment_account uuid;
BEGIN
  SELECT ppa.payment_account_id
  INTO v_payment_account
  FROM public.order_items oi
  JOIN public.product_payment_accounts ppa ON ppa.product_id = oi.product_id AND ppa.is_primary
  WHERE oi.order_id = p_order_id
  LIMIT 1;

  IF v_payment_account IS NULL THEN
    SELECT id INTO v_payment_account FROM public.payment_accounts WHERE is_active = true ORDER BY created_at LIMIT 1;
  END IF;

  IF v_payment_account IS DISTINCT FROM (SELECT payment_account_id FROM public.orders WHERE id = p_order_id) THEN
    UPDATE public.orders SET payment_account_id = v_payment_account WHERE id = p_order_id;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_order_items_refresh_payment_account()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_order_id uuid;
BEGIN
  IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
    v_order_id := NEW.order_id;
  ELSIF TG_OP = 'DELETE' THEN
    v_order_id := OLD.order_id;
  ELSE
    RETURN NULL;
  END IF;

  PERFORM public.refresh_order_payment_account(v_order_id);
  RETURN NULL;
END;
$$;

CREATE TRIGGER trg_order_items_after_changes
AFTER INSERT OR UPDATE OR DELETE ON public.order_items
FOR EACH ROW
EXECUTE FUNCTION public.trg_order_items_refresh_payment_account();

-- ====================================================================
-- Additional index for admin dashboard queries
-- ====================================================================
CREATE INDEX IF NOT EXISTS idx_orders_status_created_at ON public.orders(status, created_at);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- - Anonymous clients (auth.role() = 'anon') may:
--     * INSERT orders
--     * INSERT order_items
--     * SELECT products (active)
-- - Admins (profiles.role = 'admin') may:
--     * full access to all tables
-- - Payment_settings: admin only
-- - Orders: anonymous can INSERT only; cannot SELECT
-- ====================================================================

-- products: public read (active) + admin full access
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

CREATE POLICY products_public_select ON public.products
  FOR SELECT
  USING ( (is_active = true) OR public.is_admin() );

CREATE POLICY products_admin_full ON public.products
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- sales_sessions: admin only
ALTER TABLE public.sales_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY sales_sessions_admin ON public.sales_sessions
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- product_sessions: admin only
ALTER TABLE public.product_sessions ENABLE ROW LEVEL SECURITY;

CREATE POLICY product_sessions_admin ON public.product_sessions
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- payment_accounts: admin only
ALTER TABLE public.payment_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY payment_accounts_admin ON public.payment_accounts
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- product_payment_accounts: admin only
ALTER TABLE public.product_payment_accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY product_payment_accounts_admin ON public.product_payment_accounts
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- orders:
-- - allow anonymous INSERT only (create order)
-- - admin full access (SELECT/UPDATE/DELETE)
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY orders_allow_insert_anonymous ON public.orders
  FOR INSERT
  WITH CHECK ( public.is_anon() OR public.is_admin() );

CREATE POLICY orders_admin_all ON public.orders
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- order_items:
-- - allow anonymous INSERT only (to create order items in the same transaction)
-- - admin full access
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY order_items_allow_insert_anonymous ON public.order_items
  FOR INSERT
  WITH CHECK ( public.is_anon() OR public.is_admin() );

CREATE POLICY order_items_admin_all ON public.order_items
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- deliveries: admin only
ALTER TABLE public.deliveries ENABLE ROW LEVEL SECURITY;

CREATE POLICY deliveries_admin ON public.deliveries
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- payment_settings: ADMIN ONLY (per your confirmation)
ALTER TABLE public.payment_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY payment_settings_admin ON public.payment_settings
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- profiles: admin only
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_admin ON public.profiles
  FOR ALL
  USING ( public.is_admin() )
  WITH CHECK ( public.is_admin() );

-- ====================================================================
-- Final notes:
-- - Orders should be created in a single transaction from the client along with order_items.
-- - Stock enforcement in order_items trigger is a best-effort check; for strict inventory guarantees add reservation flow.
-- - product_id in order_items is ON DELETE SET NULL so order history remains even if product is deleted.
-- - Admins validate manual payments and update orders.status to 'paid'; deliveries tracked separately.
-- ====================================================================
