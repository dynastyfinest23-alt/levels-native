-- Recalibrate the `desire` anchor from 120 to 125 to match Dodson 2e (printed p. 150,
-- heading "125: Craving, Neediness, Addiction, Compulsion, Unfulfilled Desire, Longing,
-- Obsession"). Book-verification source: docs/dodson-2e-reference.md (2026-07-12).
-- Only the numeric anchor changes; the concept mapping ("Craving, Unfulfilled Desire")
-- already matched. All other anchors verified as matching the book and are unchanged.
--
-- Function replace only (no enum change, no matview) — safe to wrap in a transaction.
-- Body is copied verbatim from the deployed definition (read back 2026-07-12) with the
-- single `desire` line changed, preserving IMMUTABLE, the reason=450 line, and the
-- deprecated conflated tokens kept for enum stability.

BEGIN;

CREATE OR REPLACE FUNCTION public.answer_to_raw_score(answer p1_answer)
 RETURNS integer
 LANGUAGE plpgsql
 IMMUTABLE
AS $function$
BEGIN
  RETURN CASE answer
    WHEN 'shame_apathy'            THEN 30   -- Shame / Humiliation floor
    WHEN 'apathy_grief'            THEN 65   -- Apathy (50) / Grief (80) blend
    WHEN 'fear'                    THEN 100  -- Fear, Worry, Paranoia
    WHEN 'desire'                  THEN 125  -- Craving, Unfulfilled Desire (Dodson 2e p.150)
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
$function$;

COMMIT;
