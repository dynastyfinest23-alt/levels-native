# PRD & Roadmap — Levels native client: full five-phase journey

Standing plan for completing the Levels native client from its current state
(auth + Phase 1 assessment + result placeholder) to the full 21-day ascension
loop (Phases 2–5). Written to be executed task-by-task by any model without
the author present. **Read `CLAUDE.md` in full before starting any task —
every rule there is binding and overrides convenience.** Schema facts below
were read from production (project `dnqwsgpkinieitiiikij`) on 2026-07-08.

---

## 0. NOW (next ~2 weeks)

- **Current milestone:** M3, M4.1, M4.2, M4.3, M4.4 all COMPLETE. M4.5
  (embodiment screen + 7-day daily loop) COMPLETE 2026-07-18 — manually
  verified end-to-end through day 7 (session screen, day 1, and days 6-7
  via SQL-backdated `started_at`). M4.6 (hub integration — track progress
  + daily CTA) COMPLETE 2026-07-19 — manually verified in-browser. All
  Phase 4 work is now built and wired into the hub. M5 (Phase 5
  reassessment) is next.
- **Resolved:** love_flow 530-vs-550 — Noah decided to defer, keep 530
  (`ACTION-FOR-NOAH.md`, 2026-07-16). No scoring artifact touched.
- **Flagged for cleanup:** a real test account created during M3.4's manual
  verification run needs deletion alongside the existing parked
  test-account cleanup item (`ACTION-FOR-NOAH.md`).
- **Parked on purpose:** Dodson extraction doc (done — see
  `docs/dodson-2e-reference.md`); OAuth (blocked on credentials); test-account
  deletion (needs Noah's ID list); marketing site (separate workstream, own
  standards).
- This section is refreshed at every gate close and session handoff.

## 1. OBJECTIVE

Build the remaining client journey of Levels, a consciousness-tracking app.
A user signs up, takes a 7-question behavioral assessment that computes a
deterministic Center of Gravity (CoG) score and energy zone (Phase 1 —
already built), sees a personalized dashboard reveal (Phase 2), diagnoses the
origin of their dominant emotional block (Phase 3), works a matched
behavioral track across the loop (Phase 4), and is reassessed in two windows
— Day 5–7 and Day 21 — to verify the elevation is durable (Phase 5). A
verified loop raises their calibrated floor; accumulated verified loops are
the only path to the Flow band.

The user is someone actively working on their inner state who wants evidence
of change, not affirmations. The outcome: a user can complete an entire loop
— assessment through Day-21 durability check — in the web app, with every
score, classification, and routing decision computed by deployed Postgres
functions and every screen faithfully displaying (never computing) those
results.

## 2. CONTEXT

### Already built and working (do not rebuild, do not break)

- **Backend (production, verified):** all tables, enums, and functions for
  all five phases are deployed. Scoring (`compute_center_of_gravity` with
  the ≤499.99 clamp and `was_clamped` capture), zone mapping, Phase 3→4
  track routing (`assign_phase4_track`), Phase 5 classification
  (`compute_phase5_classification`, `process_phase5_reassessment`,
  `process_window3_durability`, `route_false_positive`,
  `apply_window3_calibration`), and the `seed_calibration_from_assessment`
  trigger all exist. RLS on all user tables; SECURITY DEFINER functions
  hardened with `SET search_path = public, pg_temp`.
- **Client:** auth (login/signup), default-deny router
  (`lib/core/router.dart`), Phase 1 assessment flow
  (`lib/features/assessment/`), Dart scoring mirrors + golden-mirror test
  suite, `DashboardCopy` parser (`lib/features/dashboard/dashboard_copy.dart`).
- **Edge Function:** `generate-dashboard-copy` — deployed and verified on
  the fallback path; LLM path is code-complete and blocked only on Anthropic
  credits. It caches one row per loop in `phase2_dashboard_views`.
- **Project skills:** `levels-verify` (production verification suite) and
  `levels-dev-loop` (migration runbook). Use them exactly when their
  descriptions say to.

### Deployed schema the client will consume (verified 2026-07-08)

Only the columns the client touches are listed; all tables also carry
`id uuid PK`, `user_id uuid`, and RLS scoped to `auth.uid() = user_id`.

- **`ascension_loops`**: `loop_number int`, `started_at timestamptz`
  (default now(); the window clock), `completed_at`, `status loop_status`
  (`active`/`complete`/`stalled`), `entry_score`, `exit_score`,
  `entry_zone`, `exit_zone`, `assigned_track ascension_track`.
- **`phase2_dashboard_views`**: `loop_id` (UNIQUE via
  `one_dashboard_per_loop`), `zone_shown`, `generated_copy jsonb`,
  `bridge_question_shown text`, `reality_tunnel_read bool`,
  `hidden_benefit_opened bool`, `illusion_opened bool`,
  `time_on_screen_secs int`, `copy_source`, `generated_at`, `viewed_at`.
- **`phase3_origin_drills`**: `loop_id`, `completed_at`,
  `q1_origin_type origin_type`, `q2_domain origin_domain`,
  `q3_mechanism coping_mechanism`, `q1_free_text`, `q2_free_text`,
  `q3_free_text`, `assigned_protocol` (ascension_track), `protocol_rationale
  text`, `deepening_layer int default 1`.
- **`phase4_track_sessions`**: `loop_id`, `user_id`, `track_type
  ascension_track`, `started_at`, `completed_at`, `success_state_reached
  bool`, `integrity_check_triggered bool`, plus per-track columns —
  embodiment: `body_location_tapped`, `sensation_words text[]`,
  `stage4_response stage4_response` (`shifted`/`intensified`/`same`);
  completion: `completion_statement`, `preparation_duration prep_duration`
  (**column name corrected 2026-07-16 — verified live via
  `information_schema.columns`; the enum type is `prep_duration` but the
  column is `preparation_duration`, not `prep_duration`**);
  belief_audit: `flagged_beliefs text[]`, `belief_authorship_age int[]`
  (**corrected 2026-07-16 — verified live; age is stored as an integer
  array, not `text[]`**), `belief_authorship_source text[]`,
  `cross_exam_verdict belief_verdict[]` (`fact`/`conclusion`);
  commitment: `declaration_text`, `constraint_chosen constraint_type`
  (`time`/`resource`/`audience`), `checkin_scheduled_at`,
  `checkin_response checkin_response` (`yes`/`partially`/`no`),
  `checkin_blocker_text`; free-form: `track_notes jsonb`.
- **`embodiment_daily_logs`**: `session_id`, `day_number int`,
  `completed_at`, `body_location`, `sensation_words text[]`,
  `identity_statement_shown`, `body_response body_response`
  (`true_open`/`strange_foreign`/`false_lying`),
  `day6_delta_reported embodiment_delta` (`yes_different`/`slightly`/
  `no_same`), `day7_action_committed`, `day7_action_confirmed bool`.
- **`phase5_reassessments`**: `loop_id`, `window_number
  reassessment_window` (`window_1`/`window_2`/`window_3` — this build uses
  only `window_2` (Day 5–7) and `window_3` (Day 21); `window_1` is unused,
  never write it), `administered_at` (**the timestamp column — there is no
  `created_at`**), `q1_trigger_answer`/`q1_new_score`/`q1_original_score`/
  `q1_delta`, `q2_body_state_answer`/`q2_new_score`/`q2_original_score`/
  `q2_delta` (**column names corrected 2026-07-19 — verified live via a
  read-only `supabase db dump --linked`; the processing RPC writes all
  answer/score/delta columns itself, so the client insert carries only
  `loop_id`, `user_id`, `window_number`**), `q3_block_flag
  q3_block_flag` (`regression`/`movement`/`ascension`), `combined_delta`,
  `classification`, `routing_outcome`, and the rediag columns
  `rediag_q1_resistance rediag_resistance` (`specific`/`general`/`none`),
  `rediag_q2_feeling rediag_feeling` (`relief`/`satisfaction`/`flatness`/
  `skepticism`), `rediag_q3_pattern rediag_pattern` (`handled_differently`/
  `same`/`not_noticed`), `rediag_q4_free_text`, `rediag_classification
  rediag_classification` (`compliance_bypass`/`surface_contact`/
  `method_mismatch`/`reclassify_residual` — enum values verified live
  2026-07-19).
- **`user_calibration`** (PK `user_id`): `calibrated_level`,
  `verified_floor`, `consecutive_verified_loops`, `peak_level`,
  `flow_resident`, `last_durability_at`. Written ONLY by DB functions —
  the client reads it, never writes it.
- **`energy_guides`**: static guidance rows; `get_energy_guide(p_score)`
  returns the matching row.

### Deployed decision functions the client will call (never reimplement)

| Function | Signature | Decides |
|---|---|---|
| `assign_phase4_track` | `(origin_type, origin_domain, coping_mechanism) → ascension_track` | which Phase 4 track a drill result routes to |
| `process_phase5_reassessment` | `(p_reassessment_id uuid, p_q1_new_answer p1_answer, p_q2_new_answer p1_answer, p_q3_flag q3_block_flag) → phase5_classification` | Window 2 classification + routing (writes the row) |
| `process_window3_durability` | `(same args) → user_calibration` | Day-21 durability + calibration update |
| `route_false_positive` | `(p_reassessment_id, p_resistance, p_feeling, p_pattern, p_free_text?) → rediag_classification` (**arg names corrected 2026-07-19 — verified live via read-only schema dump; an earlier draft of this table dropped the `p_` prefixes**) | false-positive re-diagnosis routing (always writes `routing_outcome = track_reassignment`; may rotate `ascension_loops.assigned_track`) |
| `get_energy_guide` | `(p_score numeric) → energy_guides` | zone guidance content |

### Enum tokens the client must mirror (verified against production 2026-07-08)

- `origin_type` (12): childhood_conditioning, acute_trauma, inherited_belief,
  identity_fusion, conditional_approval, humiliation_imprint,
  modeled_identity, betrayal_wound, preparation_loop, past_failure_imprint,
  optionality_preservation, worthiness_gap.
- `origin_domain` (12): relational_attachment, adequacy_impostor,
  existential_catastrophic, autonomy_sovereignty, status_achievement,
  relational_reciprocity, ideological_systemic, internal_self_directed,
  internalized_authority, societal_comparative, self_perfectionism,
  visibility_fear.
- `coping_mechanism` (12): distraction_avoidance, external_regulation,
  collapse_shutdown, cognitive_override, justice_confusion,
  control_dependency, appointed_guardian, sunk_cost_identity,
  preserved_potential, comfort_preservation, responsibility_avoidance,
  identity_continuity.
- `ascension_track` (4): completion, belief_audit, embodiment, commitment.
- Smaller enums are listed inline in the schema section above. `p1_answer`'s
  stale v1.0 tokens (`courage_neutrality`, `willingness_acceptance`,
  `reason`) must never be written (CLAUDE.md).

### Must not break

- The Phase 1 flow, auth gate, and golden-mirror tests.
- Any deployed scoring/classification function — **changing an existing
  deployed function body requires Noah's explicit sign-off**; new additive
  migrations are allowed via the `levels-dev-loop` runbook.
- The `one_dashboard_per_loop` cache contract and the Edge Function's
  fallback behavior.
- RLS and default-deny routing (new routes are private automatically; keep
  it that way).

## 3. SUCCESS CRITERIA

The project is done when every box checks:

- [ ] From a fresh signup in Chrome, a user can complete: assessment →
      dashboard reveal → origin drill → assigned track work → Window 2
      reassessment → (if routed onward) Window 3 durability check, with no
      dead ends and no manual SQL.
- [ ] Every number, zone, classification, and routing decision shown on
      screen was read back from a DB row or RPC result — grep-level check:
      no screen constructs an outcome from client math (mirrors are
      display-only previews, labeled as such in code).
- [x] Phase 2 screen writes `reality_tunnel_read`, `hidden_benefit_opened`,
      `illusion_opened`, and `time_on_screen_secs` as the user progresses
      (production SELECT 2026-07-11: newest row all-true + 24s; older null
      `time_on_screen_secs` rows predate the dispose-write fix).
- [ ] Phase 3 writes a complete `phase3_origin_drills` row whose
      `assigned_protocol` came from `assign_phase4_track`, and
      `ascension_loops.assigned_track` matches it.
- [ ] Each of the four tracks has a working session flow writing its
      designated columns; embodiment writes 7 `embodiment_daily_logs` rows
      gated one per day.
- [ ] Window 2 is only offered on loop days 5–7 and Window 3 only on day
      21+, both computed from `ascension_loops.started_at`; each calls its
      RPC and renders the returned classification/routing; the
      `false_positive` path runs the rediag flow via `route_false_positive`.
- [ ] All four routing outcomes lead somewhere real: `new_loop` starts a new
      loop (Phase 1), `deepening_protocol` re-enters Phase 3 with
      `deepening_layer + 1`, `track_reassignment` re-enters the drill,
      `retest_scheduled` shows the 48-hour gate.
- [ ] Home screen is a journey hub showing loop number, current phase, day
      counter, and calibration snapshot (`user_calibration` read-only).
- [ ] `flutter analyze` zero warnings; `flutter test` fully green; every
      new token mirror and window-gating rule has a pinned test.
- [ ] The `levels-verify` suite passes against production after any backend
      change, with results reported (not assumed).
- [ ] All protocol/drill content was reviewed by Noah before being declared
      shipped (each content task has an explicit review gate).
- [ ] `pubspec.yaml` dependencies unchanged: `go_router`, `supabase_flutter`,
      `flutter_lints` only.
- [ ] CLAUDE.md "Current open items" updated to reflect what shipped.

## 4. CONSTRAINTS

- **Platform:** web (Chrome) only. Do not enable iOS/Android in this plan.
- **Dependencies:** none may be added. State management stays plain
  `ChangeNotifier` following the `AssessmentController` pattern.
- **The one inviolable principle:** the LLM never decides; functions do.
  No client code computes a score, classification, or routing. Dart mirrors
  are preview-only and must be pinned by tests.
- **Backend changes:** additive migrations only, via the
  `levels-dev-loop` skill from this repo (sole migration authority).
  Existing deployed function bodies are frozen without Noah's sign-off.
  Run `levels-verify` after every backend change.
- **Content:** Phase 3/4 protocol content is **static Dart constants in
  this repo** (register and tone matching `fallback.ts`), drafted by the
  executing model and gated on Noah's review. No new Edge Functions and no
  runtime-LLM content in this plan (Anthropic credits are an unresolved
  blocker; the existing dashboard LLM path activates on its own when
  credits are added).
- **Trigger (v1):** in-app window gating computed from
  `ascension_loops.started_at` only. Push/email reminders are **out of
  scope** (listed as a future milestone; do not build pg_cron or email
  infra).
- **Also out of scope:** the FlutterFlow repo, the Framer site, OAuth
  wiring, payments, any admin UI, `window_1` reassessments, and analytics
  beyond the columns that already exist.
- **Standards:** everything in CLAUDE.md — imperative single-line commits
  with no AI trailers, committed directly to `main`; behavioral (never
  emotional) question copy; errors surface (throwing parsers, visible
  failures); doc comments cite production-verification dates; tests are
  pinned contracts. Tone rules: zones are positions in a climb, never
  labels; no manufactured urgency; never imply Flow from one assessment.

## 5. MILESTONES

| # | Milestone | Goal |
|---|---|---|
| M1 | Journey spine | The app knows where a user is in their loop; home becomes the hub that routes to the right phase. |
| M2 | Phase 2 dashboard | The variable-reward reveal: score, zone, four-part progressive copy, engagement columns written. |
| M-DS | Design system application | Apply `design-system/MASTER.md` (added 2026-07-08) across existing screens so M3+ screens are born themed. Runs after M2, before M3. |
| M3 | Phase 3 origin drill | Diagnose the block (3 structured + free-text questions), route to a track via `assign_phase4_track`. |
| M4 | Phase 4 tracks | All four track session flows; embodiment's 7-day daily loop. |
| M5 | Phase 5 reassessment | Window gating, both reassessment flows, rediag path, all four routing outcomes wired. |
| M6 | Full-loop hardening | End-to-end verification, docs, open-items cleanup. |

Order is strict: M1 → M2 → M3 → M4 → M5 → M6. Within a milestone, tasks are
ordered; do them one at a time, each ending in a passing-tests commit.

## 6. TASK BREAKDOWN

Every task below implicitly ends with: `flutter analyze` clean,
`flutter test` green, one commit in CLAUDE.md style.

**Review-gate delegation (2026-07-08):** Noah delegated the review gates
(M2.4, M-DS.3, M4.1, M5.1) to the Fable reviewer session — it judges against
the committed rubric (`docs/copy-tone-rubric.md` for copy gates, MASTER.md's
anti-pattern list for visual gates) and the writing standards, and records a
written verdict; Noah's written line then closes the gate. Executor sessions
still stop at each gate and hand the artifact (screenshots or copy) to the
reviewer; they never self-approve. "Done when" lists only
the task-specific checks. When a task says "behavioral copy", options
describe observable reactions, never emotion labels, matching
`lib/features/assessment/questions.dart`.

**A review gate is closed only by a committed artifact — rubric, verdict,
and approver line. A chat message or session summary is evidence, not
closure.**

**Book canon for content tasks (added 2026-07-11, Noah-approved):** all
M3.2/M4.1/M5.1 content follows the CLAUDE.md book canon hierarchy — Dodson's
*Levels of Energy* 2e is the sole canon for mechanics; *The Law of One* and
Abke's *Three Beliefs of Ego* inform framing/voice only and may never
introduce numbers, scales, or classifications. Noah plans a Dodson 2e
extraction doc (`docs/dodson-2e-reference.md`); if it exists when a content
task starts, treat it as the content source of truth under that hierarchy —
if it doesn't, log that to ACTION-FOR-NOAH before drafting drill/track copy
that leans on book material.

### M1 — Journey spine

**Status: COMPLETE — verified 2026-07-08.** M1.1–M1.4 shipped (`2067e8c`, `a71d710`, `b67cdb5`, `bf9c424`, `e1fc094`). Manual done-when observed by Noah in Chrome on his machine: mid-loop user (Loop 1, Day 5) showed "Day 5–7 check-in open" with the correct CTA resolving to the reassessment placeholder; a fresh account showed "Begin assessment" (null-loop branch); calibration strip rendered a real `user_calibration` row (verified floor 343.57).

1. **M1.1 — Loop state model.** Create `lib/features/journey/loop_state.dart`:
   a pure, immutable `LoopState` computed from plain inputs (loop row fields,
   existence of phase2/3 rows, latest phase4 session, phase5 rows, `DateTime
   now`) — no Supabase imports. It exposes: `currentPhase` (enum: assessment,
   dashboard, drill, track, window2, window3, complete), `loopDay` (1-based
   from `started_at`), `window2Open` (day 5–7 inclusive), `window3Open`
   (day ≥ 21). Done when: `test/loop_state_test.dart` pins the phase
   progression and the exact window boundaries (day 4 closed, 5 open, 7
   open, 8 closed; day 20 closed, 21 open) and passes.
2. **M1.2 — Journey repository.** Create
   `lib/features/journey/journey_repository.dart`: one class that fetches the
   active loop and its phase rows in a single method returning the inputs
   for `LoopState`, plus a read of `user_calibration`. Follow
   `AssessmentController`'s error discipline (throw, never swallow). Done
   when: home screen (M1.3) renders from it; no other file queries
   `ascension_loops` directly except `AssessmentController`.
3. **M1.3 — Home as journey hub.** Rewrite
   `lib/features/home/home_screen.dart`: show loop number, loop day, current
   phase with a single primary CTA routing to that phase's route, and a
   read-only calibration strip (verified floor, consecutive verified loops).
   No active loop → CTA is "Begin assessment". Done when: manual run in
   Chrome shows the correct CTA for a user with no loop and a user mid-loop.
4. **M1.4 — Route registrations.** Add placeholder routes in
   `lib/core/router.dart` for `/dashboard`, `/drill`, `/track`,
   `/reassessment` (plain Scaffolds for now; real screens land in M2–M5).
   Done when: `test/auth_gate_test.dart` extended to assert each new route
   redirects to `/login` without a session.

### M2 — Phase 2 dashboard

**Status: COMPLETE — 2026-07-11.** M2.1–M2.3 shipped and verified (reveal
columns confirmed by production SELECT 2026-07-11: booleans true +
`time_on_screen_secs` written on the newest row). M2.4 tone review passed
2026-07-10 via the delegated rubric judge against `docs/copy-tone-rubric.md`
(two `fallback.ts` fixes — flow + builder_clamped — deployed as Edge Function
v8, MCP read-back confirmed). Approved in writing — Noah, 2026-07-15 (via
reviewer-relayed prompt). Full-flow artifact: the M-DS.3 reveal-flow
screenshot set — artifact path unavailable (`Screenshots/` is empty/absent as
of 2026-07-15; see ACTION-FOR-NOAH.md), not re-shot for this closure.

1. **M2.1 — Dashboard repository.** Create
   `lib/features/dashboard/dashboard_repository.dart`: invokes the
   `generate-dashboard-copy` Edge Function with the user's JWT (via
   `supabase_flutter` functions client) for a `loopId`, parses the response
   through `DashboardCopy.fromJson`, and exposes the authoritative
   score/zone read from `phase1_assessments`. Handles `cached: true|false`
   identically. Done when: a widgetless unit test parses a captured
   fallback-path response fixture; errors from the function surface as
   thrown exceptions.
2. **M2.2 — Reveal screen.** Create
   `lib/features/dashboard/dashboard_screen.dart` at `/dashboard`:
   progressive tap-to-reveal in canonical order — score + zone illumination
   first (from the DB row), then `reality_tunnel`, `hidden_benefit`,
   `illusion`, ending on `bridge_question`. Each reveal updates its column
   (`reality_tunnel_read`, `hidden_benefit_opened`, `illusion_opened`) on
   the user's own `phase2_dashboard_views` row; on leaving, write
   `time_on_screen_secs`. Done when: manual run shows the reveal on a real
   loop and a `SELECT` on the row (read-only `execute_sql`) shows the three
   booleans true and a plausible seconds value.
3. **M2.3 — Wire assessment → dashboard.** Update
   `assessment_result_screen.dart` and the home hub so a scored loop's next
   step is `/dashboard`. Remove any placeholder result copy that duplicates
   what the dashboard now owns. Done when: completing an assessment lands
   on the reveal without manual navigation.
4. **M2.4 — Tone pass (review gate).** Present the full reveal flow
   (screenshots or run) to Noah against the Tone and product ethics section.
   Done when: Noah approves in writing; blockers become follow-up tasks.
5. **M2.5 — LLM-copy tone gate (follow-up, blocks LLM path activation).**
   Before enabling the funded LLM path in production, run 5 generated
   outputs per zone through `docs/copy-tone-rubric.md` via a cold judge;
   failures fall back or fix the prompt. Done when: 30 outputs (5 × 6
   zones) are scored against all 10 rubric criteria and every failure is
   resolved (fallback or prompt fix) before the path goes live.

### M-DS — Design system application (added 2026-07-08; runs before M3)

**Status: M-DS.1–M-DS.6 COMPLETE (commits `9c4190f`…`d77762d`; the
calibration strip was replaced with mechanic-free progress dots, `e7d4c6e`,
2026-07-10 — read "calibration strip" in older task text as those dots,
never raw numbers). M-DS.6 swept 2026-07-15 (commit `2624fcb`): found 2 —
`_ComingSoonScreen`/`errorBuilder` in `lib/core/router.dart` used untokenized
`Text` + a `FilledButton` instead of the §6 displayTitle/body/text-button
placeholder spec, and all 4 `SnackBar` call sites (login/signup/home/
assessment) rendered with Material defaults (no theme). Both fixed — router
placeholders now use `LevelsType`/`LevelsColors` and a plain `TextButton`;
`main.dart` gained a tokenized `SnackBarThemeData`. Clean elsewhere: no
inline hex, no ad-hoc `TextStyle`, no raw zone tokens in UI text, no
spinners (loading already uses `BreathingDot` everywhere), no fixed-height
reveal-panel containers (`minHeight` only).**

`design-system/MASTER.md` is binding for every task below and for all M3–M5
screens. Read it in full first. Every task ends with `flutter analyze` clean,
`flutter test` green, and zero inline hex/ad-hoc TextStyles introduced.

1. **M-DS.1 — Token foundation.** Create `lib/core/design_tokens.dart` from
   MASTER.md §1–§5; download Fraunces + Inter (OFL) into `assets/fonts/` and
   declare in `pubspec.yaml` (font files are approved; the `google_fonts`
   package is not); rebuild `ThemeData` in `main.dart` from tokens. Done
   when: app boots on the `void`/aurora base with Inter body type and no
   Material-default purple anywhere.
2. **M-DS.2 — ZoneStyle resolver.** Create `lib/core/zone_style.dart`
   (`ZoneStyle.of(EnergyZone)` → display name + zoneColor + zoneGlow, throws
   on unknown). Done when: a test pins all six display names and colors to
   MASTER.md §2 and fails if any mapping is edited.
3. **M-DS.3 — Dashboard restyle.** Apply MASTER.md §6: CoG anchor with glow
   + `breath`, glass reveal panels with locked/tappable/revealed states,
   bridge_question as the invitation layout, and replace the raw zone token
   with the ZoneStyle display name (fixes the "builder" leak observed
   2026-07-08). Done when: a screenshot set is approved against the
   anti-pattern list (this is the M-DS visual gate; blocks M-DS.4+).
4. **M-DS.4 — Home hub restyle.** Aurora backdrop, phase CTA per spec,
   quiet calibration strip. Done when: hub matches spec in a manual run.
5. **M-DS.5 — Auth + assessment restyle.** Neutral-accent treatment (no
   zone glow), assessment options as tokenized cards. Done when: manual run
   + no inline styles.
6. **M-DS.6 — Placeholders, loading, error states + anti-pattern sweep.**
   Style remaining surfaces per §6, then grep-audit `lib/` against MASTER.md
   §8 (inline hex, raw tokens, fixed heights). Done when: sweep findings are
   zero or fixed in the same commit.

### M3 — Phase 3 origin drill

**Status: M3.1 COMPLETE (`054b91e`, live-verified against production
2026-07-15). M3.2 COMPLETE — reviewer verdict PASS WITH MINOR NOTES, all
five suggested fixes applied (`bc3aa17`), Noah's written approval recorded
in `docs/m3.2-copy-review-verdict.md` 2026-07-15; gate closed. M3.3
COMPLETE — `process_phase3_drill` deployed via migration
`20260716045043_process_phase3_drill.sql`, MCP read-back confirmed the
deployed body and existing RLS policies, functional test against a
disposable row confirmed correct routing and loop sync (test row cleaned
up). M3.4 COMPLETE (2026-07-16) — see task 4 below for the full verification
record. M3 is done; M4 is next.**

1. **M3.1 — Token mirrors.** Create `lib/features/drill/drill_tokens.dart`:
   Dart enums mirroring `origin_type`, `origin_domain`, `coping_mechanism`,
   `ascension_track` wire tokens exactly (12/12/12/4 — the lists in §2 of
   this PRD, verified 2026-07-08). `fromToken` throws on unknown tokens.
   Done when: `test/drill_tokens_test.dart` pins every token string and the
   counts, citing the verification date.
2. **M3.2 — Drill content (review gate).** Create
   `lib/features/drill/drill_questions.dart`: behavioral question copy for
   Q1 (origin type), Q2 (domain), Q3 (mechanism) — each option maps to one
   token, phrased as observable patterns in the `fallback.ts` register.
   Include the bridge-question intro step: the user's `bridge_question_shown`
   is displayed and their free-text answer captured (this is the Phase 2→3
   hand-off seam; it seeds `q1_free_text`). Done when: Noah has reviewed and
   approved the copy in writing.
3. **M3.3 — Persistence migration.** Via the `levels-dev-loop` skill:
   add `process_phase3_drill(p_drill_id uuid)` — SECURITY DEFINER, `SET
   search_path = public, pg_temp` — which reads the drill row, calls
   `assign_phase4_track(q1_origin_type, q2_domain, q3_mechanism)`, writes
   `assigned_protocol`, `protocol_rationale`, `completed_at`, and updates
   the loop's `assigned_track`. Mirrors the `compute_center_of_gravity`
   pattern: one RPC that decides AND persists. Done when: migration pushed,
   `levels-verify` passes, and a read-only `pg_get_functiondef` check
   confirms the deployed body; results reported.
4. **M3.4 — Drill controller + screens. COMPLETE (2026-07-16).** Created
   `lib/features/drill/drill_controller.dart` (`DrillDataSource` seam +
   `SupabaseDrillDataSource`, `ChangeNotifier` controller: single typed
   state, single submit — insert row with answers + free text → RPC
   `process_phase3_drill` → read row back) and `drill_screen.dart` (3
   PageView-style pages at `/drill/:loopId`). `deepening_layer` defaults to 1
   (M5 will pass 2+). Router and home hub CTA updated to carry `loopId`
   through to the drill route. Verified: `test/drill_controller_test.dart`
   pins the insert → process → read-back submit-order contract with a fake
   `DrillDataSource` (5 tests); a full manual run in a release build
   (headless Chromium) signed up a fresh account, completed Phase 1 and the
   Phase 2 reveal, ran the drill end to end, and confirmed both the written
   `phase3_origin_drills` row (correct routing: `childhood_conditioning` →
   `embodiment`, matching deployed `assign_phase4_track`) and the home hub
   advancing to "Working your track". Also fixed a stale "Phase 3 coming
   soon." string on the Phase 2 dashboard, found during that manual run.

### M4 — Phase 4 tracks

1. **M4.1 — Track content pack (review gate). COMPLETE — approved by
   Noah 2026-07-16.** Created `lib/features/track/track_tokens.dart`
   (Dart mirrors of the 7 smaller Phase 4 enums: `prep_duration`,
   `belief_verdict`, `stage4_response`, `body_response`,
   `embodiment_delta`, `constraint_type`, `checkin_response`, verified
   against production via MCP) and `lib/features/track/track_content.dart`
   (static stage-by-stage copy for all four tracks — completion,
   belief_audit, embodiment, commitment — each stage keyed to the
   `phase4_track_sessions`/`embodiment_daily_logs` columns it fills;
   embodiment includes the 7 daily identity statements). Cold-context
   rubric judge pass run via a fresh Agent (model: fable) against
   `docs/copy-tone-rubric.md`: **PASS WITH MINOR NOTES**, no blocking
   findings, all 3 suggested optional fixes applied (see
   `docs/m4.1-track-content-review-verdict.md`). `flutter analyze` clean,
   `flutter test` green (125/125). Noah's written approval recorded in
   that verdict doc 2026-07-16 — gate closed.
2. **M4.2 — Track session controller. COMPLETE (2026-07-16).** Created
   `lib/features/track/track_session_controller.dart`
   (`TrackSessionDataSource` seam + `SupabaseTrackSessionDataSource`,
   mirroring `DrillController`'s pattern): `load()` starts a new
   `phase4_track_sessions` row or resumes the loop's already-open one for
   `track` (never both); typed setters + one `saveXStage()` per stage per
   track (completion; belief_audit, with all four arrays kept
   index-aligned by construction); `finish({required bool success})`
   writes `completed_at` — `success_state_reached` is the caller's
   decision, not computed here (no deployed function references this
   table; see `ACTION-FOR-NOAH.md`). Live-verified against production
   first, surfacing two doc corrections (column is `preparation_duration`,
   not `prep_duration`; `belief_authorship_age` is `int[]`, not `text[]`
   — both fixed in §2 above). No migration needed (table/RLS already
   deployed). Verified: `test/track_session_controller_test.dart` pins
   start-vs-resume (never two open sessions per loop; a finished session
   doesn't block a new loop's), and the column mapping for all four
   tracks, with a fake `TrackSessionDataSource` (17 tests). `flutter
   analyze` clean, `flutter test` green (138/138). Two open product
   decisions logged to `ACTION-FOR-NOAH.md` (per-track
   `success_state_reached` criteria; completion's
   `integrity_check_triggered` rule) — needed before M4.3 wires up real
   screens against this controller.
3. **M4.3 — Completion + commitment screens. COMPLETE (2026-07-16).**
   Built the two simpler track flows at `/track/:loopId` (branching on
   `assigned_track`): completion (statement + `preparation_duration` +
   integrity check), commitment (declaration, `constraint_chosen`,
   `checkin_scheduled_at` = now + 72h, later check-in capture of
   `checkin_response`/`checkin_blocker_text`). Built `lib/features/track/track_screen.dart`
   (`/track/:loopId`, reads `ascension_loops.assigned_track` and branches;
   `belief_audit`/`embodiment` still show the coming-soon placeholder
   pending M4.4/M4.5), `completion_screen.dart` (statement → duration →
   conditional integrity-check reflection via `AnimatedSwitcher`, per
   `docs/m4-ui-pattern-notes.md` finding 1 → `finishCompletion()`),
   `commitment_screen.dart` (declaration+constraint stage, saved and
   returns home with the session left open; a later visit resumes
   straight into the check-in stage → `finishCommitmentCheckin()`), and
   shared presentational widgets in `track_widgets.dart`. Router/home hub
   updated to `/track/:loopId` (was `/track`). Verified: `flutter analyze`
   clean, `flutter test` green (146/146, +8 new controller tests pinning
   the two approved pure rules and the per-track `finishX` methods); a
   full manual run in a release build (two fresh test accounts, each
   routed to a different track via the drill's Q1 answer) confirmed both
   tracks write every documented column, including the `over_3yr` ->
   `integrity_check_triggered` auto-trigger and the `partially` ->
   `success_state_reached = false` commitment rule (`ACTION-FOR-NOAH.md`).
4. **M4.4 — Belief-audit screen. COMPLETE (2026-07-17).** Built
   `lib/features/track/belief_audit_screen.dart`: repeating per-belief
   flow (flag → authorship age → authorship source → cross-exam verdict),
   "Add another belief" (secondary) / "Finish" (primary) after each
   belief's cross-exam, min 1 / max 3 beliefs enforced in
   `TrackSessionController` (`minBeliefCount`/`maxBeliefCount`,
   `canAddMoreBeliefs`, `addFlaggedBelief` throws past the cap — approved
   rule, `ACTION-FOR-NOAH.md`). All four arrays
   (`flagged_beliefs`/`belief_authorship_age`/`belief_authorship_source`/
   `cross_exam_verdict`) are only ever written together, fully
   index-aligned, by `saveBeliefAuditStage` — nothing persists mid-flow.
   Copy is entirely from the M4.1-approved `track_content.dart` (no new
   narrative strings; "Add another belief"/"Finish" are UI chrome, same
   precedent as M4.3's "Save"/"Continue"). Wired into
   `lib/features/track/track_screen.dart`, replacing the coming-soon
   placeholder. Verified: `flutter analyze` clean, `flutter test` green
   (149/149, +4 new controller tests pinning the cap); a full manual run
   in a release build (fresh test account, drill Q1 answer
   `inherited_belief`) completed a real 3-belief run and an MCP SELECT
   confirmed all four arrays land perfectly index-aligned
   (`ACTION-FOR-NOAH.md` has the full row).
5. **M4.5 — Embodiment screen + daily loop.** Session screen (body
   location, `sensation_words`, `stage4_response`) plus the 7-day
   `embodiment_daily_logs` flow: one log per `day_number`, gated by
   calendar day (no catch-up backfill), day 6 adds `day6_delta_reported`,
   day 7 adds `day7_action_committed`/`_confirmed`. Done when: gating
   COMPLETE (2026-07-18). Built `lib/features/track/embodiment_gate.dart`
   (`embodimentDayGate`, pure — calendar day_number = elapsed local-calendar
   days since `started_at` + 1, clamped 1-7; local date, not UTC, per
   Fable's 2026-07-17 decision; skipped days are never offered later since
   the gate always maps to *today's* slot, not "the next unlogged day"),
   `lib/features/track/embodiment_daily_log_controller.dart`
   (`EmbodimentDailyLogController`, one insert per day: base fields
   `identity_statement_shown`/`body_response` plus day6/day7 extras), and
   `lib/features/track/embodiment_screen.dart` (one-time session screen ->
   same-visit day-1 check -> gated re-entry each day after, including an
   "already logged today" status view and a "window elapsed" view for days
   past 7). `body_location`/`sensation_words` on `embodiment_daily_logs`
   are left unwritten daily (no per-day copy for them exists; flagged in
   `ACTION-FOR-NOAH.md`, not invented). Wired into `track_screen.dart`,
   replacing the last coming-soon placeholder — all four tracks are now
   built. Verified: `flutter analyze` clean, `flutter test` green
   (170/170, including 10 pinned gate tests covering
   same-day/next-day/skipped-day/window-boundary/local-vs-UTC scenarios).
   Manual run against production (fresh test account) completed the
   session screen, day 1 same visit, then days 6 and 7 via SQL-backdated
   `started_at` (the only way to reach later days in one sitting); MCP
   confirmed every column per day plus
   `phase4_track_sessions.completed_at`/`success_state_reached = true` on
   day 7's confirmation (`ACTION-FOR-NOAH.md` has the full row-by-row
   detail). One real bug surfaced during verification and was fixed: it
   was in the Playwright test harness (a stale browser profile/service-
   worker serving a cached JS bundle across rebuilds), not in the app — no
   `lib/` changes resulted from that finding.
6. **M4.6 — Hub integration. COMPLETE 2026-07-19.** Home hub shows track
   progress (stage or day N/7) and routes the daily embodiment CTA.
   `JourneyRepository.fetchActiveLoop` computes `TrackProgress` (track
   type, completion, embodiment day-gate) from `phase4_track_sessions` +
   `embodiment_daily_logs`; `home_screen.dart`'s `_trackCtaLabel` renders
   "Day N of 7" for an open embodiment day and "Day N logged — come back
   tomorrow" for an already-logged day, generic "Continue your track"
   otherwise (including before a session row exists — session creation is
   lazy, on first track-screen visit). `flutter analyze` clean, all 170
   tests pass. Manually verified end-to-end in a real browser against
   production: confirmed the no-session generic state, "Day 1 of 7" on an
   open session, and "Day 1 logged — come back tomorrow" after saving the
   check-in, with an MCP SELECT on `embodiment_daily_logs` matching the UI
   (`ACTION-FOR-NOAH.md` has the full test-account detail).

### M5 — Phase 5 reassessment

1. **M5.1 — Reassessment content (review gate). COMPLETE — approved by Noah in writing 2026-07-19 (commit `a6a91be`; em dashes removed from all question copy per standing rule).** Create
   `lib/features/reassessment/reassessment_questions.dart`: behavioral copy
   for Q1 (re-run of the loop's trigger question), Q2 (body-state re-scan)
   — both answered in `p1_answer` tokens (reuse `P1Answer`; never the three
   stale v1.0 tokens) — and Q3 (block flag: `regression`/`movement`/
   `ascension` as behavioral descriptions), plus the four rediag questions
   (`rediag_resistance`/`_feeling`/`_pattern` options + free text). Done
   when: Noah approves in writing.
2. **M5.2 — Window 2 flow.** Controller + screens at `/reassessment`:
   only reachable when `LoopState.window2Open`; insert the
   `phase5_reassessments` row (`window_number = 'window_2'`), call
   `process_phase5_reassessment(id, q1, q2, q3)`, read the row back, render
   classification + routing from the row (never client-derived). Done when:
   a manual run on a day-5+ test loop (backdate `started_at` via a
   **read-only-exempt** single UPDATE that Noah runs or approves) shows a
   classification; a fake-client test pins the insert→RPC→read-back order.
3. **M5.3 — Rediag path.** When the returned classification is
   `false_positive`, continue into the rediag flow and call
   `route_false_positive(...)`; render the returned `rediag_classification`
   and resulting `routing_outcome` from the row. Done when: test pins that
   the rediag screens only mount on `false_positive`.
4. **M5.4 — Routing outcomes.** Implement all four destinations:
   `new_loop` → mark loop complete, CTA to new assessment (**corrected
   2026-07-19 — verified live: the deployed `process_phase5_reassessment`
   already writes `status = 'complete'` + `completed_at` + exit score/zone
   on `true_ascension`, and `route_false_positive` never returns
   `new_loop`; the client performs no loop write, it only routes**);
   `deepening_protocol` → `/drill` with `deepening_layer + 1`;
   `track_reassignment` → `/drill` fresh; `retest_scheduled` → gated
   48-hour retest state on the hub. Done when: each outcome is reachable in
   a test (pure routing function + pinned test) and the hub reflects it.
5. **M5.5 — Window 3 flow.** Same pattern as M5.2 with
   `window_number = 'window_3'` and `process_window3_durability(...)`;
   render the returned `user_calibration` change (floor, consecutive
   verified loops, flow_resident) as the loop's closing screen. Copy must
   frame Flow as earned across loops (CLAUDE.md Flow reachability). Done
   when: manual run on a day-21 test loop updates the hub's calibration
   display (the mechanic-free progress dots that replaced the raw-number
   strip in `e7d4c6e` — never reintroduce raw numbers there).

### M6 — Full-loop hardening

1. **M6.1 — Full-loop verification. COMPLETE — 2026-07-23.** Ran
   `levels-verify` against production (all golden/classification/clamp/
   infra checks PASS). `get_advisors` surfaced a real IDOR (not just a
   lint): `compute_center_of_gravity`, `process_phase5_reassessment`,
   `process_window3_durability`, `apply_window3_calibration`, and
   `route_false_positive` were all anon/authenticated-executable with no
   ownership check — fixed via two migrations (ownership guards +
   `REVOKE ... FROM PUBLIC`; the first revoke attempt targeted `anon`
   directly and had no effect since the grant was on `PUBLIC` — corrected
   in a second migration), verified via `pg_get_functiondef`,
   `role_routine_grants`, and a clean post-fix `get_advisors` re-check.
   Regression check passed: an existing M5 false_positive/retest account
   (`m52-api-verify2-1784500982739@example.com`) still shows exactly one
   `window_2` row with `administered_at` reset, not duplicated.

   The full manual loop (fresh account, browser, release build) surfaced a
   second real bug: `LoopState` checked `loopComplete` before `window3Open`,
   so a loop that reached `true_ascension` at Window 2 (which marks
   `ascension_loops.status = 'complete'` immediately) could never route to
   the Window 3 durability check — the one case `apply_window3_calibration`
   was built to confirm. Fixed in `loop_state.dart` (window3Open now checked
   first), pinned with two new tests, verified live end-to-end: the same
   test loop reached "Three weeks later, it holds" after the fix, with the
   full row trail confirmed present and consistent via read-only SELECTs
   (loop → phase1 → phase2(fallback) → phase3_drill → phase4_track →
   phase5_window_2(true_ascension) → phase5_window_3(true_ascension) →
   user_calibration). `user_calibration.calibrated_level` clamped to
   exactly 500.00 with `consecutive_verified_loops = 1` and
   `flow_resident = false`, confirming the climb-only Flow rule holds even
   though the raw (unused-by-client) `ascension_loops.exit_score` field is
   itself unclamped and can read into Flow off one reassessment — flagged
   in `ACTION-FOR-NOAH.md` as a loose end, not fixed (not currently
   reachable from any UI).

   `flutter analyze` clean, `flutter test` 222/222 green throughout.
   Test-account cleanup still pending (needs the service-role API, same as
   every prior milestone's manual-verification accounts).
2. **M6.2 — Docs sync.** Update CLAUDE.md: repo tree (new feature dirs),
   open items (mark Phases 2–5 UI shipped; add push/email trigger and
   `checkin_scheduled_at` reminder as future items), and the mirror sync
   map (add the drill/reassessment token mirrors + their tests as group 4).
   Update this PRD's checkboxes in §3. Done when: CLAUDE.md matches the
   shipped reality and `docs/PRD.md` reflects final status.
3. **M6.3 — Loose ends audit.** Grep for TODOs introduced by this plan,
   confirm the `TODO(phase-3)` note in
   `supabase/functions/generate-dashboard-copy/index.ts` is now satisfied
   (bridge answer captured in M3.2's flow) and update/remove the comment
   accordingly (Edge Function redeploy per CLAUDE.md command). Done when:
   no stale TODOs reference unbuilt phases.

## 7. HANDOFF NOTES

**Session start ritual.** Read CLAUDE.md fully. If the session will touch
the backend, run the `levels-verify` skill first and report the table. Then
open this PRD, find the first unchecked task in order, and do exactly that
task.

**Work order is the milestone order.** Do not parallelize milestones; later
tasks assume earlier files exist. One task = one commit (imperative mood, no
prefixes, **no Co-Authored-By or AI trailers**, straight to `main`).

**The trap this project is designed against:** it will feel natural to
compute a classification or zone client-side "just for display". Don't. If
a screen needs an outcome, read it from the row the RPC wrote or call the
RPC. The Dart mirrors (`scoring.dart`, and the token mirrors you'll add)
exist only for instant previews and parsing, and every one must be pinned by
a test citing a production-verification date.

**Backend etiquette.** Migrations only through the `levels-dev-loop`
skill from this repo (never from `levels-app` — its supabase dir is stale
and would fork history). Additive changes only; existing function bodies are
frozen without Noah's sign-off. After any push: `levels-verify`, and read
the deployed body back with `pg_get_functiondef` — report results, never
assume. Enum checks go through `pg_enum`, not `information_schema`.

**Secrets.** The secrets-and-debug-discipline skill is binding. No literal
key values in commands, ever. The client uses only the publishable key.

**Content gates.** Tasks M2.4, M3.2, M4.1, M5.1 stop at the delegated
reviewer: the reviewer judges the drafted content against the committed
rubric (`docs/copy-tone-rubric.md` and MASTER.md's anti-pattern list) and
records a written verdict; Noah's written line then closes the gate.
Executors draft and present — they never self-approve, and never mark the
task done or build screens that ship unreviewed copy to users. Copy
register: match `fallback.ts` — warm, direct, second person, zero numbers,
zones as positions in a climb.

**A review gate is closed only by a committed artifact — rubric, verdict,
and approver line. A chat message or session summary is evidence, not
closure.**

**Gotchas already paid for (don't rediscover):**
- `one_window_per_loop` UNIQUE(loop_id, window_number) and
  `one_drill_per_loop` UNIQUE(loop_id) are enforced in production (verified
  live 2026-07-19 — a second INSERT is a 409). Retests and
  deepening/track-reassignment drills UPDATE the loop's existing row and
  re-run the processing RPC, which recomputes and overwrites every derived
  column from its arguments.
- `ascension_loops.started_at` is the only clock; windows are day 5–7 and
  day ≥ 21, computed in pure Dart (`LoopState`) so they're testable.
- `phase2_dashboard_views` is written by the Edge Function (service role);
  the client only UPDATEs the reveal-tracking booleans on its own row —
  RLS permits that; INSERTing from the client would fight the cache
  contract.
- `p1_answer` carries three stale v1.0 tokens that must never be written.
- Postgres arrays in `phase4_track_sessions` (belief audit) are
  index-aligned across four columns — misalignment is silent data
  corruption; the controller owns alignment and a test pins it.
- An all-`love_flow` assessment scores 499.99/`builder` with
  `was_clamped = true`. That is correct behavior, not a bug.
- Backdating `started_at` to test windows is a production data edit — get
  Noah's approval each time; it is not covered by the read-only exemption.

**When something contradicts this PRD:** production wins, then CLAUDE.md,
then this file — and fix the loser in the same commit (this PRD is a living
doc; keep §3 checkboxes and §6 statuses current).
