-- =============================================================================
-- Migration: v1.1 -> v1.2   (STEP 2 of 2)
-- Recalibrate the scoring + zone functions to the TRUE Dodson scale.
--
-- Run this ONLY AFTER step 1 has been pushed and committed.
-- Both functions use CREATE OR REPLACE, so every caller
-- (compute_center_of_gravity, process_phase5_reassessment, the views, etc.)
-- automatically picks up the new logic. No signatures change, so nothing
-- downstream breaks.
-- =============================================================================

BEGIN;

-- =============================================================================
-- answer_to_raw_score : true Dodson Levels of Energy
-- =============================================================================
-- Dodson reference numbers (from the source text):
--   30  Guilt, Shame, Psychosis, Humiliation, Hatred
--   50  Apathy, Despair, Depression, Hopelessness
--   80  Grief, Sorrow, Self-Pity
--   100 Fear, Worry, Shyness, Inferiority, Paranoia
--   120 Craving, Need, Compulsion, Unfulfilled Desire
--   160 Anger, Domination, Aggression, Coldness
--   190 Pride, Superiority, Arrogance
--   200 Contentment, Routine, Functionality, Boredom   <- the critical line
--   275 Courage, Relaxation, Eagerness, Fun
--   320 Willingness, Kindness, Optimism, Activity
--   400 Acceptance, Interest, Attention, Neutrality
--   450 Intelligence, Knowledge, Reason
--   475+ Joy / Beauty / Power / Love / Peace / Bliss ...

CREATE OR REPLACE FUNCTION answer_to_raw_score(answer p1_answer)
RETURNS INTEGER
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE answer
    WHEN 'shame_apathy'            THEN 30   -- Shame / Humiliation floor
    WHEN 'apathy_grief'            THEN 65   -- Apathy (50) / Grief (80) blend
    WHEN 'fear'                    THEN 100  -- Fear, Worry, Paranoia
    WHEN 'desire'                  THEN 120  -- Craving, Unfulfilled Desire
    WHEN 'anger'                   THEN 160  -- Anger, Aggression, Coldness
    WHEN 'pride'                   THEN 190  -- Pride, Superiority, Arrogance
    WHEN 'contentment'             THEN 200  -- Contentment, Routine, Functionality
    WHEN 'courage'                 THEN 275  -- Courage, Relaxation, Eagerness
    WHEN 'willingness'             THEN 320  -- Willingness, Kindness, Optimism
    WHEN 'neutrality'              THEN 400  -- Acceptance, Interest, Neutrality
    WHEN 'reason'                  THEN 450  -- Intelligence, Knowledge, Reason
    WHEN 'love_flow'               THEN 530  -- Love, Intuition, Appreciation
    -- Deprecated conflated tokens (kept for enum stability; not written anymore):
    WHEN 'courage_neutrality'      THEN 275
    WHEN 'willingness_acceptance'  THEN 320
    ELSE 0
  END;
END;
$$;

-- =============================================================================
-- score_to_zone : recalibrated bands aligned to the Dodson numbers
-- =============================================================================
-- 200 stays the critical "functionality line" (boundary of the threshold zone),
-- which also keeps apply_downward_anchor_weight()'s "< 200" rule meaningful.
--
--   collapsed   30-80    Shame / Apathy / Grief
--   contracted  100-120  Fear / Desire
--   reactive    160-190  Anger / Pride
--   threshold   200-275  Contentment / Courage
--   builder     320-475  Willingness / Neutrality / Reason / Joy
--   flow        500+     Love / Peace / Bliss

CREATE OR REPLACE FUNCTION score_to_zone(score NUMERIC)
RETURNS energy_zone
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  RETURN CASE
    WHEN score < 90    THEN 'collapsed'::energy_zone
    WHEN score < 140   THEN 'contracted'::energy_zone
    WHEN score < 200   THEN 'reactive'::energy_zone
    WHEN score < 300   THEN 'threshold'::energy_zone
    WHEN score < 500   THEN 'builder'::energy_zone
    ELSE                    'flow'::energy_zone
  END;
END;
$$;

COMMIT;

-- =============================================================================
-- VALIDATION (run in SQL Editor after pushing):
--   SELECT answer_to_raw_score('courage');     -- 275
--   SELECT answer_to_raw_score('neutrality');  -- 400
--   SELECT answer_to_raw_score('reason');      -- 450
--   SELECT answer_to_raw_score('love_flow');   -- 530
--   SELECT score_to_zone(65);   -- collapsed
--   SELECT score_to_zone(120);  -- contracted
--   SELECT score_to_zone(190);  -- reactive
--   SELECT score_to_zone(275);  -- threshold
--   SELECT score_to_zone(450);  -- builder
--   SELECT score_to_zone(530);  -- flow
-- =============================================================================
