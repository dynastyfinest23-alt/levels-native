# Levels Design System — MASTER

Binding visual system for the Levels native client. Derived from
`levels-design-system-brief.md` (2026-07-08). **Read this before building or
modifying any screen** (CLAUDE.md → Design system). Every value below becomes
a `const` in `lib/core/design_tokens.dart` and flows into widgets via
`ThemeData` or the `ZoneStyle` resolver — never as inline literals.

The one-sentence system: **a dark, still atmosphere in which the user's zone
determines the quality of light.**

## 1. Foundations — the atmosphere (zone-independent)

| Token | Value | Use |
|---|---|---|
| `void` | `#0B0C15` | Scaffold background — deep space, near-black indigo |
| `surface` | `#131525` | Cards, panels at rest |
| `surfaceRaised` | `#1A1D33` | Hovered/active panels, app bar on scroll |
| `glassFill` | `#1A1D33` @ 62% alpha | Reveal-card fill (glass) |
| `glassStroke` | `#FFFFFF` @ 8% alpha | 1px inner border on glass surfaces |
| `textPrimary` | `#ECEDF4` | Headings, body |
| `textSecondary` | `#9EA3BF` | Supporting text, labels |
| `textFaint` | `#5C6180` | Locked/disabled text, timestamps |
| `auroraA` | `#20265C` | Signature gradient, bottom stop |
| `auroraB` | `#3A2E6E` | Signature gradient, mid stop |
| `auroraC` | `#1C3A56` | Signature gradient, top stop |

**Aurora signature:** one soft radial/linear mesh of `auroraA→B→C`, extremely
low contrast against `void`, applied ONLY to full-screen backdrops (home hub,
dashboard, auth). It is atmosphere, not decoration — if a screenshot makes it
look like a "gradient design", it's too strong. Panels never carry the aurora.

Light mode: none in v1. The product is dark-only by design (brief: dark as
the wellness premium default). Do not add a light theme without a MASTER.md
revision.

## 2. The six-zone spectrum (the only zone→color mapping)

One ascending journey — value, saturation, and temperature climb with energy
(CLAUDE.md rule). Cold dim indigo at the bottom of the climb to radiant warm
gold at the top. Never chakra-rainbow, never red for low zones.

| Zone | Display name | `zoneColor` | `zoneGlow` (color @ alpha) | Character |
|---|---|---|---|---|
| collapsed | Collapsed | `#4E5578` | `#4E5578` @ 20% | cold, dim, grey-indigo |
| contracted | Contracted | `#5F6FC0` | `#5F6FC0` @ 24% | indigo, first saturation |
| reactive | Reactive | `#7D6DD8` | `#7D6DD8` @ 28% | violet, restless energy |
| threshold | Threshold | `#A96FD6` | `#A96FD6` @ 32% | orchid, warming |
| builder | Builder | `#DB7E93` | `#DB7E93` @ 36% | rose-ember, kinetic warmth |
| flow | Flow | `#F5C066` | `#F5C066` @ 44% | radiant gold, arrival light |

Rules:
- **Display names, never tokens.** UI text uses the Display name column
  (via `ZoneStyle`), never the raw enum token ("builder" in the UI is a bug).
- `zoneColor` is used for: the CoG numeral, the zone name, the primary CTA
  fill on zone-bearing screens, glow halos, and progress accents. It is NOT
  used for body text or backgrounds.
- `zoneGlow` renders as a large soft `BoxShadow`/radial behind the CoG
  numeral and (subtly) behind the primary CTA. Glow radius ≥ 48px blur, no
  hard edges. Glow intensity climbing with zone is intentional — the climb
  is literally brighter.
- Screens with no zone context (auth, placeholders) use `contracted`'s hue
  family as a neutral accent (`#5F6FC0`), no glow.

## 3. Typography

Bundled asset fonts (OFL), declared in `pubspec.yaml` under `fonts:` —
**approved by this document; the `google_fonts` package remains forbidden.**

- **Display: Fraunces** (weights 300, 600) — the CoG numeral, screen titles,
  zone names. Its warmth keeps the dark UI human.
- **Body/UI: Inter** (400, 500, 600) — everything else.

| Token | Font | Size/height | Use |
|---|---|---|---|
| `displayScore` | Fraunces 300 | 88/1.0, tabular figs | CoG numeral only |
| `displayTitle` | Fraunces 600 | 32/1.2 | Screen titles |
| `zoneName` | Inter 600 | 14/1.2, +0.12em tracking, small caps feel (uppercase) | Zone display name under the numeral |
| `panelTitle` | Inter 600 | 13/1.3, +0.08em tracking | Reveal-panel titles, section labels |
| `body` | Inter 400 | 16/1.55 | Reveal copy, paragraphs |
| `invitation` | Fraunces 300 italic | 20/1.5 | `bridge_question` text ONLY |
| `button` | Inter 500 | 15/1.0 | CTAs |
| `caption` | Inter 400 | 12.5/1.4 | Calibration strip, metadata |

## 4. Space, shape, elevation

- Spacing scale (px): 4, 8, 12, 16, 24, 32, 48, 64. Screen gutter 24.
  Content max-width 560px centered on web — the app is a column of focus,
  not a full-bleed dashboard.
- Radii: panels 16, buttons 999 (pill), the score has no container.
- Elevation is light, not shadow: raised = `surfaceRaised` + `glassStroke`.
  Drop shadows exist only as zone glows. No Material elevation tints.

## 5. Motion — slow, settled, deterministic

| Token | Value | Use |
|---|---|---|
| `reveal` | 600ms, `Curves.easeOutCubic` | Panel content fade+rise (12px) on reveal |
| `page` | 350ms, `easeOutCubic` | Route transitions, fade-through |
| `breath` | 2400ms, `easeInOut`, ±6% glow alpha | CoG glow idle pulse (one element per screen max) |
| `press` | 120ms | Button/tap feedback |

Rules: motion never blocks input; nothing loops except `breath`; **the CoG
number never counts up, spins, or shimmers into place** — it appears settled
(deterministic result, not a slot machine; CLAUDE.md tone rules). Reduced-
motion: respect `MediaQuery.disableAnimations` by dropping `reveal` to fade-
only and killing `breath`.

## 6. Component specs

- **CoG anchor (dashboard):** `displayScore` numeral in `zoneColor` over its
  `zoneGlow` halo (the `breath` element), `zoneName` beneath in uppercase
  tracking, on the aurora backdrop. Nothing else competes — the "Center of
  Gravity" label is `caption`/`textSecondary`.
- **Reveal panels:** glass cards (`glassFill` + `glassStroke`, radius 16).
  Locked: `textFaint` title, lock glyph at 40% opacity, no fill change.
  Tappable: title `textPrimary` + a 2px left accent in `zoneColor` + "Tap to
  reveal" in `textSecondary`. Revealed: body copy enters with `reveal`
  motion. Panels grow with copy — min-height only, never fixed height.
- **Bridge question:** NOT a glass card. Open layout: a thin `zoneColor`
  hairline above, question in `invitation` type, generous 32px padding —
  visually an invitation, not a fourth data panel.
- **Primary CTA:** pill, `zoneColor` fill at 90% (neutral accent where no
  zone), `void`-dark text at ≥4.5:1 contrast, subtle zone glow. One primary
  CTA per screen (hub rule already).
- **Calibration strip:** `caption` type on `surface`, no glass, no glow —
  it's an instrument readout, deliberately quiet.
- **Loading:** replace spinners with a slow-breathing 8px dot in the accent
  color where feasible; error states keep the house pattern (message +
  retry) styled with `textSecondary`, never red-boxed.
- **Coming-soon placeholders:** `displayTitle` + one `body` line + text
  button home. No glass, no glow — placeholders stay humble.

## 7. Implementation map (for the applying model)

1. `lib/core/design_tokens.dart` — every table above as `const` values
   (`LevelsColors`, `LevelsType`, `LevelsSpace`, `LevelsMotion`).
2. `lib/core/zone_style.dart` — `ZoneStyle.of(EnergyZone)` → display name,
   `zoneColor`, `zoneGlow`; throws on unknown zone (house rule). Pinned by a
   test asserting all six zones resolve and display names match this file.
3. `ThemeData` in `main.dart` built from tokens (colorScheme, textTheme,
   cardTheme, filledButtonTheme); widgets consume the theme, reaching for
   `ZoneStyle` only for zone-reactive elements.
4. Fonts: download Fraunces + Inter OFL files to `assets/fonts/`, declare in
   `pubspec.yaml`. No new packages.

## 8. Anti-patterns (check every new screen against this list)

1. Raw enum token in UI text (e.g. "builder") — always `ZoneStyle` display name.
2. Inline hex / ad-hoc `TextStyle` in a widget — tokens only.
3. Chakra-rainbow zone mapping, or red/danger styling for low zones.
4. Fixed-height text containers for LLM copy.
5. Glass on non-reveal surfaces; aurora on panels; more than one `breath`
   element per screen.
6. Any animation implying the score is being computed/randomized (count-up,
   slot roll, shimmer).
7. Urgency mechanics: countdown styling, alarm colors, streak-guilt visuals.
8. Light-mode improvisation.
9. A second primary CTA on one screen.
10. New tokens invented in widgets — propose them here first, then implement.
