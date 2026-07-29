-- Pin search_path on the five remaining functions the Supabase linter flags as
-- function_search_path_mutable (found 2026-07-28 via get_advisors).
--
-- All five are SECURITY INVOKER and IMMUTABLE, so this is not the privilege-
-- escalation shape the SECURITY DEFINER hardening rule targets: they already
-- run with the caller's own rights. Pinning is still correct, because each one
-- resolves public enum types (p1_answer, origin_type, energy_zone, ...) by
-- unqualified name, and it clears a standing WARN off every advisor run.
--
-- Signatures read from pg_get_function_identity_arguments on 2026-07-28; none
-- is overloaded. ALTER FUNCTION changes only the config, never the body, so no
-- scoring behavior moves and the golden mirror values are untouched.

BEGIN;

ALTER FUNCTION public.answer_to_raw_score(answer p1_answer)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.apply_downward_anchor_weight(raw_score integer)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.score_to_zone(score numeric)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.assign_phase4_track(p_origin_type origin_type, p_domain origin_domain, p_mechanism coping_mechanism)
  SET search_path = public, pg_temp;

ALTER FUNCTION public.compute_phase5_classification(p_q1_delta integer, p_q2_delta numeric, p_q3_flag q3_block_flag)
  SET search_path = public, pg_temp;

COMMIT;
