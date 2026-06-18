-- Migration: storage helper for receipts (URL formatter)
-- This migration adds a SQL function to build a public storage URL for objects.
-- Note: creating buckets and setting public access must be done via Supabase Studio
-- or the storage API; the CLI version here does not provide create-bucket.

-- Replace <PROJECT_REF> with your project's ref when calling, or supply it from the client.
CREATE OR REPLACE FUNCTION public.storage_public_url(bucket text, object_path text, project_ref text)
RETURNS text
LANGUAGE sql STABLE
AS $$
  SELECT format('https://%s.supabase.co/storage/v1/object/public/%s/%s', project_ref, bucket, object_path);
$$;

COMMENT ON FUNCTION public.storage_public_url(text, text, text) IS
  'Returns the public URL for a storage object. Requires the bucket to be public.';

-- Example usage:
-- SELECT public.storage_public_url('receipts','receipts/1234.jpg','<PROJECT_REF>');
