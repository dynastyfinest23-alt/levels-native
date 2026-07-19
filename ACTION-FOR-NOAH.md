# Action items for Noah

## M2.4 full-flow artifact — screenshot path unavailable (2026-07-15)

PRD M2.4 status now cites the M-DS.3 reveal-flow screenshot set as its
full-flow artifact, but `Screenshots/` at the repo root is currently
empty/absent (per CLAUDE.md, that folder is transient and only present when
populated). Did not re-shoot per Task 2c instructions — flagging instead.

If you want a durable artifact on record for this gate, either point to
where the M-DS.3 screenshots actually live now, or ask for a fresh screenshot
pass next session.

## M3.4 manual-verification test account (2026-07-16)

Verified the M3.4 drill flow end-to-end in a real browser (release build,
headless Chromium) — signed up, ran Phase 1, revealed the Phase 2 dashboard,
completed the Phase 3 drill, confirmed the home hub advanced to "Working
your track". Left the test account in place rather than partially cleaning
it up: `public.users`/loop/assessment/drill rows are deletable via SQL, but
the linked `auth.users` row needs the admin API (service role), which isn't
available to this client — deleting only the public-schema rows would leave
an orphaned auth user, which is worse than leaving the full account intact.
Add to the existing "test-account deletion" cleanup pass:
`m34-drill-verify@example.com` (`public.users.id`
`fd8f6411-02c0-4def-a3ed-dfa71c8a4daa`, loop `b6efaf63-69ac-4891-9ef9-59960f020cbb`).

## Resolved — love_flow decision (2026-07-16)

**Decision: defer — keep `love_flow` = 530.** Noah reviewed the 530-vs-550
brief and chose to hold off recalibrating; the book's citation for 550 is
adjacent (a "Love of 550..." quote, not a dedicated anchor heading like the
other 11 tokens), and a change buys no behavioral difference in the common
full-`love_flow` case. No scoring artifact touched — `answer_to_raw_score`,
`scoring.dart`, golden tests, and CLAUDE.md's scoring table all remain as
deployed/verified 2026-07-15. Removed from the open list; no further action
needed unless Noah revisits the citation later.

## Resolved — M4.2 open product decisions (2026-07-16)

Built `lib/features/track/track_session_controller.dart` (start/resume +
per-stage save for all four `phase4_track_sessions` tracks). Verified live
against production first — two docs corrections came out of that (column is
`preparation_duration` not `prep_duration`; `belief_authorship_age` is
`int[]` not `text[]`, both now fixed in `docs/PRD.md` §2). No deployed
function references `phase4_track_sessions` at all (confirmed via
`pg_proc.prosrc` search), so the decision layer for the rules below is the
client for now; if any deployed function ever reads `success_state_reached`,
promote the rule to a Postgres function.

**All three decisions approved by Noah 2026-07-16.** These are binding for
M4.3-M4.6; implement each as a pure Dart function with a pinned test.

1. **`success_state_reached` per track:**
   - `completion`, `belief_audit`: finishing the flow = success. The
     integrity-check moment is reflective, not a fail state.
   - `commitment`: `finish()` is NOT called at declaration time — the
     session stays open until the ~72h check-in (the one-open-session-per-
     loop invariant tolerates this). Success = `checkin_response == yes`
     only; `partially`/`no` = not success (behavior tells the truth over
     self-report, mirroring the Phase 5 stance).
   - `embodiment`: success = `day7_action_confirmed` in
     `embodiment_daily_logs`, written back to the session row when the
     day-7 log completes. Never reaching day 7 leaves it false.
2. **`completion` track's `integrity_check_triggered` rule:** fires when
   `preparation_duration` is a year or more (`years1to3` or `over3yr`).
   The statement is free text, so the duration enum is the only structured
   input a deterministic rule may use — no language classification.
3. **M4.4 belief-count cap: fixed at 3 (min 1, max 3).** Matches the
   3-belief done-when in PRD M4.4 and the tab-navigation UI pattern.

Cleanup to take in passing during M4.3: doc comments in
`lib/features/track/track_content.dart` (around line 25) still say
`prep_duration`; the live column is `preparation_duration`.

## M4.3 manual-verification test accounts (2026-07-16)

Verified the M4.3 completion and commitment screens end-to-end in a real
browser (release build, headless Chromium), same method as M3.4. Two fresh
test accounts, each driven through signup -> Phase 1 -> Phase 2 reveal ->
Phase 3 drill (deliberately picking the Q1 origin-type answer that routes
to the track under test) -> the new track screen:

- `m43-completion-verify@example.com` (loop
  `224c2273-2b0c-4d6e-a6f9-8edeb01227fe`) -- routed to `completion`.
  Verified the `over_3yr` duration correctly auto-triggers
  `integrity_check_triggered`, the reflection stage renders, and finishing
  writes `completed_at`/`success_state_reached = true`.
- `m43-commitment-verify@example.com` (loop
  `42c36712-7f5a-40ed-886c-d9d57818fcc0`) -- routed to `commitment`.
  Verified the declaration stage saves and returns home with the session
  still open (`completed_at` null), re-entering resumes straight to the
  check-in stage (never a second session), and a `partially` check-in with
  blocker text correctly writes `success_state_reached = false`.

Left both test accounts in place for the same reason as M3.4's
`m34-drill-verify@example.com`: deleting the `public.users`/loop rows would
orphan the linked `auth.users` row without the admin/service-role API. Add
both to the existing test-account cleanup pass.

## M4.4 manual-verification test account (2026-07-17)

Verified the M4.4 belief-audit screen end-to-end in a real browser (release
build, headless Chromium), same method as M4.3. One fresh test account,
`m44-belief-audit-verify@example.com` (loop
`84f28c44-8da3-468b-9d11-c0ec4ed0f4c7`) -- driven through signup -> Phase 1
-> Phase 2 reveal -> Phase 3 drill (Q1 answer `inherited_belief`, which
routes to `belief_audit`) -> a full 3-belief run (the approved cap). MCP
SELECT on `phase4_track_sessions` confirmed all four arrays land perfectly
index-aligned:

- `flagged_beliefs`: `["I am not enough", "I will be abandoned if I speak
  up", "I have to earn rest"]`
- `belief_authorship_age`: `[8, 12, 20]`
- `belief_authorship_source`: `["A strict teacher in school.", "A
  difficult breakup.", "A demanding parent."]`
- `cross_exam_verdict`: `{conclusion,fact,conclusion}`
- `completed_at` set, `success_state_reached = true`

Also confirmed the "Add another belief" button correctly disappears once
`canAddMoreBeliefs` goes false at the 3-belief cap (screenshot: belief 3's
cross-exam stage shows only "Finish"). Add this account to the existing
test-account cleanup pass, same reasoning as M3.4/M4.3 (orphaned
`auth.users` row risk without the admin/service-role API).

## M4.5 embodiment: two scope decisions made without a review gate (2026-07-17)

`lib/features/track/embodiment_daily_log_controller.dart` and
`lib/features/track/embodiment_screen.dart` both carry doc comments that
say "flagged in ACTION-FOR-NOAH.md" — this is that flag, added on review
since neither file had actually written it yet.

1. **`body_location`/`sensation_words` on `embodiment_daily_logs` are left
   null every day.** The table has both columns (confirmed live via
   `information_schema.columns`), but `track_content.dart` (M4.1,
   gate-approved) only has a prompt for them on the one-time session
   screen, not per day. PRD M4.5's task text also only lists identity
   statement + body_response as the daily baseline. Read as intentional —
   the columns are likely vestigial from an earlier schema draft — but
   flagging since nothing says so explicitly. If you want daily
   location/sensation capture too, that needs new copy through the content
   gate, not a silent code change.
2. **"Already logged today" / "window elapsed" states use plain
   functional-chrome copy, not content-gate-reviewed narrative.** Same
   register as `TrackErrorView` and the router's coming-soon placeholder —
   status text, not drill/reveal copy. If you want these two states held
   to the M4.1 tone rubric too, say so and they'll go through a review
   pass like the rest of the track content did.

Neither decision touches scoring, schema, or the deployed backend — both
are reversible in a follow-up commit if you want it done differently.

## M4.5 manual-verification test account (2026-07-17/18)

Verified the M4.5 embodiment screen and 7-day daily-log flow end-to-end
against production, same method as M4.3/M4.4, plus SQL backdating to reach
days 6-7 in one sitting (documented in `docs/PRD.md`'s M4.5 entry). One
test account, `m45-embodiment-verify@example.com` (loop
`0c2a6b5f-fa0f-4c57-acae-2778439f036b`, session
`e4abb0c9-ac72-42a6-9300-741e95363f0a`) -- driven through signup -> Phase 1
-> Phase 2 reveal -> Phase 3 drill (Q1 answer `childhood_conditioning`,
which routes to `embodiment`) -> the session screen -> day 1's check-in
same visit, then days 6 and 7 across two `started_at` backdates.

MCP SELECTs confirmed:
- Session screen: `body_location_tapped` = `"chest"`, `sensation_words` =
  `["tight","warm"]`, `stage4_response` = `"shifted"`.
- `embodiment_daily_logs`, one row per day, each with the correct static
  `identity_statement_shown` for that day_number and a `body_response`:
  day 1 (`true_open`), day 6 (`true_open` + `day6_delta_reported` =
  `"yes_different"`), day 7 (`true_open` + `day7_action_committed` =
  `"Send the email I keep drafting."` + `day7_action_confirmed = true`).
- Re-entering after day 1's log correctly showed the "already logged
  today" status screen instead of a second entry form.
- Day 7's confirmation wrote `phase4_track_sessions.completed_at` and
  `success_state_reached = true` (via `finishEmbodiment`), matching the
  approved rule (success = `day7_action_confirmed`).

**A real bug was found and fixed during this verification, but it was in
my test harness, not the app.** The headless Chromium instance was reusing
a persistent default profile across relaunches; Flutter's web service
worker cached the JS bundle at that profile level and kept serving a stale
build across every rebuild *and every browser process restart* for a long
stretch of this session, making a working Save button look completely
broken (no click effect, no network call, nothing). Confirmed via a
throwaway `--user-data-dir` per Chrome launch, which immediately fixed it.
No code in `lib/` was changed as a result — the `onPressed` wiring was
already correct in the committed code. If browser-based verification ever
looks inexplicably "dead" again (button does nothing, no errors, no
requests) on a *rebuilt* release bundle, suspect stale profile/service-
worker caching before suspecting the Dart code.

Left the account in place, same reasoning as M3.4/M4.3/M4.4 (orphaned
`auth.users` row risk without the admin/service-role API). The session row
is now fully completed (day 7 done) so it won't be resumed again by
accident; `started_at` was intentionally backdated by SQL for this test
and was left as-is afterward since the row is a closed historical record.
Add this account to the existing test-account cleanup pass.

## M4.6 manual-verification test accounts (2026-07-18/19)

Verified the M4.6 hub track-progress CTA end-to-end in a real browser
against production. Two accounts:

- `m46-hub-verify@example.com` (loop routed to `completion`) — a keyboard
  focus-traversal mistake during drill Q1 (typing into the wrong focused
  element while hunting for the free-text field via Tab) accidentally
  changed the selected origin-type answer mid-drill, so this account ended
  up on the `completion` track instead of the intended `embodiment` track.
  Not usable for the embodiment CTA test; left as-is.
- `m46-hub-verify-2@example.com` (loop `17e2e644-355e-42ed-93c9-b529569e16a6`,
  session `a60803fa-abac-4ebd-a499-8de927487c25`) — driven through signup ->
  Phase 1 -> Phase 2 reveal -> Phase 3 drill (Q1 `childhood_conditioning`,
  routing to `embodiment`) -> confirmed hub shows generic "Continue your
  track" before a session row exists -> opened the track screen (creates
  the session) -> back to hub, confirmed "Day 1 of 7" -> completed day 1's
  check-in -> back to hub, confirmed "Day 1 logged — come back tomorrow".
  MCP SELECT on `embodiment_daily_logs` confirmed `day_number=1`,
  `completed_at` set, matching the UI.

Both accounts left in place, same reasoning as prior milestones (orphaned
`auth.users` row risk without the admin/service-role API). Add both to the
existing test-account cleanup pass.

**Browser-automation note:** on this Flutter web build, Tab-key focus
traversal through a `_DrillQuestionPage`'s answer options is unreliable
when driven in rapid batched keypresses (many `Tab`s in one tool call) —
focus lands inconsistently and typed text can land on a still-focused
option button instead of the free-text field, silently changing the
selected answer via type-ahead-style key handling. Tabbing one key at a
time with a short wait and a screenshot between each step was reliable;
batching all Tabs in one call was not. Not a product bug — an artifact of
CanvasKit's accessibility tree being sparse for automation tooling.

## M5.2 Window 2 flow — manual run pending, assumptions flagged (2026-07-19)

Built the `/reassessment/:loopId/:window` flow (controller, screens, gate,
hub CTA) on branch `kimi/m5`. The route changed from the M1.4 placeholder
`/reassessment` to carry `loopId` + window; `router_test.dart` was updated
to match.

**The PRD M5.2 done-when manual run is still pending.** It needs a day-5+
test loop (backdating `ascension_loops.started_at` is a production data
edit — your approval required each time, per PRD §7) showing a real
classification from `process_phase5_reassessment`. The fake-client test
pins the insert -> RPC -> read-back order, but per the definition of done,
unit tests do not substitute for the manual run.

Assumptions coded blind against PRD §2 (no local migration defines the
Phase 5 schema; `20260623000001_baseline.sql` is an empty file):

1. `phase5_reassessments` insert columns are `loop_id`, `user_id`,
   `window_number`, `q1_answer`, `q2_answer`, `q3_block_flag` (`user_id`
   included per the house RLS insert pattern used by every other phase
   table).
2. `process_window3_durability` takes the identical `p_`-prefixed args as
   `process_phase5_reassessment` (PRD says "same args"); the controller
   dispatches on window.
3. `classification`/`routing_outcome` are treated as nullable on read-back
   (a row left by a failed submit reads back null; Window 2 treats that as
   a loud error). If `process_window3_durability` never writes them, the
   Window 3 closing screen in M5.5 does not depend on them.
4. Result-screen copy (`ClassificationCopy`) and the gate-closed/error copy
   are executor-written functional copy, not content-gate-reviewed
   narrative — same standing as the M4.5 status states. Say the word if you
   want it run through the rubric judge.

## M5.3 rediag path — gaps coded around, not resolved (2026-07-19)

1. **`route_false_positive` RPC arg names are assumed.** PRD §2's signature
   table writes them without the `p_` prefix the other Phase 5 functions use
   (`rediag_resistance`, `rediag_feeling`, `rediag_pattern`, optional
   `free_text`; `p_reassessment_id` IS prefixed there). Coded exactly as the
   PRD writes them. If the deployed function actually uses `p_` prefixes,
   the RPC will 400 on the first real false_positive run — the manual M5.2
   verification pass should include one false_positive answer set to catch
   this.
2. **`rediag_classification` enum values are documented nowhere in this
   repo** (the Phase 5 schema lives only in production; the local baseline
   migration is empty). Per the no-invented-schema rule, the client stores
   it as an opaque string and never renders it — the post-rediag screen
   shows a quiet acknowledgement plus the way home. To render it properly
   (typed throwing lookup like `ZoneStyle.of`), paste the output of
   `SELECT enumlabel FROM pg_enum e JOIN pg_type t ON t.oid = e.enumtypid
   WHERE t.typname = 'rediag_classification' ORDER BY e.enumsortorder;`
   and it becomes a small follow-up commit.
3. **Widget-test quirk worth knowing:** the bundled Fraunces/Inter assets
   do not load under `flutter_test`, so prompts render far taller than
   production and later option cards start scrolled under the bottom button
   bar. Reassessment question pages use `SingleChildScrollView + Column`
   (everything eager, nothing offstage) and the widget tests
   `ensureVisible` before tapping. `DrillScreen`'s lazy `ListView` pages
   have the same latent test quirk; left untouched as out of scope.

## M5.4 routing outcomes — assumptions flagged (2026-07-19)

All four routing outcomes are wired: `new_loop` (controller marks the loop
`complete` on read-back, CTA to `/assessment`), `deepening_protocol`
(`/drill/:loopId?deepen=1`, controller resolves deepest layer + 1),
`track_reassignment` (`/drill/:loopId` fresh), `retest_scheduled` (48-hour
gate on the hub, disabled quiet CTA until it lifts). Assumptions coded
blind:

1. **`ascension_loops.status = 'complete'` is a valid write.** The status
   column's enum/text domain is not in this repo (baseline migration is
   empty); `'complete'` is the value `JourneyRepository` already reads for.
   If the deployed enum spells it differently, the new_loop path throws at
   runtime — the manual verification run covers this.
2. **A retest inserts a second `window_2` row.** No unique constraint is
   documented; `JourneyRepository` now reads the latest row by `created_at`
   to tolerate it. If a unique(loop_id, window_number) constraint exists,
   the retest insert fails and we need an UPDATE-style retest path instead.
3. **The retest is not re-bounded by the day 5-7 window.** A check-in
   answered on day 6 retests on day 8, outside Window 2. The gate treats
   the retest as its own event (spec says only "retest in 48h"). Correct me
   if retests should instead be clipped to the window.
4. **Hub/CTA copy is executor-written functional chrome** ("Continue your
   practice", "Start a fresh drill", "Your check-in opens soon", "Take your
   check-in"), same standing as the M4.5 status states — not
   content-gate-reviewed narrative.
