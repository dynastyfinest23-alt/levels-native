Purpose: design and first-time-user review of the Levels native client, with a prioritized fix list. Source: Claude session 2026-11-09, requested by Noah.

# Levels design and UX review (2026-11-09)

**Overall: 5.5/10.** Backend discipline is far ahead of the product surface.

## Evidence and limits

- Looked at 6 of the 13 July screenshots in `Screenshots/` (hub, reassessment, rediag result, drill).
- Read the code for login, signup, assessment, dashboard, hub, router, theme, and the web shell.
- NOT rendered: login, signup, assessment, dashboard. `build/web` dated 2026-07-23; no rebuild was done.
- NOT run: tests, backend verification. `marketing-site/` not covered.
- Screenshot issue numbers 3 and 4 describe `main` before PR #9 (shared `AnswerCard`).

## Report card

| Area | Score | One line |
|---|---|---|
| Design | 5.5 | Good bones (Fraunces + Inter, restrained palette, real tokens); component defects and dead space. |
| UX flow | 4 | No onboarding, jargon, and the payoff moment ends on "Done". |
| Code quality | 8 | Small, typed, single submit path, default-deny router, tokens enforced. |
| Performance / security | 6 | Security strong on paper; heavy web first load; template web shell. |
| Testability | 6.5 | Pure contracts pinned well; screens almost untested. |

## Issues

### Design

1. Primary buttons are about 32px tall and 512px wide: reads as a progress bar, under the 48px touch minimum.
2. The bottom "Continue" bar in drill and reassessment runs edge to edge (about 1230px) while content sits in a 512px column.
3. Answer cards shrink to text width in reassessment (ragged) and are full width in the assessment.
4. Selected state is a 2px left border clipped by `ClipRRect`: looks like a glitch. Hover shows square corners inside a rounded card.
5. The hub is about 60% empty.
6. App bar title and logout icon are pinned to the window edges, detached from the content column.
7. "Signed in as <email>" is the first thing on the hub (`lib/features/home/home_screen.dart:245`).
8. Score shows two decimals at 88px (`lib/features/dashboard/dashboard_screen.dart:322`).
9. Lock icons plus "Tap to reveal" four times.
10. Aurora backdrop is nearly invisible.
11. No brand mark; favicon is Flutter's.

### First-time user

12. First screen is a login form with "Log in to continue your climb" (`lib/features/auth/login_screen.dart:80`).
13. Nothing says what the app is, how long the assessment takes, or what the user gets.
14. Signup asks for the password twice; no Google or Apple; no password reset anywhere in `lib/`.
15. Hub after signup is one unexplained button: "Begin assessment".
16. Seven questions with up to seven full-sentence options each.
17. Options run low to high in the questions read: the scale is visible and gameable.
18. Tapping the last answer submits immediately, no review or confirm.
19. Refresh or browser back loses every answer.
20. After question 1 the exit X becomes a back arrow; no way out except the browser.
21. Loading screen shows "Provisional: ~N" before the reveal (`lib/features/assessment/assessment_screen.dart:249`).
22. Undefined jargon: Center of Gravity, Loop, Calibration, Verified climb, origin drill, durability check, track.
23. The reveal ends on "Done", which goes home (`lib/features/dashboard/dashboard_screen.dart:248`); the bridge question has nowhere to be answered from there.
24. No way to see a past result; the hub has one button and no history.
25. Hub repeats itself: phase label directly above a button with the same words.
26. "Calibration: Verified climb" dots are unexplained.
27. Raw exception text shown to users (15 occurrences of `error.toString()` / `$error` in `lib/`).

### Code, performance, security, tests

28. Assessment submit is five sequential round trips, not atomic (`lib/features/assessment/assessment_controller.dart:69-106`); a mid-way failure plus retry leaves an orphan loop.
29. `loop_number` is computed on the client (constraint not checked).
30. Web shell is the Flutter template: title `levels_native`, description "A new Flutter project.", manifest colour `#0175C2`.
31. No splash or background colour in `web/index.html`; 2.85 MB `main.dart.js` plus CanvasKit.
32. Fonts total 1.6 MB.
33. Zero `Semantics` in `lib/`.
34. Password minimum 6 characters; email confirmation off.
35. Anthropic key expires 2026-11-21 (per `CLAUDE.md`); copy silently falls back to static text after that.
36. Screens hard to test: `HomeScreen` builds its own `JourneyRepository()`; five screens have no widget tests.
37. CI never builds the app; no end-to-end test.

## Fix list (execution order)

| # | Fix | Covers | Impact | Risk | Effort | Needs Noah |
|---|---|---|---|---|---|---|
| 1 | Rotate the Anthropic key before 2026-11-21 | 35 | High | Low | 10 min | Yes, Noah does it |
| 2 | Web shell: title, description, theme colour, dark background, loader | 30, 31 | High | Low | 1 hr | Approve description copy |
| 3 | Welcome screen before auth; default to signup | 12, 13, 15 | High | Low | Half day | Approve copy |
| 4 | Reveal ending: drop provisional number; "Done" becomes a step into the drill | 21, 23 | High | Low | Half day | No |
| 5 | Component pass: 48px buttons, CTA in the column, full-width cards, real selected state (after PR #9) | 1 to 4 | High | Low | 1 day | No |
| 6 | Hub: drop email line, add last result and one plain sentence on what is next | 5, 7, 24, 25, 26 | Medium | Low | Half day | Approve copy |
| 7 | Friendly error copy; raw detail in debug builds only | 27 | Medium | Low | 2 hrs | No |
| 8 | Confirm on question 7; exit always available; drop confirm-password; password reset | 14, 18, 20 | Medium | Low | Half day | No |
| 9 | Move submit into one RPC (migration via `levels-dev-loop`) | 28, 29 | Medium | Medium | 1 day | Yes |
| 10 | Shuffle or interleave answer order (changes the instrument) | 17 | Medium | Medium | Half day | Yes |
| 11 | Semantics labels; widget tests for five screens; build step in CI | 33, 36, 37 | Medium | Low | 1 to 2 days | No |
| 12 | Subset fonts | 32 | Low | Low | 2 hrs | No |

The three that move the score most: 3 (with 2), 4, and 5. Estimated result: 7.5/10.

## Status

- [ ] 1 Key rotation
- [ ] 2 Web shell (branch `fix/web-shell-metadata`)
- [ ] 3 Welcome screen
- [ ] 4 Reveal ending
- [ ] 5 Component pass
- [ ] 6 Hub
- [ ] 7 Error copy
- [ ] 8 Assessment and auth friction
- [ ] 9 Atomic submit
- [ ] 10 Answer order
- [ ] 11 Accessibility, tests, CI build
- [ ] 12 Fonts
