-- Migration: add product image path to products
-- Adds a column to store the storage object path for product images.

ALTER TABLE public.products
  ADD COLUMN IF NOT EXISTS product_image_path text;

COMMENT ON COLUMN public.products.product_image_path IS 'Object path in storage bucket (e.g. "product-images/<product_id>/image.jpg"). Use public.storage_public_url to build public URL.';

-- Optional: if you want to expose a computed public URL in SQL, use the helper function:
-- SELECT public.storage_public_url('product-images', product_image_path, '<PROJECT_REF>')
