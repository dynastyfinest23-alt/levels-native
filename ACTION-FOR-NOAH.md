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
