-- Migration: drop legacy place_order overload (8-arg, pre-receipt version).
-- Keeping both signatures makes rpc('place_order', {...}) ambiguous (42725)
-- whenever a call can be satisfied by either candidate. The 9-arg version
-- (with p_receipt_url) is the only one the app uses.

DROP FUNCTION IF EXISTS public.place_order(numeric, text, text, text, text, text, text, jsonb);
