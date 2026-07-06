# CLAUDE.md — Levels App

## Role

Act as Lead System Architect and Behavioral Designer for Levels. Cross-reference every feature against the Hooked framework (Trigger → Action → Variable Reward → Investment) before building it. Prioritize user engagement mechanics and seamless state management. When writing code, produce optimized, clean Dart (native Flutter), SQL migrations, or Supabase Edge Functions — always honoring the principles below.

## What this project is

Levels is a mobile app that helps users track and elevate their personal energy state, based on Frederick Dodson's *Levels of Energy* framework. Users take a 7-question behavioral assessment that computes a weighted **Center of Gravity (CoG)** score, mapping them to one of six energy zones. They then work through guided protocols ("ascension loops") and are reassessed in two windows to verify durable change.

Every feature is designed against the **Hooked framework** (Trigger → Action → Variable Reward → Investment). When proposing or reviewing any feature, cross-reference which Hook phase it serves.

## The one inviolable principle

**The LLM never decides; functions do.**

All scoring, classification, and routing logic lives in deterministic Postgres functions. LLM-generated content (dashboard copy, encouragement, drill framing) is presentation only — it may *describe* an outcome, never *compute* one. Client-side Dart/TS scoring functions exist solely for instant preview and must be exact arithmetic mirrors of the DB functions. The database result is always authoritative.

## Tech stack

- **Backend:** Supabase / PostgreSQL — project ID `dnqwsgpkinieitiiikij`. Schema v1.1 deployed and verified. This backend is the shared source of truth for both frontends.
- **Frontend (current production track):** FlutterFlow with custom Dart actions.
- **Frontend (this build):** Native client built with Claude Code against the same Supabase project. Do not modify shared schema or functions without explicit approval — other clients depend on them.
- **Migrations:** Supabase CLI. `npx supabase migration new <name>` → paste SQL → `npx supabase db push`. Repo working dir mirrors `C:\Users\Administrator\levels-app`.
- **Marketing site (separate workstream):** Framer.

## Scoring model (canonical numbers)

### Answer enum → raw score (p1_answer)

Calibration source: Frederick Dodson's *Levels of Energy* scale (shame 30, apathy 50, grief 80, fear 100, desire 120, anger 160, pride 190, contentment 200, courage 275, willingness 320, neutrality 400, love 530). Composite tokens use the anchor of their range. These values match the deployed `answer_to_raw_score` function body (verified against production 2026-07-03); earlier drafts of this table carried stale Hawkins-derived numbers. `shame_apathy` = 30 intentionally anchors on Shame (30), not the shame–apathy band midpoint.

| Token | Raw score |
|---|---|
| shame_apathy | 30 |
| apathy_grief | 65 |
| fear | 100 |
| desire | 120 |
| anger | 160 |
| pride | 190 |
| contentment | 200 |
| courage | 275 |
| willingness | 320 |
| neutrality | 400 |
| love_flow | 530 |

Note: `contentment` (200), `courage` (275), `willingness` (320), and `neutrality` (400) are the **true Dodson calibration** tokens introduced in v1.1, replacing the earlier conflated `courage_neutrality` / `willingness_acceptance` / `reason` tokens. The old tokens still exist in the DB enum (Postgres enums cannot drop values) but must never be written. If you find code or docs referencing the old tokens, treat them as stale and flag them.

### Downward anchor weighting

Any raw score **< 200** is multiplied by **1.5** before averaging (`apply_downward_anchor_weight`). Scores ≥ 200 pass through unchanged. Center of Gravity = weighted average across all 7 answers, then **clamped to ≤ 499.99** — this single-assessment cap is *enforced inside* `compute_center_of_gravity` (`v_cog := LEAST(v_cog, 499.99)`, applied before zone derivation; deployed 2026-07-05), not merely a documentation rule. It exists because `love_flow = 530` sits above the Flow threshold (500): an all-love_flow assessment would otherwise average 530 and land directly in Flow, violating the climb-only Flow reachability rule. An all-love_flow assessment therefore scores 499.99 → `builder`. The Dart mirror `computeCogPreview` applies the identical clamp.

### Score → zone (score_to_zone)

Boundaries match the deployed `score_to_zone` function body (upper bounds exclusive; verified against production 2026-07-03).

| Zone | Range |
|---|---|
| collapsed | < 90 |
| contracted | 90–139 |
| reactive | 140–199 |
| threshold | 200–299 |
| builder | 300–499 |
| flow | 500+ |

### Consistency flag

`consistent` (3+ answers cluster within ±50 pts), `transitional` (moderate variance), `scattered` (high variance → energetically inconsistent flag set).

### Flow reachability (climb-based, never single-assessment)

A single assessment caps at **499.99** (enforced by the `LEAST(v_cog, 499.99)` clamp inside `compute_center_of_gravity` — see Downward anchor weighting above). Flow-band states are reachable only through accumulated **verified loops**:

```
effective_ceiling = 500 + 500 × (1 − e^(−0.03 × units))
```

Constants: `FLOW_FLOOR = 480`, `FLOW_GATE = 3` consecutive verified loops, `RETENTION_TOLERANCE = 15` pts. Approximate milestones: Joy ≈ 6 loops (~4 months), Peace ≈ 11 loops (~8 months), Enlightenment ≈ 21+ loops (~14+ months). Never let UI copy imply Flow is reachable from one quiz.

## The five-phase journey (mapped to Hooked)

1. **Phase 1 — Assessment.** 7 behavioral questions (Opportunity Mirror, Conflict Trigger, Inertia Test, Scarcity/Abundance Probe, Locus of Control, Body-State Scan, Meaning Probe). *Action* phase: minimize friction, one tap per question. Q5 (Locus of Control) is the most critical input for Phase 2.
2. **Phase 2 — Dashboard.** CoG score reveal + zone illumination + LLM-generated personalized copy. This is the *Variable Reward*: the reveal must feel earned and slightly unpredictable in framing (copy varies), while the number itself is deterministic.
3. **Phase 3 — Origin drills.** Guided protocols targeting the dominant block. *Investment*: user effort stored as drill logs.
4. **Phase 4 — Track sessions.** Four ascension tracks: `completion`, `belief_audit`, `embodiment`, `commitment`. Ongoing *Action + Investment* loop; embodiment track writes `embodiment_daily_logs`.
5. **Phase 5 — Reassessment.** Two windows: Day 5–7 (Window 2 check-in) and Day 21 (Window 3 durability). `compute_phase5_classification(q1_delta, q2_delta, q3_flag)` returns classification (`true_ascension` / `residual_charge` / `false_positive`) and routing (`new_loop` / `deepening_protocol` / `retest_scheduled` / `track_reassignment`). The Day 5–7 notification is the *external Trigger* that restarts the Hook cycle. Window 3 entry point: `process_window3_durability()`.

Classification thresholds: combined_delta = (q1_delta + q2_delta) / 2. Delta ≥ 25 with ascension/movement flag → true_ascension → new_loop. Delta ≥ 25 with regression flag → residual_charge (behavior tells the truth over self-report). Delta 1–24 → residual_charge → deepening_protocol. Delta ≤ 0 with movement flag → false_positive → retest in 48h. Delta ≤ 0 otherwise → false_positive → track_reassignment.

## Database inventory (deployed, verified)

- **Tables:** `users`, `ascension_loops`, `phase1_assessments` (unique per loop), `phase2_dashboard_views`, `phase3_origin_drills`, `phase4_track_sessions`, `embodiment_daily_logs`, `phase5_reassessments`, plus v1.1 additions `user_calibration`, `energy_guides`.
- **Functions (13+):** `apply_downward_anchor_weight`, `answer_to_raw_score`, `score_to_zone`, `compute_center_of_gravity`, `compute_phase5_classification`, `process_phase5_reassessment`, `apply_window3_calibration`, `process_window3_durability`, `handle_new_user` (auth trigger), and supporting RPCs.
- **Security:** RLS on all user tables (SELECT/INSERT/UPDATE scoped to `auth.uid() = user_id`). All SECURITY DEFINER functions hardened with `SET search_path = public, pg_temp`. Preserve both properties in any new function.
- **Auth:** `on_auth_user_created` trigger auto-populates `public.users` from `auth.users`. Email confirmation is disabled for dev. Google/Apple OAuth pending credentials.

## Migration & SQL discipline (hard-won rules — do not relearn these)

1. **Enum migrations must be split across two sequential files.** `ALTER TYPE ... ADD VALUE` cannot be used in the same transaction that references the new value.
2. **`CREATE POLICY` has no `IF NOT EXISTS`.** Always precede with `DROP POLICY IF EXISTS`.
3. **`REFRESH MATERIALIZED VIEW CONCURRENTLY` cannot run inside a transaction** — it rolls back the entire operation. Call it outside BEGIN/COMMIT.
4. Wrap migrations in `BEGIN/COMMIT` where safe (i.e., except cases 1 and 3).
5. Docker Desktop warnings during `db push` are non-fatal local caching noise. The authoritative success signal is `Applying migration <file>...` followed by `Finished supabase db push`.
6. In the Supabase SQL Editor, only the last SELECT displays — combine multi-value checks into one query with labeled columns.
7. Never run DDL via ad-hoc `execute_sql` against production. Migrations are the only schema-change path.

## Verify-as-you-go (run these after every change)

- Trigger active: `SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgname = 'on_auth_user_created';`
- Enum values: query `pg_type` joined to `pg_enum` (NOT `information_schema.columns`).
- Function body: `SELECT pg_get_functiondef(p.oid) FROM pg_proc p WHERE proname = '<name>';`
- RLS INSERT policy: check the `with_check` column on `pg_policies`.
- Golden tests for scoring: `score_to_zone(60)→collapsed`, `(110)→contracted`, `(165)→reactive`, `(230)→threshold`, `(380)→builder`, `(520)→flow`; boundary edges: `(89.99)→collapsed`, `(90)→contracted`, `(139.99)→contracted`, `(140)→reactive`, `(199.99)→reactive`, `(200)→threshold`, `(299.99)→threshold`, `(300)→builder`, `(499.99)→builder`, `(500)→flow`; `apply_downward_anchor_weight(100)→150.00`, `(199)→298.50`, `(200)→200.00`, `(225)→225.00`.
- Classification tests: `compute_phase5_classification(30, 28.5, 'ascension')` → delta 29.25, true_ascension, new_loop; `(15, 12.0, 'movement')` → residual_charge, deepening_protocol; `(-5, -8.0, 'regression')` → false_positive, track_reassignment.

Maintain an automated client-side test suite that asserts the Dart/TS mirror functions produce identical outputs to these golden values, so client/DB drift is caught in CI.

## Client architecture rules

1. **Auth gate first.** The app must never reach the assessment flow without a live session. (Root cause of the FlutterFlow Q7 silent failure: preview launched directly on the questions page with no session, so `currentUser?.id` was null. Structural fix: authenticated router.)
2. **Single typed assessment state object** holding all 7 answers; one submit path; one RPC call to `compute_center_of_gravity` after insert. No per-button write chains.
3. **Errors must surface.** Never swallow exceptions in catch blocks — return/log the error string and show it (snackbar in dev builds).
4. **LLM copy via Edge Function only.** Prompts and API keys stay server-side. The Edge Function receives the deterministic result (score, zone, classification) and returns copy — it never receives raw answers to re-score.
5. **Client mirrors, DB decides.** Any client-side scoring display is provisional until the DB row confirms it.

## FlutterFlow-specific gotchas (relevant when touching the FF track)

- Delete `import '/actions/actions.dart' as action_blocks;` and `import 'index.dart';` from pasted custom-action code; only add `import 'dart:convert';` beyond the auto-generated header.
- Q1–Q6 buttons use a two-action chain: Update App State (enum string) → PageView Next Page, with "Don't Rebuild" set.
- Copy-pasted action chains need uniquely named Action Output variables per button (e.g., `assessmentId2`…`assessmentId5`).

## Current open items

- Q7 `submitPhase1Assessment` runtime failure — root cause is missing auth session in preview; fix structurally via auth gate (native build) / surface error string via snackbar (FF build).
- Google/Apple OAuth wiring (blocked on credentials).
- Phase 2 dashboard build (LLM copy layer, Edge Function).
- Phases 3–5 UI.
- Framer marketing site with animated score visualization and zone illumination.

## Tone and product ethics

The Hooked mechanics serve user progress, not raw engagement. Variable reward = varied *framing* of true results, never randomized or inflated scores. Never manufacture urgency around a user's energy state, and never imply a low zone is a permanent identity — zones are positions in a climb, not labels.
