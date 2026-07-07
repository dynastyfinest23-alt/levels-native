-- Phase 2 dashboard copy provenance columns.
--
-- The generate-dashboard-copy Edge Function writes one cached row per loop
-- (one_dashboard_per_loop UNIQUE constraint, verified in production
-- 2026-07-06). These columns record how the copy was produced:
--   copy_source  — 'llm' (Anthropic API) or 'fallback' (static zone copy).
--   generated_at — when the copy was generated (distinct from viewed_at,
--                  which tracks when the user saw the dashboard).

BEGIN;

ALTER TABLE phase2_dashboard_views
  ADD COLUMN IF NOT EXISTS copy_source TEXT,
  ADD COLUMN IF NOT EXISTS generated_at TIMESTAMPTZ;

COMMIT;
