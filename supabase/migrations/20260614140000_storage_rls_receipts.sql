-- Migration: storage RLS policies for receipts bucket
-- Ensure private bucket 'receipts' can accept uploads from clients (anon/authenticated)
-- while only admins can read/update/delete objects.

-- Note: enabling RLS on storage.objects may require owner privileges. The storage schema
-- typically already has RLS enabled. If RLS is not enabled, enable it as the DB owner
-- or via Supabase Studio before applying these policies.

-- INSERT policy: allow anonymous or authenticated clients to INSERT metadata for objects in bucket 'receipts'
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'receipts_insert_clients') THEN
    CREATE POLICY receipts_insert_clients ON storage.objects
      FOR INSERT
      -- allow anon or authenticated clients to upload into this bucket
      WITH CHECK (
        bucket_id = 'receipts'
        AND (
          auth.role() = 'anon' OR auth.role() = 'authenticated' OR public.is_admin()
        )
      );
  END IF;
END$$;

-- SELECT policy: only admins can SELECT (read) objects in receipts
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'receipts_select_admin') THEN
    CREATE POLICY receipts_select_admin ON storage.objects
      FOR SELECT
      USING (
        bucket_id = 'receipts' AND public.is_admin()
      );
  END IF;
END$$;

-- UPDATE policy: only admins can update metadata for objects in receipts
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'receipts_update_admin') THEN
    CREATE POLICY receipts_update_admin ON storage.objects
      FOR UPDATE
      USING (
        bucket_id = 'receipts' AND public.is_admin()
      )
      WITH CHECK (
        bucket_id = 'receipts' AND public.is_admin()
      );
  END IF;
END$$;

-- DELETE policy: only admins can delete objects in receipts
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'receipts_delete_admin') THEN
    CREATE POLICY receipts_delete_admin ON storage.objects
      FOR DELETE
      USING (
        bucket_id = 'receipts' AND public.is_admin()
      );
  END IF;
END$$;

-- Notes:
-- 1) Create the bucket 'receipts' as PRIVATE in Supabase Studio (Storage -> Create bucket). Do NOT make it public.
-- 2) Clients (using anon key or authenticated non-admin) will be able to upload objects to this bucket because of the
--    INSERT policy above. The uploaded object's metadata (storage.objects) will be created and visible only to admins
--    via SELECT according to the SELECT policy.
-- 3) Save the object path (the 'name' column in storage) into orders.payment_receipt_url (e.g. 'order-id/comprobante.jpg').
-- 4) To display the image to admins, generate a signed URL in the admin client:
--    const { data } = await supabase.storage.from('receipts').createSignedUrl(objectPath, expiresInSeconds)
