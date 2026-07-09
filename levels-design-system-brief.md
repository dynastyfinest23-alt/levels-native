# Levels design-system brief

Input brief for `design-system/MASTER.md` (authored 2026-07-08, Fable 5, from
market research + the standing product rules in CLAUDE.md). MASTER.md is the
binding artifact; this file records what it was derived from and why.

## What the current UI is (and why it fails)

Stock Material 3 with a single seed color: default cards, default type ramp,
raw enum tokens rendered as UI text ("builder"). It reads as a settings page.
The product moment — a person seeing a number that claims to describe their
inner state — deserves gravity, atmosphere, and reverence. Generic UI actively
undercuts the Variable Reward.

## Emotional targets

- **Ethereal, not mystical-kitsch.** Depth, luminosity, quiet. No chakra
  rainbows, no lotus clip-art, no glowing third eyes.
- **The reveal is a ritual.** Phase 2 should feel like surfacing something
  that was already there — slow, deliberate, earned.
- **Zones are light, not labels.** A zone is rendered as a quality of light
  the UI takes on — dim and cold low in the climb, radiant and warm high —
  never as a badge, grade, or color-coded warning.
- **Low zones get dignity.** A collapsed reading must never look like an
  error state. Dimmer, quieter — never red, never alarming.

## Research distillation (2026 wellness/app UI)

From current trend and wellness-app design coverage: cool, calm palettes and
minimalist layouts to cut cognitive load; dark mode as the premium wellness
default; "Liquid Glass"-style glassmorphism back in disciplined form —
reserved for overlay cards and high-value surfaces, not everywhere; soft
purposeful gradients (aurora/mesh, not harsh stops) adding depth without
noise; slow ambient motion as brand language (Calm's slow animations,
nature-evoking atmosphere; Headspace's warm singular accent). What we adopt:
**one dark atmospheric base + one aurora signature gradient + glass reveal
cards + a zone-colored glow system + slow motion.** What we reject: adaptive
AI theming, audio-first chrome, AR gimmicks, glass on every surface.

## Hard constraints (from CLAUDE.md — binding)

- No new pub dependencies. Fonts ship as bundled asset files declared in
  `pubspec.yaml` (OFL-licensed), not via the `google_fonts` package.
- All styling flows through `ThemeData` + token constants; no inline hex in
  widgets, no per-screen font choices.
- The six-zone palette is a single ascending spectrum: value, saturation, and
  temperature climb with energy.
- The CoG number is the dashboard's visual anchor; `bridge_question` is
  styled as an invitation, distinct from the other three reveal parts.
- Every text container tolerates variable-length LLM copy — no fixed heights.
- Copy/tone rules apply to visual language too: no manufactured urgency, no
  implying a low zone is identity, nothing that makes the score feel random.
- Web (Chrome) is the only platform today; tokens must also make sense on
  mobile later.
