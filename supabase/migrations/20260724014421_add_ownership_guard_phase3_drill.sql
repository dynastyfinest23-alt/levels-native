-- Launch-readiness follow-up to 20260723004551_add_ownership_guards_phase5_cog:
-- that migration guarded the five Phase 5/CoG SECURITY DEFINER functions but
-- missed process_phase3_drill, which has the identical IDOR shape (verified
-- live 2026-07-23: SECURITY DEFINER, anon-executable, no auth.uid() check --
-- possession of a drill row's UUID was sufficient to recompute another user's
-- assigned_protocol and rotate their loop's assigned_track). Same fix, same
-- shape: ownership guard right after the existing NOT FOUND check, body
-- otherwise byte-for-byte identical to the deployed version read via
-- pg_get_functiondef on 2026-07-23.
--
-- Grant note: unlike the Phase 5 five (whose EXECUTE came only via the
-- implicit PUBLIC grant), this function carries BOTH a PUBLIC grant and a
-- direct anon grant (confirmed via role_routine_grants) -- so the revoke
-- targets both. authenticated/postgres/service_role keep their own explicit
-- grants; the Flutter client calls this as the authenticated user and is
-- unaffected. This enforces CLAUDE.md Migration & SQL discipline rule 8.

BEGIN;

CREATE OR REPLACE FUNCTION public.process_phase3_drill(p_drill_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rec       phase3_origin_drills%ROWTYPE;
  v_track     ascension_track;
  v_rationale text;
BEGIN
  SELECT * INTO v_rec
  FROM phase3_origin_drills
  WHERE id = p_drill_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Drill % not found', p_drill_id;
  END IF;

  IF v_rec.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to process this drill';
  END IF;

  -- Guard: all three routing answers must be present, same discipline as
  -- compute_center_of_gravity's completeness guard.
  IF v_rec.q1_origin_type IS NULL OR v_rec.q2_domain IS NULL OR v_rec.q3_mechanism IS NULL THEN
    RAISE EXCEPTION 'Drill % is incomplete: q1_origin_type, q2_domain, and q3_mechanism are all required before routing', p_drill_id;
  END IF;

  v_track := assign_phase4_track(v_rec.q1_origin_type, v_rec.q2_domain, v_rec.q3_mechanism);
  v_rationale := format('origin_type=%s domain=%s mechanism=%s -> track=%s',
    v_rec.q1_origin_type, v_rec.q2_domain, v_rec.q3_mechanism, v_track);

  UPDATE phase3_origin_drills SET
    assigned_protocol  = v_track,
    protocol_rationale = v_rationale,
    completed_at        = now()
  WHERE id = p_drill_id;

  UPDATE ascension_loops SET
    assigned_track = v_track
  WHERE id = v_rec.loop_id;

END;
$function$;

REVOKE EXECUTE ON FUNCTION public.process_phase3_drill(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.process_phase3_drill(uuid) FROM anon;

COMMIT;
