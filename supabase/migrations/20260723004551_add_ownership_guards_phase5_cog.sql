-- M6.1 hardening: close an IDOR gap found via get_advisors during full-loop
-- verification. compute_center_of_gravity, process_phase5_reassessment,
-- process_window3_durability, apply_window3_calibration, and
-- route_false_positive are all SECURITY DEFINER (bypass RLS by design) and
-- were all callable by anon/authenticated via PostgREST RPC with no check
-- that the target row belongs to the caller -- only that the row exists.
-- Fix: add an ownership guard (auth.uid() = row's user_id) to each, in the
-- same place/shape as each function's existing NOT FOUND guard, and revoke
-- EXECUTE from anon (no legitimate unauthenticated caller exists for any
-- of these). Bodies are otherwise byte-for-byte identical to the deployed
-- versions read via pg_get_functiondef on 2026-07-22 -- no other logic
-- touched, per CLAUDE.md's "existing function bodies are frozen without
-- Noah's sign-off."
--
-- route_false_positive did not have a NOT FOUND guard at all (it only
-- SELECTed loop_id, so a bad p_reassessment_id silently proceeded with
-- v_loop_id NULL). That gap had to be closed to have anywhere to put the
-- ownership check, so this migration adds a NOT FOUND raise there too --
-- flagged here since it's a small behavior change beyond the ownership
-- guard itself.

BEGIN;

CREATE OR REPLACE FUNCTION public.compute_center_of_gravity(p_assessment_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rec                  phase1_assessments%ROWTYPE;
  v_scores               INTEGER[] := ARRAY[]::INTEGER[];
  v_weighted_scores      NUMERIC[] := ARRAY[]::NUMERIC[];
  v_raw                  INTEGER;
  v_weighted             NUMERIC;
  v_cog                  NUMERIC;
  v_raw_mean             NUMERIC;
  v_min_score            INTEGER;
  v_max_score            INTEGER;
  v_cluster_count        INTEGER;
  v_consistency          consistency_flag;
  v_inconsistent         BOOLEAN;
  v_zone                 energy_zone;
  v_answer               p1_answer;
  v_was_clamped          BOOLEAN;
  i                      INTEGER;
BEGIN
  -- Fetch the assessment row
  SELECT * INTO v_rec
  FROM phase1_assessments
  WHERE id = p_assessment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Assessment % not found', p_assessment_id;
  END IF;

  IF v_rec.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to compute this assessment';
  END IF;

  -- Guard: all 7 answers must be present. answer_to_raw_score() returns 0 on
  -- NULL, so a partial assessment would silently produce a deflated CoG.
  IF v_rec.q1_answer IS NULL OR v_rec.q2_answer IS NULL OR v_rec.q3_answer IS NULL
     OR v_rec.q4_answer IS NULL OR v_rec.q5_answer IS NULL OR v_rec.q6_answer IS NULL
     OR v_rec.q7_answer IS NULL THEN
    RAISE EXCEPTION 'Assessment % is incomplete: all 7 answers are required before scoring', p_assessment_id;
  END IF;

  -- Build raw score array from answer enums
  FOREACH v_answer IN ARRAY ARRAY[
    v_rec.q1_answer, v_rec.q2_answer, v_rec.q3_answer,
    v_rec.q4_answer, v_rec.q5_answer, v_rec.q6_answer,
    v_rec.q7_answer
  ]
  LOOP
    v_raw := answer_to_raw_score(v_answer);
    v_scores := v_scores || v_raw;
    v_weighted := apply_downward_anchor_weight(v_raw);
    v_weighted_scores := v_weighted_scores || v_weighted;
  END LOOP;

  -- Compute Center of Gravity (weighted -- the score the user is shown)
  v_cog := (
    SELECT AVG(s) FROM UNNEST(v_weighted_scores) AS s
  );

  -- Capture clamp state BEFORE clamping, so Phase 2 receives it as a stored
  -- fact rather than deriving it from center_of_gravity = 499.99.
  v_was_clamped := (v_cog > 499.99);

  -- Single assessments cap below Flow (500). Flow zones are only reachable
  -- via accumulated verified loops per the Flow reachability formula.
  -- Calibrated love_flow=530 would otherwise allow an all-love_flow
  -- assessment to score into Flow directly.
  v_cog := LEAST(v_cog, 499.99);

  -- Consistency check operates on RAW scores against the RAW mean, so the
  -- downward-anchor weighting can't distort the spread measurement.
  v_raw_mean := (SELECT AVG(s) FROM UNNEST(v_scores) AS s);

  SELECT COUNT(*) INTO v_cluster_count
  FROM UNNEST(v_scores) AS s
  WHERE ABS(s - v_raw_mean) <= 50;

  -- Determine consistency flag
  v_min_score := (SELECT MIN(s) FROM UNNEST(v_scores) AS s);
  v_max_score := (SELECT MAX(s) FROM UNNEST(v_scores) AS s);

  IF v_cluster_count >= 3 THEN
    v_consistency := 'consistent'::consistency_flag;
    v_inconsistent := FALSE;
  ELSIF (v_max_score - v_min_score) > 250 THEN
    v_consistency := 'scattered'::consistency_flag;
    v_inconsistent := TRUE;
  ELSE
    v_consistency := 'transitional'::consistency_flag;
    v_inconsistent := FALSE;
  END IF;

  -- Derive zone from CoG
  v_zone := score_to_zone(v_cog);

  -- Write computed values back to assessment row
  UPDATE phase1_assessments SET
    q1_raw_score         = v_scores[1],
    q2_raw_score         = v_scores[2],
    q3_raw_score         = v_scores[3],
    q4_raw_score         = v_scores[4],
    q5_raw_score         = v_scores[5],
    q6_raw_score         = v_scores[6],
    q7_raw_score         = v_scores[7],
    q1_weighted_score    = v_weighted_scores[1],
    q2_weighted_score    = v_weighted_scores[2],
    q3_weighted_score    = v_weighted_scores[3],
    q4_weighted_score    = v_weighted_scores[4],
    q5_weighted_score    = v_weighted_scores[5],
    q6_weighted_score    = v_weighted_scores[6],
    q7_weighted_score    = v_weighted_scores[7],
    center_of_gravity    = ROUND(v_cog, 2),
    dominant_zone        = v_zone,
    consistency_flag     = v_consistency,
    energetically_inconsistent = v_inconsistent,
    was_clamped          = v_was_clamped
  WHERE id = p_assessment_id;

  -- Sync zone back to the parent ascension_loop entry_zone
  UPDATE ascension_loops SET
    entry_score = ROUND(v_cog, 2),
    entry_zone  = v_zone
  WHERE id = v_rec.loop_id;

END;
$function$;

CREATE OR REPLACE FUNCTION public.process_phase5_reassessment(p_reassessment_id uuid, p_q1_new_answer p1_answer, p_q2_new_answer p1_answer, p_q3_flag q3_block_flag)
 RETURNS phase5_classification
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rec              phase5_reassessments%ROWTYPE;
  v_loop_id          UUID;
  v_orig_q1_score    INTEGER;
  v_orig_q2_raw      INTEGER;
  v_orig_q2_score    NUMERIC;
  v_q1_new_score     INTEGER;
  v_q2_new_score     NUMERIC;
  v_q1_delta         INTEGER;
  v_q2_delta         NUMERIC;
  v_result           RECORD;
BEGIN
  -- Fetch the reassessment row
  SELECT * INTO v_rec
  FROM phase5_reassessments
  WHERE id = p_reassessment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reassessment % not found', p_reassessment_id;
  END IF;

  IF v_rec.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to process this reassessment';
  END IF;

  v_loop_id := v_rec.loop_id;

  -- Pull original Phase 1 scores for delta computation.
  -- We take q6 RAW (not q6_weighted_score) and re-apply the body-state weight
  -- below, so original and new are measured on the IDENTICAL 1.75x scale.
  SELECT
    q5_raw_score,       -- Q5 (Locus of Control) maps to Q1 of check-in
    q6_raw_score        -- Q6 (Body State) maps to Q2 of check-in
  INTO v_orig_q1_score, v_orig_q2_raw
  FROM phase1_assessments
  WHERE loop_id = v_loop_id;

  v_orig_q2_score := v_orig_q2_raw * 1.75;  -- Body-state weight (same as new)

  -- Compute new scores
  v_q1_new_score := answer_to_raw_score(p_q1_new_answer);
  v_q2_new_score := answer_to_raw_score(p_q2_new_answer) * 1.75;  -- Body-state weight

  -- Compute deltas
  v_q1_delta := v_q1_new_score - v_orig_q1_score;
  v_q2_delta := v_q2_new_score - v_orig_q2_score;

  -- Run classification engine
  SELECT * INTO v_result
  FROM compute_phase5_classification(v_q1_delta, v_q2_delta, p_q3_flag);

  -- Write all computed values back to the reassessment row
  UPDATE phase5_reassessments SET
    q1_trigger_answer   = p_q1_new_answer,
    q1_new_score        = v_q1_new_score,
    q1_original_score   = v_orig_q1_score,
    q1_delta            = v_q1_delta,
    q2_body_state_answer = p_q2_new_answer,
    q2_new_score        = v_q2_new_score,
    q2_original_score   = v_orig_q2_score,
    q2_delta            = v_q2_delta,
    q3_block_flag       = p_q3_flag,
    combined_delta      = v_result.combined_delta,
    classification      = v_result.classification,
    routing_outcome     = v_result.routing_outcome
  WHERE id = p_reassessment_id;

  -- If true ascension, update the parent loop exit data
  IF v_result.classification = 'true_ascension' THEN
    UPDATE ascension_loops SET
      status      = 'complete',
      completed_at = NOW(),
      exit_score  = (
        SELECT center_of_gravity + v_result.combined_delta
        FROM phase1_assessments
        WHERE loop_id = v_loop_id
      ),
      exit_zone   = score_to_zone((
        SELECT center_of_gravity + v_result.combined_delta
        FROM phase1_assessments
        WHERE loop_id = v_loop_id
      ))
    WHERE id = v_loop_id;
  END IF;

  -- NOTE: We deliberately do NOT refresh longitudinal_profile here.
  -- REFRESH MATERIALIZED VIEW CONCURRENTLY cannot run inside a transaction
  -- block, and this whole function executes inside one (every Supabase RPC /
  -- Edge Function call is a transaction). Refreshing inline would throw and
  -- roll back the entire reassessment. The refresh is handled out-of-band by
  -- the pg_cron job in Section 8 (refresh-longitudinal-profile).

  RETURN v_result.classification;
END;
$function$;

CREATE OR REPLACE FUNCTION public.process_window3_durability(p_reassessment_id uuid, p_q1_new_answer p1_answer, p_q2_new_answer p1_answer, p_q3_flag q3_block_flag)
 RETURNS user_calibration
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rec            phase5_reassessments%ROWTYPE;
  v_loop_id        UUID;
  v_orig_q1_score  INTEGER;
  v_orig_q2_raw    INTEGER;
  v_orig_q2_score  NUMERIC;
  v_q1_new_score   INTEGER;
  v_q2_new_score   NUMERIC;
  v_q1_delta       INTEGER;
  v_q2_delta       NUMERIC;
  v_result         RECORD;
  v_calibration    user_calibration%ROWTYPE;
BEGIN
  SELECT * INTO v_rec FROM phase5_reassessments WHERE id = p_reassessment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reassessment % not found', p_reassessment_id;
  END IF;

  IF v_rec.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to process this reassessment';
  END IF;

  IF v_rec.window_number <> 'window_3' THEN
    RAISE EXCEPTION 'process_window3_durability expects a Window-3 row (got %)',
      v_rec.window_number;
  END IF;

  v_loop_id := v_rec.loop_id;

  -- Original Phase 1 anchors (same mapping + 1.75x body weight as Window 2)
  SELECT q5_raw_score, q6_raw_score
  INTO v_orig_q1_score, v_orig_q2_raw
  FROM phase1_assessments WHERE loop_id = v_loop_id;

  v_orig_q2_score := v_orig_q2_raw * 1.75;

  v_q1_new_score := answer_to_raw_score(p_q1_new_answer);
  v_q2_new_score := answer_to_raw_score(p_q2_new_answer) * 1.75;

  v_q1_delta := v_q1_new_score - v_orig_q1_score;
  v_q2_delta := v_q2_new_score - v_orig_q2_score;

  -- Reuse the classification engine to compute combined_delta (+ a record-keeping
  -- classification for the Window-3 row).
  SELECT * INTO v_result
  FROM compute_phase5_classification(v_q1_delta, v_q2_delta, p_q3_flag);

  UPDATE phase5_reassessments SET
    q1_trigger_answer    = p_q1_new_answer,
    q1_new_score         = v_q1_new_score,
    q1_original_score    = v_orig_q1_score,
    q1_delta             = v_q1_delta,
    q2_body_state_answer = p_q2_new_answer,
    q2_new_score         = v_q2_new_score,
    q2_original_score    = v_orig_q2_score,
    q2_delta             = v_q2_delta,
    q3_block_flag        = p_q3_flag,
    combined_delta       = v_result.combined_delta,
    classification       = v_result.classification
  WHERE id = p_reassessment_id;

  -- Run the climb engine on the now-populated Window-3 row
  v_calibration := apply_window3_calibration(p_reassessment_id);

  RETURN v_calibration;
END;
$function$;

CREATE OR REPLACE FUNCTION public.apply_window3_calibration(p_reassessment_id uuid)
 RETURNS user_calibration
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  -- ── Tunable constants (shape is locked; numbers calibrate against data) ──
  c_ceiling             CONSTANT NUMERIC := 500;   -- assessment hard cap
  c_flow_floor          CONSTANT NUMERIC := 480;   -- residence bar to earn flow
  c_flow_gate           CONSTANT INTEGER := 3;     -- consecutive loops before accrual
  c_retention_tolerance CONSTANT NUMERIC := 15;    -- max W2→W3 decay still "durable"
  c_flow_k              CONSTANT NUMERIC := 0.03;  -- asymptotic steepness
  c_flow_band           CONSTANT NUMERIC := 540;   -- Joy threshold (flow_resident)

  v_w3              phase5_reassessments%ROWTYPE;
  v_loop_id         UUID;
  v_user_id         UUID;
  v_cog             NUMERIC;
  v_w2_delta        NUMERIC;
  v_w2_class        phase5_classification;
  v_w2_confirmed    NUMERIC;
  v_w3_confirmed    NUMERIC;
  v_durable         BOOLEAN;
  v_cal             user_calibration%ROWTYPE;
  v_streak          INTEGER;
  v_floor           NUMERIC;
  v_calibrated      NUMERIC;
  v_units           INTEGER;
  v_peak            NUMERIC;
  v_flow_resident   BOOLEAN;
  v_result          user_calibration%ROWTYPE;
BEGIN
  -- 1. Load the Window-3 row
  SELECT * INTO v_w3 FROM phase5_reassessments WHERE id = p_reassessment_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reassessment % not found', p_reassessment_id;
  END IF;

  IF v_w3.user_id <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to calibrate this reassessment';
  END IF;

  IF v_w3.window_number <> 'window_3' THEN
    RAISE EXCEPTION 'Reassessment % is not a Window-3 row (got %)',
      p_reassessment_id, v_w3.window_number;
  END IF;

  v_loop_id := v_w3.loop_id;
  v_user_id := v_w3.user_id;

  -- 2. Original Phase 1 CoG for this loop (the ≤500 anchor)
  SELECT center_of_gravity INTO v_cog
  FROM phase1_assessments WHERE loop_id = v_loop_id;

  -- 3. Matching Window-2 row: its delta + classification
  SELECT combined_delta, classification
  INTO v_w2_delta, v_w2_class
  FROM phase5_reassessments
  WHERE loop_id = v_loop_id AND window_number = 'window_2';

  -- 4. Confirmed levels, clamped to the assessment ceiling (invariant: ≤500)
  v_w2_confirmed := LEAST(c_ceiling, GREATEST(0, v_cog + COALESCE(v_w2_delta, 0)));
  v_w3_confirmed := LEAST(c_ceiling, GREATEST(0, v_cog + COALESCE(v_w3.combined_delta, 0)));

  -- 5. Durability test: the loop must have genuinely ascended at W2,
  --    the gain must not have decayed past tolerance by day 21,
  --    and behaviour must not have regressed.
  v_durable := (v_w2_class = 'true_ascension')
           AND ((v_w2_confirmed - v_w3_confirmed) <= c_retention_tolerance)
           AND (v_w3.q3_block_flag IS DISTINCT FROM 'regression');

  -- 6. Load current calibration (defaults if first time)
  SELECT * INTO v_cal FROM user_calibration WHERE user_id = v_user_id;
  IF NOT FOUND THEN
    v_cal.consecutive_verified_loops := 0;
    v_cal.verified_floor := 0;
    v_cal.peak_level := 0;
  END IF;

  -- 7. Apply the climb / decay
  IF v_durable THEN
    v_streak := v_cal.consecutive_verified_loops + 1;
    v_floor  := LEAST(c_ceiling, GREATEST(v_cal.verified_floor, v_w3_confirmed));

    IF v_w3_confirmed >= c_flow_floor AND v_streak >= c_flow_gate THEN
      -- Asymptotic accrual above 500
      v_units      := v_streak - c_flow_gate;
      v_calibrated := c_ceiling + c_ceiling * (1 - EXP(-c_flow_k * v_units));
    ELSE
      -- Workable range: track the confirmed snapshot
      v_calibrated := v_w3_confirmed;
    END IF;
  ELSE
    -- Streak broken: reset flow eligibility, decay toward retained floor
    v_streak     := 0;
    v_floor      := v_cal.verified_floor;
    v_calibrated := GREATEST(v_cal.verified_floor, v_w3_confirmed);
  END IF;

  v_peak          := GREATEST(v_cal.peak_level, v_calibrated);
  v_flow_resident := v_calibrated >= c_flow_band;

  -- 8. Upsert
  INSERT INTO user_calibration AS uc (
    user_id, calibrated_level, verified_floor, consecutive_verified_loops,
    peak_level, flow_resident, last_durability_at, updated_at
  )
  VALUES (
    v_user_id, ROUND(v_calibrated, 2), ROUND(v_floor, 2), v_streak,
    ROUND(v_peak, 2), v_flow_resident, NOW(), NOW()
  )
  ON CONFLICT (user_id) DO UPDATE SET
    calibrated_level           = EXCLUDED.calibrated_level,
    verified_floor             = EXCLUDED.verified_floor,
    consecutive_verified_loops = EXCLUDED.consecutive_verified_loops,
    peak_level                 = EXCLUDED.peak_level,
    flow_resident              = EXCLUDED.flow_resident,
    last_durability_at         = EXCLUDED.last_durability_at,
    updated_at                 = EXCLUDED.updated_at
  RETURNING * INTO v_result;

  RETURN v_result;
END;
$function$;

CREATE OR REPLACE FUNCTION public.route_false_positive(p_reassessment_id uuid, p_resistance rediag_resistance, p_feeling rediag_feeling, p_pattern rediag_pattern, p_free_text text DEFAULT NULL::text)
 RETURNS rediag_classification
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_rediag              rediag_classification;
  v_new_track           ascension_track;
  v_loop_id             UUID;
  v_current_track       ascension_track;
  v_reassessment_user   UUID;
BEGIN
  -- Fetch context
  SELECT loop_id, user_id INTO v_loop_id, v_reassessment_user
  FROM phase5_reassessments WHERE id = p_reassessment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reassessment % not found', p_reassessment_id;
  END IF;

  IF v_reassessment_user <> auth.uid() THEN
    RAISE EXCEPTION 'Not authorized to route this reassessment';
  END IF;

  SELECT assigned_track INTO v_current_track
  FROM ascension_loops WHERE id = v_loop_id;

  -- Re-diagnosis routing matrix
  IF p_pattern = 'handled_differently' THEN
    -- User showed movement in Q3 despite flat scores → reclassify
    v_rediag    := 'reclassify_residual'::rediag_classification;
    v_new_track := v_current_track;  -- Continue same track at deeper layer

  ELSIF p_feeling = 'skepticism' THEN
    -- Method mismatch: rotate to a different format
    v_rediag := 'method_mismatch'::rediag_classification;
    v_new_track := CASE v_current_track
      WHEN 'completion'   THEN 'commitment'::ascension_track
      WHEN 'belief_audit' THEN 'embodiment'::ascension_track
      WHEN 'embodiment'   THEN 'belief_audit'::ascension_track
      WHEN 'commitment'   THEN 'completion'::ascension_track
    END;

  ELSIF p_resistance = 'specific' AND p_feeling IN ('relief', 'flatness') THEN
    -- Surface contact: reached the edge but structural layer remains
    v_rediag    := 'surface_contact'::rediag_classification;
    v_new_track := 'embodiment'::ascension_track;  -- Always body-first for structural work

  ELSE
    -- Default: compliance bypass — re-administer with Threshold Moment framing
    v_rediag    := 'compliance_bypass'::rediag_classification;
    v_new_track := v_current_track;

  END IF;

  -- Write rediag results to reassessment row
  UPDATE phase5_reassessments SET
    rediag_q1_resistance    = p_resistance,
    rediag_q2_feeling       = p_feeling,
    rediag_q3_pattern       = p_pattern,
    rediag_q4_free_text     = p_free_text,
    rediag_classification   = v_rediag,
    routing_outcome         = 'track_reassignment'::routing_outcome
  WHERE id = p_reassessment_id;

  -- Update the loop's assigned track for the next Phase 4 session
  UPDATE ascension_loops SET
    assigned_track = v_new_track
  WHERE id = v_loop_id;

  RETURN v_rediag;
END;
$function$;

-- No legitimate unauthenticated caller exists for any of these five --
-- close the wider hole get_advisors flagged (anon-execute on SECURITY
-- DEFINER functions) alongside the ownership guards above.
REVOKE EXECUTE ON FUNCTION public.compute_center_of_gravity(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.process_phase5_reassessment(uuid, p1_answer, p1_answer, q3_block_flag) FROM anon;
REVOKE EXECUTE ON FUNCTION public.process_window3_durability(uuid, p1_answer, p1_answer, q3_block_flag) FROM anon;
REVOKE EXECUTE ON FUNCTION public.apply_window3_calibration(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.route_false_positive(uuid, rediag_resistance, rediag_feeling, rediag_pattern, text) FROM anon;

COMMIT;
