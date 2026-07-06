-- Record clamp state as a first-class fact for Phase 2.
--
-- Phase 2's Edge Function needs to know whether a single-assessment CoG was
-- clamped below the Flow boundary (LEAST(v_cog, 499.99), added in the
-- previous migration) so it can frame the reveal copy honestly. Deriving
-- "was clamped" downstream from center_of_gravity = 499.99 would be a guess
-- (a legitimate unclamped 499.99 average is arithmetically possible), so the
-- function captures the fact at the moment of computation.
--
-- Changes, relative to the deployed body (read back via pg_get_functiondef
-- 2026-07-06):
--   * phase1_assessments.was_clamped BOOLEAN NOT NULL DEFAULT FALSE
--   * v_was_clamped declared, set from (v_cog > 499.99) BEFORE the existing
--     clamp line, and written in the UPDATE. Nothing else changes.

BEGIN;

ALTER TABLE phase1_assessments
  ADD COLUMN IF NOT EXISTS was_clamped BOOLEAN NOT NULL DEFAULT FALSE;

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

  -- Compute Center of Gravity (weighted — the score the user is shown)
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

COMMIT;
