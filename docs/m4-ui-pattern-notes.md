# M4 UI pattern notes — research pass over `reference-flutteropen/`

Purpose: candidate UI techniques for the Phase 4 track screens (M4.3–M4.6,
`docs/PRD.md`), mined from the local read-only reference clones. Research
only — no `lib/` changes in this pass. No code from any reference repo is
reproduced here; every technique is described in plain language. License
status per repo is as corrected in `CLAUDE.md`'s "Reference Repositories"
section (verified 2026-07-16): copying code verbatim (with attribution) is
permitted only from `flutter-layouts-exampls` (MIT) and `flutter-ui-nice` /
`fun_flutter` (Apache-2.0); the other 7 repos — including all three cited
below (`flutter-canvas`, `flutter-animations`, `flutter-widgets`) — have no
license declaration, so they are **reference pointers only: study the
technique, rewrite from scratch, never copy their code.**

Repos skimmed per the task scope: `flutter-canvas`, `flutter-animations`,
`flutter-widgets`, `flutter-ui-nice`. `fun_flutter` was deliberately not
opened (flagged low-trust/broken source tree per CLAUDE.md). The other 6
repos (`FlutterImitation`, `design_patterns`, `flutter_source`,
`flutter-layouts-exampls`, `flutter-ui-tutorials`) were out of the
instructed scope for this pass and were not opened.

## Repos with nothing further to report

**`flutter-animations`** — only 2 demo screens. `FlarePage.dart` depends on
the `flare_flutter` package (a 2D animation asset player) — this project
adds no dependency without approval, and Flare/Rive assets aren't part of
this app's design system, so it's a hard skip regardless. `AnimationOnePage.dart`
is a bare `AnimationController` + `Tween` + `addListener(setState)` rotating
a logo — textbook-level, nothing this project doesn't already know how to
do, and no staged-reveal-specific technique beyond what's below. No entry
written for this repo.

## Per-screen findings

### M4.3 — completion + commitment screens

**1. Cross-fade between stage states via `AnimatedCrossFade`.**
Flutter's built-in `AnimatedCrossFade` widget swaps between two children
with independent enter/exit curves, driven by a single boolean flip (no
manual `AnimationController` needed) — demonstrated in
`flutter-widgets/lib/page/anim/AnimCrossFadePage.dart` (unlicensed repo —
reference pointer only; `AnimatedCrossFade` itself is a Flutter SDK widget,
not this repo's code).
*Applies to:* the completion track's conditional integrity-check reveal
(statement/duration stage → integrity-check copy, only when the controller
decides to show it) and the commitment track's check-in stage appearing
72h after the initial declaration.
*Adaptation:* durations/curves should be pulled from `LevelsMotion` tokens
in `design_tokens.dart`, not hardcoded `Duration(seconds: 1)`/`Curves.easeIn`
literals as in the demo. Anti-pattern check: this is a state swap, not a
score animation — fine against MASTER.md §8 item 6 as long as it's never
used to animate the CoG number or any zone value.

**2. `Stepper` widget as an alternative to the existing `PageView` shape —
considered, not recommended.** `flutter-widgets/lib/page/stepper/stepper_page.dart`
shows Flutter's built-in `Stepper` (vertical or horizontal, per-step
`StepState` including `editing`/`error`, custom `controlsBuilder` to replace
the default Continue/Cancel buttons). This is a structurally different shape
from the multi-page `PageView` pattern this project already established in
`lib/features/drill/drill_screen.dart` for the same kind of "N sequential
questions" flow. Recommend staying with the existing `PageView` convention
for completion/commitment (both are short, 2–3 stage, linear flows —
`Stepper`'s value is showing all steps' status at once, which these flows
don't need). Noting the option, not recommending it. If adopted anywhere,
`controlsBuilder` must not introduce a second primary CTA (MASTER.md §8
item 9) — style the single Continue button from `LevelsColors`/`LevelsType`,
drop the built-in Cancel button entirely rather than rendering it as a
second CTA.

### M4.4 — belief-audit screen

**3. Segment-label tabs driving a `PageController`.**
`flutter-ui-nice/lib/page/signup/SignPageFive.dart` (Apache-2.0 — copying
permitted with attribution at implementation time, though nothing is copied
here) shows two label buttons ("LOGIN" / "SIGNUP") above a `PageView.builder`,
where tapping a label calls `_pageController.nextPage()`/`previousPage()`
and dims the inactive label via `Opacity`.
*Applies to:* belief-audit is the one track that repeats the same 3-question
shape N times (flag → authorship → cross-exam) per belief — PRD's own test
scenario uses 3 beliefs. A small row of tabs ("Belief 1" / "Belief 2" /
"Belief 3") above the existing per-belief `PageView` would let the user jump
between beliefs instead of being locked to forward-only navigation, which
plain sequential flows (assessment, drill) don't need but a *repeated*
flow benefits from.
*Adaptation:* replace the demo's raw `Opacity`-based active/inactive dimming
and hardcoded text styles with `ZoneStyle`/`LevelsColors` active-state
color and `LevelsType` for the tab labels; only viable while the belief
count stays small (2–3) — if the count is ever unbounded, tabs stop
scaling and the plain forward-only `PageView` is simpler. Log to
`ACTION-FOR-NOAH.md` if M4.4's actual belief-count cap is ever ambiguous
when that task starts — not decided here.

**4. Per-item completion state, conceptually borrowed from `Stepper`'s
`StepState`.** Not the widget itself — just the state model
(`not started` / `in progress` / `done`) that `Stepper` exposes per step
(`flutter-widgets/lib/page/stepper/stepper_page.dart`). Pairs naturally
with finding 3: a small checkmark or filled/outline dot per belief tab,
each visually reflecting the DB state (`flagged_beliefs[i]` present +
authorship pair present + `cross_exam_verdict[i]` present), all colors
from `LevelsColors`, never a raw green/red status-light pair (MASTER.md
§8 item 3 forbids red-for-incomplete as danger styling).

### M4.5 — embodiment screen + 7-day daily log

**5. Cross-fade for statement → body-response transition.** Same technique
as finding 1 (`AnimatedCrossFade`) — applies here to swapping the daily
identity statement into the body-response question once the user has sat
with it, rather than a hard screen cut.

**6. Determinate `CircularProgressIndicator` for the day-N/7 ring (simplest
option).** Flutter's built-in `CircularProgressIndicator` accepts a static
`value` (0.0–1.0) with no animation required — demonstrated (with an
animated variant) in `flutter-widgets/lib/page/info/ProgressIndicatorPage.dart`
(unlicensed — reference pointer only).
*Applies to:* a simple day-progress ring on the embodiment session screen
and/or the M4.6 hub tile.
*Adaptation, and an anti-pattern flag:* the demo animates the ring filling
from 0 via an `AnimationController` on every screen load — that shape reads
exactly like "the score is being computed," which MASTER.md §8 item 6
explicitly forbids for anything that could look like the CoG being
calculated. Day/stage progress is a known, static fact by the time the
screen renders (`day_number / 7`), so the ring must render at its final
value immediately — no fill-in animation on mount. Track/zone color from
`ZoneStyle`/`LevelsColors`, never the demo's raw `BLUE`/`YELLOW` constants.

**7. Segmented multi-arc ring (more visual control, more effort) — optional
upgrade over finding 6.** `flutter-canvas/lib/circle/CirclePainter.dart`
(unlicensed — reference pointer only) draws a ring as N independent arcs
(`canvas.drawArc` per segment, proportional sweep angles from a weights
list) with rounded end-caps via small filled circles at each arc's ends.
*Applies to:* if the day-progress ring should show each of the 7 days as a
visually distinct segment (filled vs. unfilled) rather than one continuous
sweep, this is the technique — a custom `CustomPainter` computing 7 equal
sweep angles and coloring each by completion state.
*Adaptation:* would need a full rewrite (the source is pre-null-safety
Dart with hardcoded hex colors and a singleton size helper this project has
no equivalent of) — recommend only if MASTER.md's design language wants
discrete day-segments; otherwise finding 6 is far less code for the same
information. Not needed for embodiment `sensation_words`/`stage4_response`
capture itself — no relevant pattern found there beyond ordinary text/choice
input, which the project's existing `AnswerOption`/`OriginTypeOption`-style
typed-option pattern already covers.

### M4.6 — home hub track-progress integration

**8. Reuse whichever ring (finding 6 or 7) M4.5 adopts, rather than
building a second implementation.** The hub's "day N/7" or "stage M/4"
indicator is the same shape of fact as the embodiment session screen's own
progress ring; building one shared widget (parameterized by
current/total and a `ZoneStyle`-derived or track-appropriate color) avoids
maintaining two progress-ring implementations that could drift.

**9. No hub-specific pattern beyond the above.** The hub's actual job here
is data plumbing (reading `phase4_track_sessions`/`embodiment_daily_logs`
to compute current stage/day and routing the daily CTA) — that's
controller/repository work, not a UI pattern question, so nothing further
to report from this research pass.

## Summary table

| Screen | Pattern | Source (license) | Recommended? |
|---|---|---|---|
| M4.3 | `AnimatedCrossFade` stage transitions | Flutter SDK; demo in `flutter-widgets` (unlicensed, reference only) | Yes |
| M4.3 | `Stepper` as alt. to `PageView` | Flutter SDK; demo in `flutter-widgets` (unlicensed, reference only) | Considered, not recommended — breaks existing convention |
| M4.4 | Tab-labels + `PageController` for jumping between beliefs | `flutter-ui-nice` (Apache-2.0) | Yes, if belief count stays small |
| M4.4 | Per-belief completion state (concept only) | `flutter-widgets`'s `StepState` concept (unlicensed, reference only) | Yes |
| M4.5 | `AnimatedCrossFade` statement→response transition | Flutter SDK; demo in `flutter-widgets` (unlicensed, reference only) | Yes |
| M4.5/M4.6 | Static `CircularProgressIndicator` day/stage ring | Flutter SDK; demo in `flutter-widgets` (unlicensed, reference only) | Yes — simplest option |
| M4.5/M4.6 | Segmented multi-arc `CustomPainter` ring | `flutter-canvas` (unlicensed, reference only) | Optional upgrade, only if segmented look is wanted |
| M4.6 | Shared ring widget across hub + embodiment screen | (this project's own composition, not a source-repo pattern) | Yes |

No blockers or scope ambiguities surfaced during this pass worth escalating
to `ACTION-FOR-NOAH.md` beyond the belief-count note in finding 3.
