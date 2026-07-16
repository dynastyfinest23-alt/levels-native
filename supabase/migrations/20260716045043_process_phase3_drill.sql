BEGIN;

-- M3.3: process_phase3_drill reads a completed origin-drill row, routes it
-- through the existing assign_phase4_track decision function, and persists
-- the result. Mirrors the compute_center_of_gravity pattern: one RPC that
-- decides AND persists. Additive only — does not touch assign_phase4_track
-- or any other existing function.
CREATE OR REPLACE FUNCTION public.process_phase3_drill(p_drill_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
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

COMMIT;
