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

## M4.2 open product decisions (2026-07-16)

Built `lib/features/track/track_session_controller.dart` (start/resume +
per-stage save for all four `phase4_track_sessions` tracks). Verified live
against production first — two docs corrections came out of that (column is
`preparation_duration` not `prep_duration`; `belief_authorship_age` is
`int[]` not `text[]`, both now fixed in `docs/PRD.md` §2). No deployed
function references `phase4_track_sessions` at all (confirmed via
`pg_proc.prosrc` search), so two things are deliberately left as caller
decisions rather than invented here:

1. **`success_state_reached` criteria per track.** `TrackSessionController.finish()`
   takes an explicit `required bool success` — it persists whatever the
   caller decides, it doesn't compute it. Completion/belief_audit probably
   just mean "the user finished the flow," but commitment plausibly should
   depend on `checkin_response` (a `no` doesn't feel like success), and
   embodiment's true success condition (`day7_action_confirmed`) lives in
   the M4.5 daily-log table, not this session row. Needs a decision — or an
   explicit "finishing counts as success regardless" call — before M4.3-M4.6
   wire up their `finish()` calls.
2. **`completion` track's `integrity_check_triggered` rule.** Exposed as a
   plain `setIntegrityCheckTriggered(bool)` setter; the actual trigger
   condition (presumably some mismatch between `completion_statement` and
   `preparation_duration`, per the M4.1 copy's framing) isn't specified
   anywhere and isn't invented here. Needs a rule before the M4.3 completion
   screen is built.

Also carried over from the M4-UI-pattern-notes research pass: M4.4's
belief-count cap (2-3, unbounded?) isn't specified — affects whether the
tab-navigation UI pattern noted there still fits.
