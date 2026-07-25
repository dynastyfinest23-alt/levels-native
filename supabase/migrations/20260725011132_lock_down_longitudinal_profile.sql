-- Launch-readiness follow-up: get_advisors flagged longitudinal_profile
-- (materialized_view_in_api) as selectable by anon and authenticated via the
-- Data API. Confirmed via pg_class.relacl (2026-07-24) that anon and
-- authenticated hold SELECT (plus INSERT/UPDATE/DELETE/TRUNCATE, though
-- Postgres blocks DML on a plain materialized view regardless) -- almost
-- certainly the default "GRANT ALL ON ALL TABLES IN SCHEMA public" applying
-- to a new relation, never scoped deliberately.
--
-- Impact: the view aggregates EVERY user's longitudinal data with no
-- user_id filter (cog_history, zone_history, dominant_origin_type,
-- dominant_coping_mechanism, and free-text completion_statements), and
-- materialized views cannot carry RLS policies -- so any anon caller with
-- only the publishable key could read every user's full history via
-- GET /rest/v1/longitudinal_profile?select=*. This violates the product
-- decision that free-text answers stay under RLS, readable only by the
-- user (CLAUDE.md "Product decisions" #2).
--
-- Fix: grep confirms no client or Edge Function code reads this view today
-- (it is not wired to any screen), so the safe move is revoking Data-API
-- access entirely rather than trying to scope it. postgres/service_role
-- keep full access for any future internal-only reporting use.

BEGIN;

REVOKE ALL ON public.longitudinal_profile FROM anon;
REVOKE ALL ON public.longitudinal_profile FROM authenticated;
REVOKE ALL ON public.longitudinal_profile FROM PUBLIC;

COMMIT;
