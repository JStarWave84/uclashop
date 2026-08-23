-- Seed data for UCLAShop (product, sales_session, payment_account, order, order_item)
-- Run options:
--  - From Supabase Studio SQL editor: paste and run
--  - Or locally: obtain DB URL and run `psql "<DB_URL>" -f supabase/seed.sql`

BEGIN;

-- Ensure the demo store exists (same as marketplace migration seed)
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

-- Insert a payment account (Pago móvil) for the products
WITH pay_acc AS (
  INSERT INTO public.payment_accounts (id, name, holder_name, bank, phone, ci, account_type, is_active, created_at)
  VALUES (gen_random_uuid(), 'PagoMóvil - BancoX', 'Colectivo UCL', 'BancoX', '+58 4120000000', 'J-00000000', 'institucional', true, now())
  RETURNING id
),

-- Insert simple product (flat stock, no variants)
prod AS (
  INSERT INTO public.products (id, name, description, price, stock, allow_backorder, is_active, store_id, created_at)
  SELECT gen_random_uuid(), 'Camiseta UCL', 'Camiseta oficial - talla M', 25.00, 5, true, true, s.id, now()
  FROM public.stores s WHERE s.slug = 'tienda-de-la-ucla'
  RETURNING id, name, price
),

-- Insert product WITH variants (color x talla)
vprod AS (
  INSERT INTO public.products (id, name, description, price, stock, allow_backorder, is_active, has_variants, store_id, created_at)
  SELECT gen_random_uuid(), 'Buso UCLA', 'Buso oficial con capota. Disponible en varios colores y tallas.', 40.00, 0, false, true, false, s.id, now()
  FROM public.stores s WHERE s.slug = 'tienda-de-la-ucla'
  RETURNING id, name, price
),

-- Variants for vprod: attributes + per-variant stock.
-- products.has_variants / products.stock are synced by trg_product_variants_sync_stock.
variants AS (
  INSERT INTO public.product_variants (product_id, attributes, price, stock, is_active)
  SELECT vprod.id, '{"Color": "Negro", "Talla": "M"}'::jsonb, NULL, 10, true FROM vprod
  UNION ALL
  SELECT vprod.id, '{"Color": "Negro", "Talla": "L"}'::jsonb, 42.00, 8, true FROM vprod
  UNION ALL
  SELECT vprod.id, '{"Color": "Blanco", "Talla": "M"}'::jsonb, NULL, 6, true FROM vprod
  UNION ALL
  SELECT vprod.id, '{"Color": "Blanco", "Talla": "L"}'::jsonb, 42.00, 0, true FROM vprod
  RETURNING id
),

-- Link products to payment account (primary)
ppa AS (
  INSERT INTO public.product_payment_accounts (id, product_id, payment_account_id, is_primary, created_at)
  SELECT gen_random_uuid(), p.id, pay_acc.id, true, now() FROM pay_acc
  CROSS JOIN (SELECT id FROM prod UNION SELECT id FROM vprod) p
  RETURNING id
),

-- Create a sales session (jornada)
session AS (
  INSERT INTO public.sales_sessions (id, name, start_date, end_date, is_open, created_at)
  VALUES (gen_random_uuid(), 'Jornada Cultural', now(), now() + interval '2 days', true, now())
  RETURNING id
),

-- Make the simple product available in the session
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
    (SELECT id FROM vprod) AS variant_product_id,
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
