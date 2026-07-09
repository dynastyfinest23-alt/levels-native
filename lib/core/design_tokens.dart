/// Design tokens for the Levels native client.
///
/// Every constant here is a direct transcription of
/// `design-system/MASTER.md` §1–§5 (Foundations, Typography, Space/shape/
/// elevation, Motion). The zone→color mapping (§2) lives in `zone_style.dart`
/// since it is a function of `EnergyZone`, not a flat constant table.
///
/// House rule (MASTER.md §8, anti-pattern #2): no inline hex codes or
/// ad-hoc `TextStyle`s in widgets — everything routes through these tokens
/// or through `ZoneStyle`.
library;

import 'package:flutter/material.dart';

/// §1 Foundations — the atmosphere (zone-independent).
///
/// `void` is a reserved word in Dart, so the scaffold-background token is
/// named `voidColor` here; it is still MASTER.md's `void`.
abstract final class LevelsColors {
  static const voidColor = Color(0xFF0B0C15);
  static const surface = Color(0xFF131525);
  static const surfaceRaised = Color(0xFF1A1D33);

  /// `#1A1D33` @ 62% alpha.
  static const glassFill = Color(0x9E1A1D33);

  /// `#FFFFFF` @ 8% alpha — 1px inner border on glass surfaces.
  static const glassStroke = Color(0x14FFFFFF);

  static const textPrimary = Color(0xFFECEDF4);
  static const textSecondary = Color(0xFF9EA3BF);
  static const textFaint = Color(0xFF5C6180);

  /// Aurora signature gradient stops (bottom → mid → top). One soft,
  /// extremely low-contrast mesh on full-screen backdrops only — never on
  /// panels (MASTER.md §1, §8 anti-pattern #5).
  static const auroraA = Color(0xFF20265C);
  static const auroraB = Color(0xFF3A2E6E);
  static const auroraC = Color(0xFF1C3A56);

  /// Neutral accent for screens with no zone context (auth, placeholders):
  /// `contracted`'s hue family, used with no glow (MASTER.md §2).
  static const neutralAccent = Color(0xFF5F6FC0);
}

/// §3 Typography.
///
/// Bundled asset fonts (Fraunces, Inter — OFL), declared in `pubspec.yaml`.
/// The `google_fonts` package remains forbidden (MASTER.md §3, §7).
///
/// Two MASTER.md properties aren't expressible as `TextStyle` fields and
/// must be applied at the call site:
/// - `zoneName`'s "uppercase" is a text transform: call `.toUpperCase()` on
///   the string, not the style.
/// - Tracking values below are converted from MASTER.md's em units to the
///   logical pixels `TextStyle.letterSpacing` expects (`em * fontSize`).
abstract final class LevelsType {
  static const _fraunces = 'Fraunces';
  static const _inter = 'Inter';

  /// CoG numeral only. Tabular figures so the digits don't jitter width.
  static const displayScore = TextStyle(
    fontFamily: _fraunces,
    fontWeight: FontWeight.w300,
    fontSize: 88,
    height: 1.0,
    color: LevelsColors.textPrimary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Screen titles.
  static const displayTitle = TextStyle(
    fontFamily: _fraunces,
    fontWeight: FontWeight.w600,
    fontSize: 32,
    height: 1.2,
    color: LevelsColors.textPrimary,
  );

  /// Zone display name under the numeral. Uppercase at the call site.
  static const zoneName = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    height: 1.2,
    letterSpacing: 14 * 0.12,
    color: LevelsColors.textPrimary,
  );

  /// Reveal-panel titles, section labels.
  static const panelTitle = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w600,
    fontSize: 13,
    height: 1.3,
    letterSpacing: 13 * 0.08,
    color: LevelsColors.textPrimary,
  );

  /// Reveal copy, paragraphs.
  static const body = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.55,
    color: LevelsColors.textPrimary,
  );

  /// `bridge_question` text ONLY — not a general-purpose style.
  static const invitation = TextStyle(
    fontFamily: _fraunces,
    fontWeight: FontWeight.w300,
    fontStyle: FontStyle.italic,
    fontSize: 20,
    height: 1.5,
    color: LevelsColors.textPrimary,
  );

  /// CTAs. Foreground/background colors are set by the button theme /
  /// zone context, not baked in here.
  static const button = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w500,
    fontSize: 15,
    height: 1.0,
  );

  /// Calibration strip, metadata.
  static const caption = TextStyle(
    fontFamily: _inter,
    fontWeight: FontWeight.w400,
    fontSize: 12.5,
    height: 1.4,
    color: LevelsColors.textSecondary,
  );
}

/// §4 Space, shape, elevation.
abstract final class LevelsSpace {
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space48 = 48.0;
  static const space64 = 64.0;

  /// Screen gutter.
  static const screenGutter = space24;

  /// Content max-width on web — a column of focus, not a full-bleed
  /// dashboard.
  static const contentMaxWidth = 560.0;

  /// Panel corner radius.
  static const radiusPanel = 16.0;

  /// Pill (button) corner radius.
  static const radiusButton = 999.0;

  /// Reveal-panel fade+rise distance (§5 `reveal`).
  static const revealRise = 12.0;
}

/// §5 Motion — slow, settled, deterministic.
///
/// Rules (enforced at call sites, not encodable as constants): motion never
/// blocks input; nothing loops except `breath`; the CoG number never counts
/// up, spins, or shimmers into place (MASTER.md §5, §8 anti-pattern #6).
abstract final class LevelsMotion {
  /// Panel content fade+rise on reveal.
  static const reveal = Duration(milliseconds: 600);
  static const revealCurve = Curves.easeOutCubic;

  /// Route transitions, fade-through.
  static const page = Duration(milliseconds: 350);
  static const pageCurve = Curves.easeOutCubic;

  /// CoG glow idle pulse — one element per screen max.
  static const breath = Duration(milliseconds: 2400);
  static const breathCurve = Curves.easeInOut;

  /// ±6% glow alpha swing during `breath`.
  static const breathAlphaSwing = 0.06;

  /// Button/tap feedback.
  static const press = Duration(milliseconds: 120);
}
