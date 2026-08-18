-- Migration: storage bucket + RLS for store logos
-- Public read; admins full; store owners can upload under their own store folder.

BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('store-logos', 'store-logos', true)
ON CONFLICT (id) DO NOTHING;

-- Admin full access
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'store_logos_admin_all') THEN
    CREATE POLICY store_logos_admin_all ON storage.objects
      FOR ALL
      USING ( bucket_id = 'store-logos' AND public.is_admin() )
      WITH CHECK ( bucket_id = 'store-logos' AND public.is_admin() );
  END IF;
END$$;

-- Public read
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'store_logos_public_select') THEN
    CREATE POLICY store_logos_public_select ON storage.objects
      FOR SELECT
      USING ( bucket_id = 'store-logos' );
  END IF;
END$$;

-- Store members can upload/delete in their own store folder (<store_id>/...)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'store_logos_store_all') THEN
    CREATE POLICY store_logos_store_all ON storage.objects
      FOR ALL
      USING ( bucket_id = 'store-logos' AND (storage.foldername(name))[1] = public.my_store_id()::text )
      WITH CHECK ( bucket_id = 'store-logos' AND (storage.foldername(name))[1] = public.my_store_id()::text );
  END IF;
END$$;

COMMIT;