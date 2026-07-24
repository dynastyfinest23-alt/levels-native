-- Correction to 20260723004551_add_ownership_guards_phase5_cog.sql: that
-- migration's REVOKE EXECUTE ... FROM anon had no effect. Confirmed via
-- information_schema.role_routine_grants that EXECUTE on all five
-- functions was granted to PUBLIC (Postgres's implicit "every role"
-- pseudo-role) rather than to anon directly -- anon inherits execute
-- rights through PUBLIC membership, so revoking from anon specifically
-- left the PUBLIC grant in place and anon still executable per a
-- post-push get_advisors re-check.
--
-- authenticated, service_role, and postgres each carry their own explicit
-- EXECUTE grant on every one of these functions (also confirmed via
-- role_routine_grants), so revoking from PUBLIC does not affect them --
-- the Flutter client (which calls these RPCs as an authenticated user)
-- keeps working. Only anon loses access, which is the intended fix.

BEGIN;

REVOKE EXECUTE ON FUNCTION public.compute_center_of_gravity(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.process_phase5_reassessment(uuid, p1_answer, p1_answer, q3_block_flag) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.process_window3_durability(uuid, p1_answer, p1_answer, q3_block_flag) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.apply_window3_calibration(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.route_false_positive(uuid, rediag_resistance, rediag_feeling, rediag_pattern, text) FROM PUBLIC;

COMMIT;
