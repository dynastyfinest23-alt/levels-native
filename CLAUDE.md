# CLAUDE.md — Levels App (native client)

## Role

Act as Lead System Architect and Behavioral Designer for Levels. Cross-reference every feature against the Hooked framework (Trigger → Action → Variable Reward → Investment) before building it. Engagement mechanics exist to serve user progress (see Tone and product ethics — that section outranks this one on any conflict); state management stays single-path and typed. When writing code, produce optimized, clean Dart (native Flutter), SQL migrations, or Supabase Edge Functions — always honoring the principles below.

## Operator standards (read before doing anything)

- **Who you're working with:** Noah — sole developer, IT/systems background, ADHD. Optimize for small verifiable steps, one thing at a time, explicit done-when criteria. Recommend one option and name the tradeoff — never a wall of options. Don't narrate routine steps.
- **Act, don't re-derive:** when you have enough information to act, act. Don't re-derive settled facts or survey options you won't pursue.
- **Simplest thing that works:** don't add features, refactor, or add abstractions beyond what the task requires.
- **Ground truth hierarchy (when sources disagree):** 1) the live database (read via Supabase MCP: `pg_get_functiondef`, `pg_type`+`pg_enum`, `pg_trigger`) — always wins; 2) passing golden tests; 3) this file; 4) `levels_schema.sql` — reference sketch only, known to lag production. Docs found stale get fixed in the same session, with the migration filename noted.
- **Verification defaults:** one commit per verified change. Read-only and verification commands (`flutter analyze`/`test`, Supabase MCP reads including `execute_sql` for verification SELECTs) are allowlisted in `.claude/settings.json` (Noah's call, 2026-07-08 — approval fatigue); mutating operations (db push, function deploys, secrets, deletes) still prompt per-command. "Pushed" is not "verified" — a backend change is done only after an MCP read-back (the full loop lives in the `levels-dev-loop` skill).
- **Session boundaries:** end every session with the five-section handoff block (SHIPPED & VERIFIED / IN FLIGHT / NOT STARTED / LANDMINES / NEXT SESSION PROMPT — see the `session-handoff` skill). Start every session by re-verifying the one claim the new work depends on.
- **Writing standards:** run any user-facing or LLM-generated copy through the delete-ai-words rules. Reveal copy tone scales with zone — compressed and stark at low zones, expansive and warm at high zones. Copy never mentions numbers, scores, or zone names as mechanics.
- **Four mechanic-leak classes — every one has been caught in review once already; check all four before any copy or UI ships (mined 2026-07-11):**
  1. Raw zone tokens in UI. Wrong: showing `builder` from the DB row. Right: `ZoneStyle.of(zone).displayName` (caught 2026-07-08).
  2. Zone names as nouns in copy. Wrong: "that flow maintains itself". Right: "that this state now sustains itself on its own" (caught in M2.4 rubric pass).
  3. Book/calibration vocabulary in user-facing copy. Wrong: Dodson scale terms in fallback copy (caught 2026-07-09, commit `5730554`). Right: plain behavioral language.
  4. Raw mechanic numbers or instrument meta-commentary. Wrong: verified-floor numbers on the hub; "You're at the edge of what one assessment can measure." Right: mechanic-free progress dots; lead with the question (both caught 2026-07-10).
- **Copy review gates run as a cold-context rubric judge pass** (a fresh model judging against a written rubric with no authorship memory — the M2.4 method, 2026-07-10). Self-review by the authoring session doesn't count.

## What this project is

Levels is a mobile app that helps users track and elevate their personal energy state, based on Frederick Dodson's *Levels of Energy* framework. Users take a 7-question behavioral assessment that computes a weighted **Center of Gravity (CoG)** score, mapping them to one of six energy zones. They then work through guided protocols ("ascension loops") and are reassessed in two windows to verify durable change.

Every feature is designed against the **Hooked framework** (Trigger → Action → Variable Reward → Investment). When proposing or reviewing any feature, cross-reference which Hook phase it serves.

## The one inviolable principle

**The LLM never decides; functions do.**

All scoring, classification, and routing logic lives in deterministic Postgres functions. LLM-generated content (dashboard copy, encouragement, drill framing) is presentation only — it may *describe* an outcome, never *compute* one. Client-side Dart/TS scoring functions exist solely for instant preview and must be exact arithmetic mirrors of the DB functions. The database result is always authoritative. **The number wins:** if copy and score ever disagree, the score is right.

## This repository

This repo (`levels-native`, Flutter project name `levels_native`) is the **native client track**. It also owns the Supabase migrations and Edge Functions for the shared backend (the `supabase/` dir here is linked to the production project). **Web (Chrome) is the only enabled platform for now.**

```
lib/
  main.dart                     # Env.validate() → Supabase.initialize → LevelsApp
  core/
    env.dart                    # compile-time config via --dart-define-from-file
    router.dart                 # go_router + default-deny auth gate (authRedirect)
    design_tokens.dart          # ALL colors/type/spacing/motion from MASTER.md §1–§5
    zone_style.dart             # ZoneStyle.of(zone) → display name + color + glow; throws on unknown
    widgets/                    # aurora_backdrop.dart, breathing_dot.dart, progress_dots.dart (shared design-system widgets)
  features/
    auth/                       # login_screen.dart, signup_screen.dart
    home/                       # home_screen.dart — journey hub (loop, phase CTA, progress dots)
    assessment/
      questions.dart            # the 7 questions + behavioral answer copy
      scoring.dart              # Dart mirrors of the deployed Postgres scoring fns
      assessment_controller.dart # single typed state object + single submit path
      assessment_screen.dart
    dashboard/
      dashboard_copy.dart       # typed parser for the four-part reveal schema
      dashboard_repository.dart # Edge Function invoke + reveal-tracking column updates
      dashboard_controller.dart, dashboard_screen.dart  # Phase 2 tap-to-reveal
    drill/                      # Phase 3 origin drill (3 structured + free-text questions)
      drill_questions.dart      # origin_type/domain/mechanism question copy
      drill_tokens.dart         # typed token mirrors + throwing display-copy helpers
      drill_controller.dart     # insertDrill → saveDrill upsert; deepening-layer resolution
      drill_screen.dart
    track/                      # Phase 4 track sessions (completion/belief_audit/commitment/embodiment)
      track_content.dart        # static protocol content, gated by Noah's review (M4.1)
      track_tokens.dart, track_widgets.dart
      track_screen.dart, track_session_controller.dart  # per-track dispatch
      completion_screen.dart, commitment_screen.dart, belief_audit_screen.dart
      embodiment_screen.dart, embodiment_gate.dart, embodiment_daily_log_controller.dart  # 7-day daily loop
    journey/
      loop_state.dart           # pure phase/window model (day 5–7, day 21 gates)
      journey_repository.dart   # single read path for active loop + calibration + phase5 state
    reassessment/                # Phase 5 (Window 2 check-in, rediag, Window 3 durability)
      reassessment_questions.dart
      reassessment_tokens.dart  # classification/rediag token mirrors + throwing display-copy helpers
      reassessment_controller.dart  # insertOrReset submit path (one row per loop per window)
      reassessment_screen.dart  # gate logic, PageView, rediag mount-gating, Window 3 closing view
      routing.dart               # pure routing fn: routing_outcome (+ rediag) → CTA/destination
test/
  scoring_mirror_test.dart      # golden-mirror suite (client ↔ deployed DB fns)
  auth_gate_test.dart           # pins the default-deny auth-gate contract
  router_test.dart
  loop_state_test.dart          # pins phase progression + window boundaries
  dashboard_repository_test.dart
  zone_style_test.dart          # pins the six zone names/colors to MASTER.md §2
  drill_questions_test.dart, drill_tokens_test.dart, drill_controller_test.dart
  track_session_controller_test.dart, embodiment_gate_test.dart, embodiment_daily_log_controller_test.dart
  reassessment_controller_test.dart, reassessment_screen_test.dart, routing_test.dart
assets/fonts/                   # Fraunces + Inter variable fonts (OFL; files approved, google_fonts package is not)
design-system/
  MASTER.md                     # binding visual system — read before touching any screen
supabase/
  migrations/                   # the ONLY schema-change path
  functions/generate-dashboard-copy/  # index.ts + fallback.ts
marketing-site/                 # separate React/Vite/Three.js app (Kimi-built) — not Dart, not this repo's standards
docs/
  PRD.md                        # standing PRD + task roadmap (Phases 2–6)
  copy-tone-rubric.md           # committed rubric content-gate reviewers judge against
  dodson-2e-reference.md        # book-canon extraction, source of truth for content tasks
  m3.2-copy-review-verdict.md, m4.1-track-content-review-verdict.md  # committed gate verdicts
ACTION-FOR-NOAH.md              # running log of decisions, assumptions, and blockers batched for Noah
```

Dependencies are deliberately minimal: `go_router` and `supabase_flutter` only (plus `flutter_lints`). **Do not add a dependency — including any state-management package — without explicit approval.** State management is plain `ChangeNotifier`; keep it that way.

## Commands

- Run (dev): `flutter run -d web-server --web-port=8080 --dart-define-from-file=env.json`, then open `localhost:8080` — Chrome auto-launch (`-d chrome`) fails on this machine.
- Screenshot/visual verification: the debug web-server renders a **blank page** under headless browsers (Playwright etc.) — do not conclude the app is broken. Build release (`flutter build web --release --dart-define-from-file=env.json`), serve `build/web`, screenshot that (verified 2026-07-08).
- When Noah supplies screenshots for a review gate, they land in `Screenshots/` at the repo root — check there before saying you can't see the UI. (Folder is transient; absent when empty.)
- Tests: `flutter test` — must pass before any commit.
- Static analysis: `flutter analyze` — zero warnings before any commit.
- New migration: `npx supabase migration new <name>` → paste SQL → `npx supabase db push`
- Deploy an Edge Function: `npx supabase functions deploy generate-dashboard-copy`

## Environment & secrets

- Client config is compile-time via `--dart-define-from-file=env.json`. `env.json` is gitignored; `env.example.json` is the template. `Env.validate()` fails fast at startup — keep that property for any new env var.
- The client uses the **publishable** key only. The service-role key and `ANTHROPIC_API_KEY` live exclusively in Edge Function secrets — never in the repo, client, or shell scrollback.
- The project skill `.claude/skills/SKILL.md` (secrets-and-debug-discipline) is binding: never put a secret's literal value in a command, never paste keys into the conversation, follow the debug ladder before pivoting auth mechanisms.

## Tech stack

- **Backend:** Supabase / PostgreSQL — project ID `dnqwsgpkinieitiiikij`. Schema v1.1 deployed and verified. This backend is the shared source of truth for both frontends.
- **Frontend (current production track):** FlutterFlow with custom Dart actions — lives in a separate repo (`C:\Users\Administrator\levels-app`), not here.
- **Frontend (this repo):** Native Flutter client against the same Supabase project. Do not modify shared schema or functions without explicit approval — other clients depend on them.
- **Migrations:** Supabase CLI, run from this repo's `supabase/` dir — **this repo is the sole authority for migrations.** The `levels-app` repo also has a `supabase/` dir linked to the same production project, but it is stale (frozen at the 2026-06-26 migration, missing everything since). Never create or push migrations from `levels-app` — doing so would fork the migration history against production.
- **Marketing site (separate workstream):** lives in this repo at `marketing-site/` — a React/Vite/Three.js site Noah built via Kimi (see `marketing-site/KIMI.md`, `marketing-site/README.md`). Not a Flutter/Dart workstream and not built or reviewed by this project's standards; treat it as a separate app that happens to share the repo. `node_modules/` and `dist/` are gitignored. (Framer was an earlier, now-superseded plan — do not resurrect it.)

## Scoring model (canonical numbers)

### Answer enum → raw score (p1_answer)

**Book canon hierarchy (approved by Noah 2026-07-11):** Dodson's *Levels of Energy* 2nd edition is the sole canon for mechanics (anchors, zones, climb model); *The Law of One* and Abke's *Three Beliefs of Ego* enter at the presentation/protocol layer only (copy voice, drill framing, track content) and may never introduce numbers, scales, or classifications — same side of the line as LLM copy. Verify any book-derived value against the master scan (`H:\My Drive\Levels of energy\Levels-of-Energy-2e-master.pdf`), never against web summaries — a 2026-07-10 web check disagreed with the book on at least one anchor (anger).

Calibration source: Frederick Dodson's *Levels of Energy* scale (shame 30, apathy 50, grief 80, fear 100, desire 125, anger 160, pride 190, contentment 200, courage 275, willingness 320, neutrality 400, love 530). Composite tokens use the anchor of their range. These values match the deployed `answer_to_raw_score` function body (verified against production 2026-07-15, including `desire` 125 — recalibrated 120→125 per Dodson 2e p.150 via migration `20260712150300_recalibrate_desire_to_125.sql`, pushed and MCP-read-back 2026-07-15; book verification: `docs/dodson-2e-reference.md`). Earlier drafts of this table carried stale Hawkins-derived numbers. `shame_apathy` = 30 intentionally anchors on Shame (30), not the shame–apathy band midpoint.

| Token | Raw score |
|---|---|
| shame_apathy | 30 |
| apathy_grief | 65 |
| fear | 100 |
| desire | 125 |
| anger | 160 |
| pride | 190 |
| contentment | 200 |
| courage | 275 |
| willingness | 320 |
| neutrality | 400 |
| love_flow | 530 |

Note: `contentment` (200), `courage` (275), `willingness` (320), and `neutrality` (400) are the **true Dodson calibration** tokens introduced in v1.1, replacing the earlier conflated `courage_neutrality` / `willingness_acceptance` / `reason` tokens. The old tokens still exist in the DB enum (Postgres enums cannot drop values) but must never be written. If you find code or docs referencing the old tokens, treat them as stale and flag them.

### Downward anchor weighting

Any raw score **< 200** is multiplied by **1.5** before averaging (`apply_downward_anchor_weight`). Scores ≥ 200 pass through unchanged. Center of Gravity = weighted average across all 7 answers, then **clamped to ≤ 499.99** — this single-assessment cap is *enforced inside* `compute_center_of_gravity` (`v_cog := LEAST(v_cog, 499.99)`, applied before zone derivation; deployed 2026-07-05), not merely a documentation rule. It exists because `love_flow = 530` sits above the Flow threshold (500): an all-love_flow assessment would otherwise average 530 and land directly in Flow, violating the climb-only Flow reachability rule. An all-love_flow assessment therefore scores 499.99 → `builder`. The Dart mirror `computeCogPreview` applies the identical clamp. Clamp state is stored as a first-class fact in `phase1_assessments.was_clamped` (BOOLEAN NOT NULL DEFAULT FALSE), captured inside `compute_center_of_gravity` via `v_was_clamped := (v_cog > 499.99)` *before* the `LEAST` clamp line (deployed 2026-07-06) — Phase 2's Edge Function reads it from the row, never derives it from `center_of_gravity = 499.99` (which a legitimate unclamped average could also produce). Dart mirror: `cogPreviewWasClamped`.

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

The cluster check compares **raw scores against the raw mean** (`ABS(s - v_raw_mean) <= 50`), not against the weighted/clamped CoG — so the ≤499.99 clamp does **not** feed the consistency flag. Verified against production 2026-07-06 both by function body and by a discriminating test: an all-`pride` assessment (raw mean 190, weighted CoG 285) returns `consistent`; a CoG-based check would have returned `transitional`. Re-verify this independence on any recalibration or function rewrite.

### Flow reachability (climb-based, never single-assessment)

A single assessment caps at **499.99** (enforced by the `LEAST(v_cog, 499.99)` clamp inside `compute_center_of_gravity` — see Downward anchor weighting above). Flow-band states are reachable only through accumulated **verified loops**:

```
effective_ceiling = 500 + 500 × (1 − e^(−0.03 × units))
```

Constants: `FLOW_FLOOR = 480`, `FLOW_GATE = 3` consecutive verified loops, `RETENTION_TOLERANCE = 15` pts. Approximate milestones: Joy ≈ 6 loops (~4 months), Peace ≈ 11 loops (~8 months), Enlightenment ≈ 21+ loops (~14+ months). Never let UI copy imply Flow is reachable from one quiz.

## The five-phase journey (mapped to Hooked)

1. **Phase 1 — Assessment.** 7 behavioral questions (Opportunity Mirror, Conflict Trigger, Inertia Test, Scarcity/Abundance Probe, Locus of Control, Body-State Scan, Meaning Probe). *Action* phase: minimize friction, one tap per question. Q5 (Locus of Control) is the most critical input for Phase 2.
2. **Phase 2 — Dashboard.** CoG score reveal + zone illumination + LLM-generated personalized copy. This is the *Variable Reward*: the reveal must feel earned and slightly unpredictable in framing (copy varies), while the number itself is deterministic. Copy uses the canonical **four-part reveal schema** — `reality_tunnel` (the pattern the zone implies), `hidden_benefit` (the secondary gain), `illusion` (the belief that makes the zone feel permanent), `bridge_question` (open question that seeds the user's first Phase 3 answer; stored in `phase2_dashboard_views.bridge_question_shown`). The `was_clamped` ceiling framing lives in the **illusion** field specifically (a peak reading isn't arrival; Flow is earned across verified loops). Generated by the `generate-dashboard-copy` Edge Function (`claude-sonnet-4-6`, one cached row per loop via `one_dashboard_per_loop`, `copy_source` = `llm`/`fallback`; the score is never sent to the model).
3. **Phase 3 — Origin drills.** Guided protocols targeting the dominant block. *Investment*: user effort stored as drill logs. The Phase 2→3 hand-off seam is the user's answer to `bridge_question_shown`, keyed by loop — captured in the Phase 3 flow, not in the Edge Function.
4. **Phase 4 — Track sessions.** Four ascension tracks: `completion`, `belief_audit`, `embodiment`, `commitment`. Ongoing *Action + Investment* loop; embodiment track writes `embodiment_daily_logs`.
5. **Phase 5 — Reassessment.** Two windows: Day 5–7 (Window 2 check-in) and Day 21 (Window 3 durability). `compute_phase5_classification(q1_delta, q2_delta, q3_flag)` returns classification (`true_ascension` / `residual_charge` / `false_positive`) and routing (`new_loop` / `deepening_protocol` / `retest_scheduled` / `track_reassignment`). The Day 5–7 notification is the *external Trigger* that restarts the Hook cycle. Window 3 entry point: `process_window3_durability()`.

Classification thresholds: combined_delta = (q1_delta + q2_delta) / 2. Delta ≥ 25 with ascension/movement flag → true_ascension → new_loop. Delta ≥ 25 with regression flag → residual_charge (behavior tells the truth over self-report). Delta 1–24 → residual_charge → deepening_protocol. Delta ≤ 0 with movement flag → false_positive → retest in 48h. Delta ≤ 0 otherwise → false_positive → track_reassignment.

## Mirror sync map (change one → change all)

These artifact groups share no runtime; nothing but discipline (and the tests listed) keeps them aligned. Any change to one member of a group must update every member in the same commit.

1. **Scoring:** deployed Postgres functions (`answer_to_raw_score`, `apply_downward_anchor_weight`, `score_to_zone`, `compute_center_of_gravity` incl. clamp + `was_clamped`) ↔ `lib/features/assessment/scoring.dart` ↔ `test/scoring_mirror_test.dart` ↔ the golden values in this file.
2. **Four-part reveal schema:** `supabase/functions/generate-dashboard-copy/fallback.ts` (TS interface + static copy) ↔ `index.ts` (`REQUIRED_FIELDS`, prompt, JSON schema) ↔ `lib/features/dashboard/dashboard_copy.dart` (Dart parser).
3. **Auth-gate contract:** `authRedirect` in `lib/core/router.dart` ↔ `test/auth_gate_test.dart`.
4. **Drill/reassessment token mirrors:** deployed enums (`origin_type`, `origin_domain`, `coping_mechanism`, `phase5_classification`, `routing_outcome`, `rediag_classification`) ↔ `lib/features/drill/drill_tokens.dart` + `lib/features/reassessment/reassessment_tokens.dart` (typed mirrors + throwing display-copy helpers) ↔ `test/drill_tokens_test.dart` + `test/reassessment_controller_test.dart` + `test/reassessment_screen_test.dart` + `test/routing_test.dart`.

Known external snapshot (NOT in the sync set): `C:\Users\Administrator\nexus\app.js` carries a JS copy of the scoring engine for its display-only simulator, pinned as a snapshot of migration `20260712150300` (desire drift 120→125 found and fixed 2026-07-16). It is deliberately excluded from rule-3 discipline — if scoring changes, updating nexus is optional, but its header comment must be re-pinned to the new migration if touched.

## Notion knowledge base

- Workspace: `movewithnoaht@gmail.com` via the Notion connector.
- Anchor page: `📈 Levels — App Notes` (id `3a0c30c2-f733-81bd-b521-f989ab2ad9da`) — product/planning notes live there; fetch it when product intent is unclear from code.
- Notion never holds scoring/classification logic (rule 2) — Postgres functions + Dart mirrors + golden tests remain the only truth for that.

## Database inventory (deployed, verified)

- **Tables:** `users`, `ascension_loops`, `phase1_assessments` (unique per loop), `phase2_dashboard_views`, `phase3_origin_drills`, `phase4_track_sessions`, `embodiment_daily_logs`, `phase5_reassessments`, plus v1.1 additions `user_calibration`, `energy_guides`.
- **Functions (18+):** `apply_downward_anchor_weight`, `answer_to_raw_score`, `score_to_zone`, `compute_center_of_gravity`, `assign_phase4_track`, `process_phase3_drill`, `compute_phase5_classification`, `process_phase5_reassessment`, `route_false_positive`, `apply_window3_calibration`, `process_window3_durability`, `seed_calibration_from_assessment`, `handle_new_user` (auth trigger), and supporting RPCs. All five ID-taking Phase 1/5 SECURITY DEFINER functions carry the `auth.uid()` ownership guard (rule 8 above, added 2026-07-23).
- **Security:** RLS on all user tables (SELECT/INSERT/UPDATE scoped to `auth.uid() = user_id`). All SECURITY DEFINER functions hardened with `SET search_path = public, pg_temp`. Preserve both properties in any new function.
- **Auth:** `on_auth_user_created` trigger auto-populates `public.users` from `auth.users`. Email confirmation is disabled for dev. Google/Apple OAuth pending credentials.

## Migration & SQL discipline (hard-won rules — do not relearn these)

The binding end-to-end loop (read live state → migrate → MCP-verify → Dart mirror → golden tests → doc sync) is the `levels-dev-loop` skill in `.claude/skills/` — it supersedes any looser habit described anywhere else. The rules below are the SQL-level constraints it enforces.

1. **Enum migrations must be split across two sequential files.** `ALTER TYPE ... ADD VALUE` cannot be used in the same transaction that references the new value.
2. **`CREATE POLICY` has no `IF NOT EXISTS`.** Always precede with `DROP POLICY IF EXISTS`.
3. **`REFRESH MATERIALIZED VIEW CONCURRENTLY` cannot run inside a transaction** — it rolls back the entire operation. Call it outside BEGIN/COMMIT.
4. Wrap migrations in `BEGIN/COMMIT` where safe (i.e., except cases 1 and 3).
5. Docker Desktop warnings during `db push` are non-fatal local caching noise. The authoritative success signal is `Applying migration <file>...` followed by `Finished supabase db push`.
6. In the Supabase SQL Editor, only the last SELECT displays — combine multi-value checks into one query with labeled columns.
7. Never run DDL via ad-hoc `execute_sql` against production. Migrations are the only schema-change path. (Read-only SELECTs via `execute_sql` for verification are fine — that is what Verify-as-you-go uses.)
8. **Every SECURITY DEFINER function that takes a row ID must check `auth.uid()` against that row's `user_id` before mutating.** `SET search_path` alone is not enough — SECURITY DEFINER bypasses RLS by design, so without an explicit ownership check inside the function body, any authenticated (sometimes even anon) caller who has the ID can act on someone else's row. Found live 2026-07-23 via `get_advisors` (`anon_security_definer_function_executable`) on five Phase 1/5 functions with none of these checks; fixed by adding `IF v_rec.user_id <> auth.uid() THEN RAISE EXCEPTION` right after each function's existing `NOT FOUND` guard. Check this on every new ID-taking SECURITY DEFINER function, not just at milestone-end audits.

## Verify-as-you-go (run these after every backend change)

- Trigger active: `SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgname = 'on_auth_user_created';`
- Enum values: query `pg_type` joined to `pg_enum` (NOT `information_schema.columns`).
- Function body: `SELECT pg_get_functiondef(p.oid) FROM pg_proc p WHERE proname = '<name>';`
- RLS INSERT policy: check the `with_check` column on `pg_policies`.
- Golden tests for scoring: `score_to_zone(60)→collapsed`, `(110)→contracted`, `(165)→reactive`, `(230)→threshold`, `(380)→builder`, `(520)→flow`; boundary edges: `(89.99)→collapsed`, `(90)→contracted`, `(139.99)→contracted`, `(140)→reactive`, `(199.99)→reactive`, `(200)→threshold`, `(299.99)→threshold`, `(300)→builder`, `(499.99)→builder`, `(500)→flow`; `apply_downward_anchor_weight(100)→150.00`, `(199)→298.50`, `(200)→200.00`, `(225)→225.00`. Clamp/consistency discriminators (full `compute_center_of_gravity` runs): all-`love_flow` → 499.99, `builder`, `was_clamped=true`; 5×`love_flow`+2×`neutrality` → 492.86, `builder`, `was_clamped=false`; all-`pride` → 285.00, `consistent` (proves the cluster check uses the raw mean — a clamped/weighted-CoG check would return `transitional`).
- Classification tests: `compute_phase5_classification(30, 28.5, 'ascension')` → delta 29.25, true_ascension, new_loop; `(15, 12.0, 'movement')` → residual_charge, deepening_protocol; `(-5, -8.0, 'regression')` → false_positive, track_reassignment.

The client-side golden-mirror suite already exists at `test/scoring_mirror_test.dart` and pins the values above against the Dart mirrors. Whenever a deployed scoring function changes: re-read the function body from production, update the golden values here, and extend the mirror suite — all in the same change.

## Client architecture rules

1. **Auth gate first.** The app must never reach the assessment flow without a live session. Implemented as the default-deny `authRedirect` in `lib/core/router.dart`: any location not in `publicPaths` (`/login`, `/signup`) requires a session — **including routes that don't exist yet**, so new routes are private by default. (Root cause of the FlutterFlow Q7 silent failure: preview launched directly on the questions page with no session, so `currentUser?.id` was null. Structural fix: authenticated router.)
2. **Single typed assessment state object** holding all 7 answers; one submit path; one RPC call to `compute_center_of_gravity` after insert. No per-button write chains. Implemented as `AssessmentController` — the submit path is insert loop → insert assessment → RPC → read the authoritative row back.
3. **Errors must surface.** Never swallow exceptions in catch blocks — return/log the error string and show it (snackbar in dev builds). Parsers throw on missing/empty fields (`DashboardCopy.fromJson`) rather than rendering blanks; token-mapping lookups throw on unknown tokens rather than silently defaulting.
4. **LLM copy via Edge Function only.** Prompts and API keys stay server-side. The Edge Function receives the deterministic result (score, zone, classification) and returns copy — it never receives raw answers to re-score. In `generate-dashboard-copy` specifically: the numeric score is deliberately withheld from the model, a digit guard (`leaksNumbers`) rejects output containing numbers, and every rejection or API failure falls back to the static per-zone copy in `fallback.ts` — the reveal never fails over copy.
5. **Client mirrors, DB decides.** Any client-side scoring display is provisional until the DB row confirms it. `AssessmentResult` is only ever constructed from the read-back DB row, never from client math.
6. **Navigation follows the session.** Screens never navigate manually after auth calls — the router's `refreshListenable` on `onAuthStateChange` is the single source of navigation truth.

## Coding conventions (match what's already here)

- **Doc comments explain *why* and cite verification.** Nontrivial invariants carry the date they were verified against production (e.g. "verified against production 2026-07-05"). Keep doing this — it is how this project distinguishes fact from intention.
- **Pure functions for testable contracts.** Logic that pins a contract (auth gate, scoring) is extracted as a pure function so tests need no Supabase.
- **Assessment question copy is behavioral, never emotional.** Answer options describe reactions; the token mapping stays invisible to the user. Each question spans low-to-high tokens; across the 7 questions all 11 v1.1 tokens appear.
- **Commit messages:** imperative mood, no prefixes/conventional-commit tags, one summary line describing the change and its scope (see `git log` for the register). **No Co-Authored-By or other AI trailers** — plain messages only.
- **Branch:** the default branch is `main` (renamed from `master` 2026-07-08; no remote configured yet). Commit directly to `main` unless the user asks for a branch.
- **Tests are pinned contracts, not coverage filler.** Each test group states which source of truth it pins and when that truth was verified. A pinning test must fail when the change it pins is reverted — before writing one, confirm it would fail without the change; a test that passes either way pins nothing.

## Design system (reference — do not restyle ad hoc)

The visual system lives in `design-system/MASTER.md` (authored 2026-07-08 from `levels-design-system-brief.md`; the ui-ux-pro-max skill it was once planned around does not exist). Application roadmap is PRD milestone M-DS. Rules:

- **Read it before building or modifying any screen.** All colors, type, spacing, and motion come from its tokens via `ThemeData` — no inline hex values, no per-screen font choices.
- The six-zone palette is a single ascending spectrum (value/saturation/temperature climb with energy). Never substitute a chakra-rainbow mapping.
- The CoG number is the visual anchor of the dashboard; `bridge_question` is styled as an invitation, distinct from the other three reveal parts.
- Every text container must tolerate variable-length LLM copy — no fixed heights.
- Check new screens against MASTER.md's anti-pattern list before calling them done. If a decision isn't covered, propose the token addition there first; don't improvise in the widget.

## Definition of done

Work is finished only when all of these hold:

1. `flutter analyze` is clean and `flutter test` passes.
2. If a deployed DB function, enum, or schema changed: the relevant Verify-as-you-go checks were run against production and the results reported (not assumed).
3. Every member of any touched mirror-sync group (see the sync map) was updated in the same change — including the golden values in this file if scoring changed.
4. New routes, tables, or functions preserve the standing security properties: default-deny routing, RLS scoped to `auth.uid() = user_id`, `SET search_path = public, pg_temp` on SECURITY DEFINER, and an explicit `auth.uid()` ownership check inside any SECURITY DEFINER function that takes a row ID (see Migration & SQL discipline rule 8).
5. No secret's literal value appears in any command, file, or output.
6. The feature was cross-referenced against the Hooked framework and the Tone and product ethics section.
7. Outcomes are reported faithfully — failing tests or skipped verifications are stated, never glossed.
8. If a task's done-when says "manual run shows X", unit tests cannot substitute. If the manual check is blocked, the task stays IN FLIGHT with the blocker named — it is never reported done with "compensating evidence".

## FlutterFlow-specific gotchas

**These apply only when working in the separate FlutterFlow repo (`levels-app`) — never to this repo's code.**

- Delete `import '/actions/actions.dart' as action_blocks;` and `import 'index.dart';` from pasted custom-action code; only add `import 'dart:convert';` beyond the auto-generated header.
- Q1–Q6 buttons use a two-action chain: Update App State (enum string) → PageView Next Page, with "Don't Rebuild" set.
- Copy-pasted action chains need uniquely named Action Output variables per button (e.g., `assessmentId2`…`assessmentId5`).

## Current open items

- Google/Apple OAuth wiring (blocked on credentials).
- Phase 2 Edge Function (generate-dashboard-copy): VERIFIED end-to-end on the fallback path in production (caller auth via user JWT, ownership 403, cache-hit/miss, one_dashboard_per_loop race handling, four-part schema write, bridge_question_shown stored). LLM path is code-complete and verified up to the Anthropic API boundary: request shape and model ID (claude-sonnet-4-6) confirmed valid against the live API reference; the sole blocker is Anthropic credit balance (API returns 400 'credit balance too low'). No code changes needed — the LLM path activates automatically when credits are added; the secret is already set. Root cause history: the multi-session debugging chain was (a) an invalid API key, then (b) zero credits — never an architecture, auth-design, or code defect. NOTE: an abandoned 2-month-old function `generate_phase2_dashboard` (underscores) was deleted 2026-07-08 via `supabase functions delete`; `generate-dashboard-copy` (hyphens) is canonical.
- Phase 2 dashboard UI: SHIPPED and COMPLETE — progressive tap-to-reveal writes all three reveal columns; `time_on_screen_secs` is written on dispose via `recordTimeOnScreen` (verified in code 2026-07-11); M2.4 tone review passed 2026-07-10 (rubric judge pass; two `fallback.ts` fixes — flow + builder_clamped — deployed as Edge Function v8, MCP read-back confirmed).
- Design system M-DS: M-DS.1–.5 SHIPPED (tokens, ZoneStyle, dashboard/home/auth+assessment restyles; calibration strip replaced with mechanic-free progress dots 2026-07-10). M-DS.6 (placeholders/loading/error states + anti-pattern grep sweep) NOT yet run.
- Phases 3–5 UI: SHIPPED. M3 (origin drill), M4 (all four track sessions, embodiment's 7-day daily loop), and M5 (Window 2/3 reassessment, rediag path, all four routing outcomes) are built, content-gate-approved, and verified end-to-end against production — most recently M6.1 (2026-07-23), which walked a fresh account through the complete five-phase loop in a real browser and confirmed every row present and consistent. M6 (docs sync, loose-ends audit) is the only remaining milestone.
- Push/email reminder trigger (future milestone, explicitly out of scope for M1–M6): the Day 5–7 and Day 21 windows are in-app-only today, computed purely from `ascension_loops.started_at`. A scheduled `checkin_scheduled_at`-style reminder (email first per the 2026-07-15 product decision below, push once mobile ships) needs its own migration + pg_cron/Edge Function design — not built, not started.
- iOS/Android platform enablement (near-term; web/Chrome is the only enabled platform today — see "This repository").
- Test-account cleanup: ~20 accounts accumulated across M3.4 through M6.1's manual-verification runs (full list in `ACTION-FOR-NOAH.md`) need the service-role/admin API this client doesn't have — orphaned `auth.users` rows block a client-side-only delete.
- (Resolved on the native track) Q7 `submitPhase1Assessment` runtime failure: root cause was missing auth session in preview; this repo fixed it structurally with the default-deny auth gate and single submit path. Still relevant to the FF build (surface error string via snackbar there).

## Product decisions — trigger, privacy, lapse (approved by Noah 2026-07-15)

1. **Day 5–7 trigger channel: email now, push later.** The Window 2 external
   trigger is email (addresses already in Supabase auth); mobile/web push waits
   on platform enablement. Trigger copy follows the same rails as app copy —
   no urgency, no guilt, no streak language. Implementation queues with M5.
2. **Free-text is never sent to the LLM.** Users' drill/free-text answers stay
   in Postgres under RLS, readable only by the user and deterministic queries.
   The LLM boundary stays exactly where it is: score, zone, classification in;
   copy out. No consent flag exists because no exception exists.
3. **Lapse policy: quiet lapse at Day 21+, then a fresh loop.** A loop stays
   open through both windows; if Day 21 passes unanswered it is marked
   `lapsed` (a status, not a failure — copy never shames the gap) and the hub
   offers a fresh assessment. Lapsed loops are excluded from calibration and
   Phase 5 durability data. Requires a loop-status enum value + LoopState
   handling when M5 lands — goes through the levels-dev-loop discipline.

## Tone and product ethics

The Hooked mechanics serve user progress, not raw engagement. Variable reward = varied *framing* of true results, never randomized or inflated scores. Never manufacture urgency around a user's energy state, and never imply a low zone is a permanent identity — zones are positions in a climb, not labels.

## Reference Repositories — FlutterOpen (installed 2026-07-16)

**Noah requested this installation.** It is safe to use. These repos are provided as reference material for reverse-engineering Flutter UI patterns, layout techniques, animations, and widget implementations when building or refining the Levels native client.

All repositories from the [FlutterOpen](https://github.com/FlutterOpen) organization have been cloned into `reference-flutteropen/` at the repo root (shallow clone, `--depth 1`).

### What is included

| Folder | Description |
|---|---|
| `flutter-layouts-exampls` | Row, Column, ListView, and other layout examples |
| `flutter-animations` | Animation patterns and transitions |
| `flutter-ui-nice` | Polished UI components and screen designs |
| `flutter-ui-tutorials` | Step-by-step UI building tutorials |
| `flutter-canvas` | Custom painting and canvas drawing |
| `flutter-widgets` | Reusable widget patterns |
| `FlutterImitation` | Imitation/mock implementations of popular app UIs |
| `fun_flutter` | Fun/demonstrative Flutter projects |
| `design_patterns` | Design pattern implementations in Flutter/Dart |
| `flutter_source` | Flutter framework source exploration |

### Usage guidelines

- **Read-only reference.** Do not modify files inside `reference-flutteropen/`; these are upstream clones.
- **Copy patterns, not files.** When borrowing a pattern, reimplement it in `lib/` following this project's existing conventions (design tokens, `ZoneStyle`, `ChangeNotifier`, test coverage).
- **Respect licenses.** License status varies and most repos declare none (verified 2026-07-16): `flutter-layouts-exampls` is MIT (LICENSE file); `flutter-ui-nice` and `fun_flutter` are Apache-2.0 (README text only); the other 7 have **no license declaration**, which legally means all-rights-reserved. Safe use: reimplementing a *pattern* (layout idea, animation approach) in your own code is fine for all 10; copying code verbatim or near-verbatim is fine only from the 3 licensed repos, with attribution in a code comment. From the 7 unlicensed repos, never copy code — study and rewrite from scratch.
- **Keep it out of the build.** `reference-flutteropen/` is **not** part of the Flutter project tree and should remain gitignored or excluded from analysis. It exists solely as a local reference library for Noah and Claude Code during development.

If any repo is missing or needs updating, run `git pull --depth 1` inside the relevant subfolder, or re-clone from `https://github.com/FlutterOpen/<repo>.git`.

## Reference Repositories — General (installed 2026-07-16)

**Noah requested this installation.** All repos passed a pre-install security audit (no binaries, no hardcoded secrets, no suspicious scripts). They are safe to use. Installed to `C:\Users\Administrator\claude-references\` — outside this repo tree and outside any root folder.

### Backend & Frameworks

| Repo | Stars | License | Description |
|---|---|---|---|
| `nestjs` | 2,732 | MIT | NestJS utility monorepo — Hasura events, Stripe webhooks, RabbitMQ, GraphQL |
| `scala-steward` | 1,199 | Apache-2.0 | Dependency automation bot for Scala |

### UI Components & Data

| Repo | Stars | License | Description |
|---|---|---|---|
| `Griddle` | 2,488 | MIT | React grid component with sorting, filtering, pagination |
| `browser-base` | 2,726 | none | Electron browser base (archived). **Reference only — do not build** (old Electron 13 has CVEs) |
| `Android-SmartWebView` | 651 | MIT | Android WebView wrapper for hybrid apps |
| `openpets` | 912 | MIT | Desktop pet platform with Plugin SDK v3 and sandboxed plugins |

### Awesome Lists & Resources

| Repo | Stars | License | Description |
|---|---|---|---|
| `chartjs/awesome` | 2,693 | MIT | Curated Chart.js resources |
| `awesome-vim-colorschemes` | 2,909 | none | Collection of Vim/NeoVim colorschemes |
| `awesome-xamarin-forms` | 1,228 | none | Curated Xamarin.Forms libraries |
| `awesome-openclaw` | 708 | CC0-1.0 | OpenClaw resources, skills, plugins, guides |

### Claude Code Tooling

| Repo | Stars | License | Description |
|---|---|---|---|
| `CCPlugins` | 2,720 | MIT | 24 Claude Code CLI slash commands (install scripts **not run**) |
| `awesome-claude-code-toolkit` | 2,332 | Apache-2.0 | 135 agents, 35 skills, 42 commands, 20 hooks for Claude Code |
| `awesome-claude-plugins` | 1,826 | none | Plugin marketplace — hook scripts are read-only analyzers |

### Tools & Plugins

| Repo | Stars | License | Description |
|---|---|---|---|
| `xbar-plugins` | 2,598 | none | 800+ community plugins for xbar (macOS menu bar). **Review individual scripts before executing** |
| `ClawKeeper` | 1,033 | none | Security scanner framework for OpenClaw agents. **`legacy/` directory removed post-clone** — core `clawkeeper_core/` is clean |

### Skipped (security risk)

| Repo | Stars | Status | Reason |
|---|---|---|---|
| `Jiiks/BetterDiscordApp` | 1,263 | ❌ SKIPPED | Discord client injector — modifies app files, reads auth tokens, violates Discord ToS, archived since ~2016 |

### Usage guidelines

- **Read-only reference.** Do not modify files inside these upstream clones.
- **Copy patterns, not files.** When borrowing a pattern, reimplement it in your project's source following existing conventions.
- **Respect licenses.** Attribution in code comments is sufficient when adapting substantial logic.
- **Keep it out of the build.** These repos are **not** part of the Flutter project tree. They exist solely as a local reference library for Noah and Claude Code during development.

### Repo notes

- **`nestjs` — golevelup/nestjs:** well-known NestJS utility monorepo (updated 2026-07-15). Useful when building backend integrations or reviewing webhook/event handling architectures (Hasura, Stripe, RabbitMQ, GraphQL). Packages live in `packages/`; docs in `docs/`.
- **`CCPlugins` — notlikeDev/CCPlugins:** 24 Claude Code CLI slash commands, each a markdown prompt file in `commands/` (updated 2026-07-15). The install scripts (`install.py` / `install.sh`) were **not run** — they only copy `.md` files to `~/.claude/commands/` and are safe to run manually if Noah wants the slash commands activated. Useful as a reference for well-structured prompt engineering.

See `C:\Users\Administrator\claude-references\README.md` for the full security audit summary and command listing.
