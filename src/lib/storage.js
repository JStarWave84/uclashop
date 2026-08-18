import { supabase } from './supabaseClient'

export function storagePublicUrl(bucket, path) {
  if (!path) return null
  const {
    data: { publicUrl },
  } = supabase.storage.from(bucket).getPublicUrl(path)
  return publicUrl
}

export function productImageUrl(path) {
  return storagePublicUrl('product-images', path)
}

export function storeLogoUrl(path) {
  return storagePublicUrl('store-logos', path)
}
