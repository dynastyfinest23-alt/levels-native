-- Purpose: close public access to the Debt Cure Dashboard tables (dcd_*), which
-- were added to the Levels production project out-of-band on 2026-09-12
-- (20260912021558, now mirrored in this repo) with allow-all policies for anon
-- and authenticated. Noah, 2026-11-08: the dashboard does not belong in Levels.
-- This only removes access; rows are kept until Noah confirms a copy exists,
-- then a follow-up migration drops the tables. RLS stays enabled with no
-- policies, so only postgres/service_role can reach them.
BEGIN;

DROP POLICY IF EXISTS dcd_cards_anon ON public.dcd_cards;
DROP POLICY IF EXISTS dcd_action_items_anon ON public.dcd_action_items;
DROP POLICY IF EXISTS dcd_payments_anon ON public.dcd_payments;
DROP POLICY IF EXISTS dcd_goals_anon ON public.dcd_goals;
DROP POLICY IF EXISTS dcd_profile_anon ON public.dcd_profile;

REVOKE ALL ON public.dcd_cards, public.dcd_action_items, public.dcd_payments,
  public.dcd_goals, public.dcd_profile FROM anon, authenticated, PUBLIC;

COMMIT;
