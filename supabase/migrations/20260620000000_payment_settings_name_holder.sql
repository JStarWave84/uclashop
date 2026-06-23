-- Migration: add name and holder_name columns to payment_settings
-- Enables global fallback payment info to be shown at checkout

ALTER TABLE public.payment_settings
  ADD COLUMN IF NOT EXISTS name text DEFAULT 'Pago móvil',
  ADD COLUMN IF NOT EXISTS holder_name text;

COMMENT ON COLUMN public.payment_settings.name IS 'Display name for the global fallback payment method (e.g. "Pago móvil")';
COMMENT ON COLUMN public.payment_settings.holder_name IS 'Account holder name for the global fallback payment method';
