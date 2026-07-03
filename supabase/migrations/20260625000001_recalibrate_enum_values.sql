-- =============================================================================
-- Migration: v1.1 -> v1.2   (STEP 1 of 2)
-- Recalibrate p1_answer to the TRUE Frederick Dodson "Levels of Energy" scale.
--
-- This step ONLY adds new enum values. It MUST be committed before Step 2,
-- because Postgres forbids USING a newly added enum value in the same
-- transaction that adds it.
--
-- Apply order:
--   1. supabase db push   (runs this file)
--   2. supabase db push   (runs step 2)
-- =============================================================================

BEGIN;

-- New Dodson-aligned tiers. These resolve the two previously conflated tokens
-- (courage_neutrality, willingness_acceptance) into discrete bands:
--
--   contentment (200) -- Contentment, Routine, Functionality, Boredom
--   courage     (275) -- Courage, Relaxation, Eagerness, Fun
--   willingness (320) -- Willingness, Kindness, Optimism, Activity
--   neutrality  (400) -- Acceptance, Interest, Attention, Neutrality
--
-- IF NOT EXISTS makes this re-runnable without error.

ALTER TYPE p1_answer ADD VALUE IF NOT EXISTS 'contentment';
ALTER TYPE p1_answer ADD VALUE IF NOT EXISTS 'courage';
ALTER TYPE p1_answer ADD VALUE IF NOT EXISTS 'willingness';
ALTER TYPE p1_answer ADD VALUE IF NOT EXISTS 'neutrality';

COMMIT;

-- The old tokens 'courage_neutrality' and 'willingness_acceptance' are left in
-- the enum (Postgres cannot drop enum values cleanly) but are deprecated and
-- no longer written by the app. Step 2 maps them to safe fallback scores.
