-- Revoke REST-callable EXECUTE from the two SECURITY DEFINER *trigger*
-- functions. Both fire from triggers only and were never meant to be reachable
-- at /rest/v1/rpc/, but both still carried the default PUBLIC execute grant,
-- so anon could invoke them. Found 2026-07-28 via get_advisors
-- (anon_security_definer_function_executable) and confirmed with
-- has_function_privilege('anon', oid, 'EXECUTE') = true for both.
--
-- Same class of gap that 20260723005040 and 20260724014421 closed on the
-- client-facing RPCs; these two were missed because they are trigger
-- functions rather than functions the client calls.
--
-- Trigger execution is unaffected: a trigger function runs as the table
-- owner's trigger, not through the caller's EXECUTE grant.

BEGIN;

-- Fires from on_auth_user_created on auth.users.
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;

-- Fires from its trigger on phase1_assessments.
REVOKE ALL ON FUNCTION public.seed_calibration_from_assessment() FROM PUBLIC, anon, authenticated;

COMMIT;
