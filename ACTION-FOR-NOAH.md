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

**Resolved (2026-07-22).** The manual run this section flags completed
2026-07-19 (see "M5 browser manual run — COMPLETE" below; screenshots
`m5-01` through `m5-08` in `Screenshots/`). Of the four blind assumptions
listed here, assumption 1 (insert columns) was disproven and fixed: the
client insert now carries only `loop_id`/`user_id`/`window_number` — the
answer columns are `q1_trigger_answer`/`q2_body_state_answer` and are
written by the processing RPC itself, not the client insert (see "Phase 5
client verified against production" below, bug 1). Left as historical
record below, not deleted.

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

## M5.5 Window 3 flow — manual day-21 run pending (2026-07-19)

Built the Window 3 durability flow on `kimi/m5`: same three questions with
`window_number = 'window_3'`, `process_window3_durability` RPC, read-back of
both the reassessment row and `user_calibration`, and a closing screen that
renders the calibration change as progress dots (shared
`ProgressDots`/`flowGateLoops` widget, extracted from the hub's calibration
strip) with copy framing Flow as earned loop by loop. The gate requires
`window3Open` and no existing Window 3 row.

**The PRD M5.5 done-when manual run is still pending**, same as M5.2's: it
needs a day-21 test loop (backdating `ascension_loops.started_at` requires
your approval each time) showing the hub's calibration display update after
the durability check. Unit/widget tests pin the submit order and the
mechanic-free rendering (a no-digits-anywhere assertion on the closing
screen), but per the definition of done they do not substitute for the
manual run.

Assumption flagged: whether `process_window3_durability` also writes
`classification`/`routing_outcome` to the reassessment row is unverifiable
from this repo — the closing screen deliberately depends only on
`user_calibration`, and the row's classification fields are treated as
nullable, so either deployed behavior works.

## Phase 5 client verified against production — three real bugs found and fixed (2026-07-19)

No Supabase MCP tools were connected in the executor session, so the blind
spots were verified a different read-only way: started Docker Desktop and
ran `npx supabase db dump --linked --schema public` (pure read; nothing was
written to production). The dumped DDL answered every open assumption from
the M5.2–M5.5 flags, and three of them were live bugs:

1. **Insert columns were wrong.** The M5.2 client inserted `q1_answer` /
   `q2_answer` / `q3_block_flag` — none of the answer columns exist under
   those names (real: `q1_trigger_answer`, `q2_body_state_answer`; all
   answer/score/delta columns are written by the processing RPC itself).
   The insert now carries only `loop_id`, `user_id`, `window_number`.
2. **`created_at` does not exist on `phase5_reassessments`** — the column
   is `administered_at`. The hub's Window 2 query and ordering used
   `created_at` and would have failed for every loop. Fixed everywhere
   (repository, screen gate, hub).
3. **`route_false_positive` arg names were wrong.** The PRD signature table
   transcribed them unprefixed (`rediag_resistance`, …); the deployed
   signature is `p_resistance`, `p_feeling`, `p_pattern`,
   `p_free_text DEFAULT NULL`. The M5.3 RPC call would have 400'd. Fixed,
   and PRD §2 corrected (production wins).

Also resolved by the dump:

- **`rediag_classification` enum is now mirrored** (`compliance_bypass`,
  `surface_contact`, `method_mismatch`, `reclassify_residual`) with a
  throwing `RediagCopy` display lookup; the post-rediag screen renders it.
  The earlier "stored opaque, never rendered" workaround is gone.
- **Rediag always routes `track_reassignment`** (and may rotate
  `ascension_loops.assigned_track` server-side) — the client's post-rediag
  CTA matches.
- **Client `markLoopComplete` was removed.** The deployed
  `process_phase5_reassessment` already writes `status='complete'` +
  `completed_at` + exit score/zone on `true_ascension`, and rediag never
  returns `new_loop`. A client UPDATE could only ever write an incomplete
  copy of that fact. PRD M5.4's wording is corrected accordingly.
- **No unique(loop_id, window_number) constraint exists** — the
  second-row retest design is valid as built.
- `loop_status` = `active`/`complete`/`stalled` (no `lapsed` value yet —
  the lapse policy's enum addition is still future backend work).

`flutter analyze` clean, `flutter test` 211/211 green after the fixes.

**Still pending:** the two manual runs (day-5 Window 2, day-21 Window 3)
with your approved `started_at` backdates. Note Docker Desktop was started
on this machine for the dump and left running.

## Phase 5 API-level verification against production — ALL PASS (2026-07-19)

With the schema-dump fixes in place, the full client contract was exercised
against production via PostgREST + RPC with a fresh test user's own JWT
(RLS-scoped, publishable key only — the exact calls the Flutter client
makes). Round 1 (14/18) surfaced one more real bug the dump-reading had
missed; round 2 (11/11) passed everything.

**Bug 4 — `one_window_per_loop` UNIQUE(loop_id, window_number).** The M5.4
retest design assumed a retest could insert a second `window_2` row; the
insert 409'd live. The constraint WAS in the dump — my earlier grep missed
it (the "no unique constraint" claim in the previous entry was wrong, and
this correction supersedes it). Fixed: a retest now resets
`administered_at` on the loop's one row and re-runs
`process_phase5_reassessment`, which overwrites every computed column.
Verified live: same row id, clock reset, `false_positive` reclassified to
`true_ascension`/`new_loop` on the retest.

**Bug 5 — `one_drill_per_loop` UNIQUE(loop_id).** Same shape: M5.4's
deepening/track-reassignment drills would have 409'd on a second drill
insert. Fixed: `DrillController` now updates the loop's one drill row (new
answers, resolved `deepening_layer`) and re-runs `process_phase3_drill`.
Verified live: `deepening_layer` 1 -> 2 on the same row, `assigned_protocol`
recomputed, no 409.

Round-2 trail (test account `m52-api-verify2-1784500982739@example.com`):
window2 false_positive/retest_scheduled read back with deltas
(-175/-175/-175); rediag -> reclassify_residual + track_reassignment;
retest row reuse + clock reset + reclassification; loop auto-completed by
the RPC itself (`status=complete`, `completed_at`, `exit_score=442.5`,
`exit_zone=builder` — confirms removing the client `markLoopComplete` was
right); drill deepening update path; window3 durability (classification
written, `routing_outcome` null as the client assumes); `user_calibration`
read back after the durability engine ran.

**Test accounts to add to the cleanup pass** (same orphaned-`auth.users`
reasoning as M3.4/M4.x): `m52-api-verify-1784500478699@example.com` and
`m52-api-verify-1784500482929@example.com` (round 1 ran twice due to a
shell `||` misfire), `m52-repro-1784500960533@example.com` (409 repro),
`m52-api-verify2-1784500982739@example.com` (round 2).

**Still pending:** the browser-level manual runs (day-5 Window 2, day-21
Window 3 with your approved `started_at` backdates) covering the UI gating
and rendering end to end. The backend contract those runs depend on is now
verified; what remains unverified is the Flutter UI against production
(window gates, hub states, closing screen).

## M5 browser manual run — COMPLETE, two more real bugs found and fixed (2026-07-19)

Full browser verification against production (release build, headless
Chromium via Playwright, fresh test accounts, `started_at` backdates run
through each test account's own JWT under RLS — covered by your 2026-07-19
blanket approval). Screenshots are in `Screenshots/` (m5-01 through m5-08).

**Bug 6 — rediag navigation crashed in release builds.** On a
`false_positive` submit, the flow swapped the PageView out for the loading
dot; the submit finished with the PageView unmounted, so
`PageController.nextPage` had no attached position and threw
`Bad state: No element` (asserts stripped in release). The widget test
could never catch this — tester frames don't interleave with the handler.
Fixed by keeping the PageView mounted and rendering the loading state as
an overlay.

**Bug 7 — the rediag path mounted for Window 3 too.** A day-21
`false_positive` continued into rediag questions instead of closing on the
calibration view, and `route_false_positive`'s `track_reassignment`
routing would have contradicted the loop's close. Rediag is now scoped to
Window 2 (PRD M5.3's actual text), with a widget test pinning that a
Window 3 `false_positive` closes on the calibration screen.

Verified end-to-end after the fixes (each on a fresh account): auth gate
login; hub day-5 state with the Day 5-7 check-in CTA; the full Window 2
flow with `false_positive` answers; rediag mounting inline and completing;
post-rediag result showing typed copy ("The change is real", never the
token) with the Start-a-fresh-drill CTA; the drill destination loading;
the hub reflecting `track_reassignment`; the 48-hour retest wait state
(disabled "Your check-in opens soon" on the hub — verified live on an
earlier account); the gate-closed backstop when re-entering a completed
check-in's URL; the hub offering the Day 21 durability check after
backdating; the Window 3 flow closing on "Three weeks later, it holds"
with progress dots and zero digits anywhere on the closing screen
(aria-verified); the hub closing the loop with Start a new loop.

**Browser-phase test accounts for the cleanup pass** (same
orphaned-`auth.users` reasoning as before):
`m52-ui-verify-1784501186869@example.com`,
`m52-ui-verify-1784502735325@example.com`,
`m52-ui-verify-1784503431865@example.com`,
`m52-ui-verify-1784503681818@example.com`,
`m52-ui-verify-1784503931695@example.com`,
`m52-ui-verify-1784504447822@example.com`.

**Automation notes for the next session that drives this app:** Flutter
web keeps its semantics tree off until the off-viewport
`flt-semantics-placeholder` is activated via JS `el.click()` (it is
outside the viewport, so a normal Playwright click times out); page
reloads reset that toggle; the first keystroke after focusing a text
field can be eaten (settle ~500ms before typing); option clicks right
after a page transition can be dropped (click-verify-retry); `fill()`
can miss Flutter's onChanged — click then `keyboard.type`. The M4.5
stale-bundle warning still applies; serving `build/web` with
`Cache-Control: no-store` avoided it this time.

With this run, the M5.2 and M5.5 done-when manual verifications are
COMPLETE (day-5 Window 2 shows a classification; day-21 Window 3 updates
the hub calibration display). No M5 items remain pending except your
review and the test-account cleanup.

## M5.R2 cold-context copy rubric judge — one violation found and fixed (2026-07-22)

Per CLAUDE.md's copy-gate rule, dispatched a fresh subagent with only the
rubric (raw tokens, zone-as-noun, calibration vocabulary, mechanic
numbers/instrument meta-commentary, em dashes, urgency/guilt/streak/
permanent-identity, Flow-not-reachable-from-one-assessment) and the copy
strings extracted verbatim from `reassessment_tokens.dart`
(ClassificationCopy + RediagCopy), `reassessment_screen.dart` (`_ClosingView`,
`_GateClosedView`, `_ReassessmentErrorView`, snackbar text), and
`routing.dart` (all CTA labels). No file paths, no diff, no authorship
context given to the judge.

**Verdict: one violation, fixed.** `RediagClassification.reclassifyResidual`
body read "Your scores were flat, but your behavior was not." — "scores" is
calibration/instrument vocabulary (rubric rule 3). Changed to "What you
reported stayed flat, but your behavior did not." in
`lib/features/reassessment/reassessment_tokens.dart`. `flutter analyze`
clean, `flutter test` 220/220 green after the fix. Not re-judged by a fresh
pass per the brief (self-review by the fixing session doesn't count as a
gate) — flagging here for your own read if you want a second look.

All other strings passed every rule, including the `Flow` display-name
usage in `_ClosingView` (sanctioned exception, rule 2) and the "never to a
single assessment" / "earned loop by loop" framing (correct compliance with
rule 7, not a violation).

## M6.1 full-loop verification — two real bugs found and fixed, one open item (2026-07-23)

Ran the complete `levels-verify` suite (all PASS) plus the two checks added
to M6.1's done-when this session (security audit, retest-reuse regression
check). Full details and the row trail are in `docs/PRD.md`'s M6.1 entry.
Summary:

1. **IDOR fixed.** Five SECURITY DEFINER functions
   (`compute_center_of_gravity`, `process_phase5_reassessment`,
   `process_window3_durability`, `apply_window3_calibration`,
   `route_false_positive`) had no ownership check and were anon-executable.
   Fixed via two migrations, verified clean post-fix.
2. **`true_ascension` loops could never reach Window 3 — fixed.**
   `LoopState` checked `loopComplete` before `window3Open`, so
   `apply_window3_calibration`'s durability confirmation was dead code for
   the one classification it exists to confirm. Fixed in `loop_state.dart`,
   pinned with two new tests, verified live.
3. **Open item — `ascension_loops.exit_score`/`exit_zone` are unclamped.**
   `process_phase5_reassessment` writes `exit_score = center_of_gravity +
   combined_delta` with no ceiling, so a single Window 2 true_ascension can
   write `exit_zone = 'flow'` directly — on its face this contradicts
   CLAUDE.md's "Flow reachability is climb-based, never single-assessment"
   rule. Confirmed via `grep` that no client Dart code reads either column
   today (`lib/` has zero references beyond one doc comment), so this is
   not currently a live UI bug — the actual Flow-gating path
   (`user_calibration.calibrated_level`, via `apply_window3_calibration`)
   is correctly clamped and gated on the 3-loop streak, verified live in
   this same run (`calibrated_level = 500.00`, `flow_resident = false`
   after 1 loop). Not fixed — `process_phase5_reassessment`'s body is
   frozen without your sign-off, and it's unclear whether `exit_score` is
   meant to be a raw historical snapshot (current behavior, arguably fine)
   or should carry the same clamp. Flagging for a decision, not urgent.

**Test account to add to the cleanup pass:**
`m61-fullloop-verify-1784768780@example.com` (loop
`7f1fa09c-8d1c-45a6-a3be-b6bace345051`), same orphaned-`auth.users` reasoning
as every prior milestone's accounts. This one completed the full five-phase
trail including both Phase 5 windows.

## Production security sweep (2026-07-28)

Ran the `levels-verify` suite plus a full `get_advisors` pass on `main` after
deleting the merged `kimi/m5` branch. Scoring core is clean: all 16
`score_to_zone` boundaries, 4 weighting values, 11 raw-score tokens, and 3
Phase 5 classification cases match production, `compute_center_of_gravity`
still captures `was_clamped` before the `LEAST` clamp and still runs the
consistency cluster check against the raw mean. `flutter analyze` zero
issues, `flutter test` 222/222, Edge Function v9 ACTIVE, and production's
migration history matched the repo exactly at 12 files.

Four things came out of it. Three are fixed and deployed; one is yours.

**Fixed: `waitlist` and `join_waitlist()` were never under migration control.**
Both have existed in production since the marketing-site signup form shipped,
created through the SQL editor. Production's `schema_migrations` had 12 rows
and neither object appeared in any of them, so a rebuild from migrations
would have silently produced a database with no waitlist table. Declared
as-is in `20260728203732_declare_waitlist_schema.sql`, reproducing the live
definitions verbatim. No behavior changed.

**Fixed: two trigger functions were callable by `anon` over REST.**
`handle_new_user()` and `seed_calibration_from_assessment()` are SECURITY
DEFINER and still carried the default PUBLIC execute grant, so anyone could
hit them at `/rest/v1/rpc/`. Same class of gap the July 23 and 24 migrations
closed on the client RPCs; these were missed because they fire from triggers
rather than from the client. Revoked in `20260728203733`. Both triggers
verified still enabled afterward (`tgenabled = 'O'`).

**Fixed: five scoring functions had a mutable `search_path`.** Low severity,
since all five are SECURITY INVOKER and run with the caller's own rights, but
they were a permanent WARN on every advisor run. Pinned in `20260728203734`.
Golden values re-verified unchanged after the ALTER.

**Yours: leaked-password protection reads as disabled.** The advisor flags
`auth_leaked_password_protection` as WARN right now. A session on 2026-07-24
logged toggling this on along with email confirmation, so either the toggle
did not save or it was later reverted. Live state wins. It is a switch in
Auth settings under Password Security, not something a migration can set.

**Also worth a decision, not fixed:** the `waitlist` SELECT policy is
`auth.uid() = id`, but `id` is the waitlist row's own `gen_random_uuid()`
primary key, not a `users.id`. The comparison can never be true, so no client
role can read the table at all and only `service_role` can. That happens to
be the safe outcome, so the catch-up migration declared it rather than
changing it. Decide whether you want it left inert or rewritten to match on
email once a user signs up.

**Not verified this session:** a fresh end-to-end signup. The EXECUTE revoke
should not affect trigger firing (Postgres invokes trigger functions
internally, without consulting the caller's grant), and both triggers read as
enabled, but the confirming check is one real signup in the browser watching
for a new `public.users` row. Worth doing before launch regardless.

Advisor warning count went from 20 to 9. The 9 that remain are the
client-facing Phase 3/5 RPCs and `join_waitlist`, all intentional and all
carrying `auth.uid()` ownership guards, plus the password-protection item
above.

## 2026-07-29: signup verification closed, em-dash ban applied to app copy

**Closed: the fresh end-to-end signup the 2026-07-28 entry left open.** A real
browser signup on the running client created `auth.users` and `public.users`
together (31 to 32 on both, zero orphans), and completing the assessment seeded
`user_calibration` from `phase1_assessments`. So both EXECUTE-revoked trigger
functions, `handle_new_user` and `seed_calibration_from_assessment`, fire
normally with `anon` and `authenticated` both denied. The revoke is verified,
not just reasoned about. Test account: `trigger-check-20260729@levels-test.local`
(user `db0b0118-ad4d-4ede-9029-11e0c6b1652f`), scored 390.00 / builder /
scattered. That makes 21 test accounts awaiting cleanup, not 20.

**Fixed: the 2026-07-19 em-dash ban had never been applied to the app.** Found
41 em dashes in user-facing copy. Cleaned 31 of them:

- `index.ts` prompt: added a hard rule forbidding em dashes, and removed the
  four in the prompt's own instruction text, which had been modelling the exact
  style it was supposed to forbid.
- New `leaksEmDash` guard beside the existing `leaksNumbers` guard, so an LLM
  generation containing an em dash is rejected in favour of fallback copy.
  Enforced rather than requested.
- `fallback.ts`: all 17 rewritten with periods, colons, and one parenthetical.
  Punctuation only. Every approved claim is unchanged in meaning, including the
  clamped-ceiling illusion framing and the Flow-reachability language.
- `drill_questions.dart` (13) and `home_screen.dart` (1).

Deployed as Edge Function v10 then v11, both MCP read-back verified. Commits
`c7ae359` and `e174bcd`, both pushed to `origin/main`.

**Yours: `fallback.ts` copy changed, so the M2.4 tone verdict is arguably
stale.** The edits are punctuation-only and touch no mechanic, number, or zone
claim, which is why the existing verdict was treated as still standing rather
than reopening the gate. If you want it airtight, a fresh cold-context rubric
pass over the seven zone variants is cheap. Your call, not one to assume.

**Not done, deliberately: `track_content.dart` still has 10 em dashes.** It is
under the M4.1 content gate, so rewriting it reopens that review. It is the
last remaining user-facing violation. Also left alone: one em dash in a
`StateError` in `track_session_controller.dart`, which is a developer-facing
exception string, not copy.

**Two schema-doc drifts found while verifying:** `phase1_assessments` uses
`dominant_zone`, not `zone`, and `user_calibration` is keyed on `user_id` with
no `id` column. Worth checking anywhere that claims otherwise.
