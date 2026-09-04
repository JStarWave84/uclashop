-- Add unlimited session support
-- Jornadas ilimitadas have is_unlimited=true and no start/end dates

ALTER TABLE public.sales_sessions
  ADD COLUMN IF NOT EXISTS is_unlimited boolean NOT NULL DEFAULT false;

ALTER TABLE public.sales_sessions
  ALTER COLUMN start_date DROP NOT NULL,
  ALTER COLUMN end_date DROP NOT NULL;
