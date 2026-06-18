-- Migration: storage RLS policies for product-images bucket
-- Public bucket: anyone can read product images; admins can insert/update/delete.

-- INSERT/UPDATE/DELETE: admin only
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'product_images_admin_all') THEN
    CREATE POLICY product_images_admin_all ON storage.objects
      FOR ALL
      USING ( bucket_id = 'product-images' AND public.is_admin() )
      WITH CHECK ( bucket_id = 'product-images' AND public.is_admin() );
  END IF;
END$$;

-- SELECT: public (anyone can view product images)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'product_images_public_select') THEN
    CREATE POLICY product_images_public_select ON storage.objects
      FOR SELECT
      USING ( bucket_id = 'product-images' );
  END IF;
END$$;
