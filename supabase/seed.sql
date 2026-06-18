-- Seed data for UCLAShop (product, sales_session, payment_account, order, order_item)
-- Run options:
--  - From Supabase Studio SQL editor: paste and run
--  - Or locally: obtain DB URL and run `psql "<DB_URL>" -f supabase/seed.sql`

BEGIN;

-- Insert a payment account (Pago móvil) for the product
WITH pay_acc AS (
  INSERT INTO public.payment_accounts (id, name, holder_name, bank, phone, ci, account_type, is_active, created_at)
  VALUES (gen_random_uuid(), 'PagoMóvil - BancoX', 'Colectivo UCL', 'BancoX', '+58 4120000000', 'J-00000000', 'institucional', true, now())
  RETURNING id
),

-- Insert product
prod AS (
  INSERT INTO public.products (id, name, description, price, stock, allow_backorder, is_active, created_at)
  VALUES (gen_random_uuid(), 'Camiseta UCL', 'Camiseta oficial - talla M', 25.00, 5, true, true, now())
  RETURNING id, name, price
),

-- Link product to payment account (primary)
ppa AS (
  INSERT INTO public.product_payment_accounts (id, product_id, payment_account_id, is_primary, created_at)
  SELECT gen_random_uuid(), prod.id, pay_acc.id, true, now() FROM prod, pay_acc
  RETURNING id
),

-- Create a sales session (jornada)
session AS (
  INSERT INTO public.sales_sessions (id, name, start_date, end_date, is_open, created_at)
  VALUES (gen_random_uuid(), 'Jornada Cultural', now(), now() + interval '2 days', true, now())
  RETURNING id
),

-- Make the product available in the session
ps AS (
  INSERT INTO public.product_sessions (id, product_id, session_id, created_at)
  SELECT gen_random_uuid(), prod.id, session.id, now() FROM prod, session
  RETURNING id
),

-- Create an order (payment_receipt_url uses a storage-style placeholder)
order1 AS (
  INSERT INTO public.orders (id, status, total, customer_first_name, customer_last_name, customer_ci, customer_phone, customer_email, payment_account_id, payment_receipt_url, created_at, updated_at)
  SELECT
    gen_random_uuid(),
    'pending_payment',
    prod.price * 1,
    'Ana', 'Gomez', 'V-11223344', '+58 4122222222', 'ana@example.com',
    (SELECT id FROM pay_acc),
    -- Placeholder for a receipt stored in Supabase Storage. Replace with actual public URL or object path.
    ('storage://receipts/' || gen_random_uuid() || '.jpg'),
    now(), now()
  FROM prod
  RETURNING id
),

-- Insert order item (snapshots populated by trigger)
order_item1 AS (
  INSERT INTO public.order_items (id, order_id, product_id, quantity, created_at)
  SELECT gen_random_uuid(), order1.id, prod.id, 1, now() FROM order1, prod
  RETURNING id
)

  SELECT
    'seed_completed' AS info,
    (SELECT id FROM prod) AS product_id,
    (SELECT id FROM session) AS session_id,
    (SELECT id FROM pay_acc) AS payment_account_id,
    (SELECT id FROM order1) AS example_order_id,
    -- also return the object path saved in payment_receipt_url for convenience
    (SELECT payment_receipt_url FROM public.orders WHERE id = (SELECT id FROM order1)) AS payment_receipt_path;

COMMIT;

-- Storage notes:
-- - payment_receipt_url currently stores a placeholder like: storage://receipts/<uuid>.jpg
-- - Best practice: store the object path (e.g. receipts/<order_id>.jpg) or the full public URL:
--     https://<PROJECT_REF>.supabase.co/storage/v1/object/public/<bucket>/<path>
-- - Use the Supabase Storage client to upload the file to a bucket (e.g. 'receipts') and save either the object path
--   or the full public URL into orders.payment_receipt_url.
-- - Ensure bucket permissions/policies allow the intended access pattern (public or signed URLs).
