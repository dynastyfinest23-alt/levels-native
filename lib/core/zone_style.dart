/// The six-zone spectrum (design-system/MASTER.md §2) — the only
/// zone→color mapping. Resolves an [EnergyZone] to its UI display name,
/// `zoneColor`, and `zoneGlow`.
///
/// House rule (MASTER.md §2): UI text uses the display name, never the raw
/// enum token ("builder" in the UI is a bug) — always go through
/// `ZoneStyle.of(zone).displayName`.
library;

import 'package:flutter/material.dart';

import '../features/assessment/scoring.dart';

/// Display name + color treatment for one [EnergyZone], per MASTER.md §2.
class ZoneStyle {
  const ZoneStyle._({
    required this.displayName,
    required this.zoneColor,
    required this.zoneGlow,
  });

  /// UI text for this zone. Never show the raw enum token instead.
  final String displayName;

  /// CoG numeral, zone name, primary CTA fill, glow halos, progress
  /// accents. NOT for body text or backgrounds (MASTER.md §2).
  final Color zoneColor;

  /// Large soft glow behind the CoG numeral / primary CTA. Blur radius
  /// ≥ 48px, no hard edges — enforced at the call site, not here.
  final Color zoneGlow;

  /// Resolves the display name + colors for [zone]. Throws if a zone is
  /// ever added to [EnergyZone] without a corresponding entry here — the
  /// system must never silently fall back to a default treatment.
  static ZoneStyle of(EnergyZone zone) {
    switch (zone) {
      case EnergyZone.collapsed:
        return const ZoneStyle._(
          displayName: 'Collapsed',
          zoneColor: Color(0xFF4E5578),
          zoneGlow: Color(0x334E5578),
        );
      case EnergyZone.contracted:
        return const ZoneStyle._(
          displayName: 'Contracted',
          zoneColor: Color(0xFF5F6FC0),
          zoneGlow: Color(0x3D5F6FC0),
        );
      case EnergyZone.reactive:
        return const ZoneStyle._(
          displayName: 'Reactive',
          zoneColor: Color(0xFF7D6DD8),
          zoneGlow: Color(0x477D6DD8),
        );
      case EnergyZone.threshold:
        return const ZoneStyle._(
          displayName: 'Threshold',
          zoneColor: Color(0xFFA96FD6),
          zoneGlow: Color(0x52A96FD6),
        );
      case EnergyZone.builder:
        return const ZoneStyle._(
          displayName: 'Builder',
          zoneColor: Color(0xFFDB7E93),
          zoneGlow: Color(0x5CDB7E93),
        );
      case EnergyZone.flow:
        return const ZoneStyle._(
          displayName: 'Flow',
          zoneColor: Color(0xFFF5C066),
          zoneGlow: Color(0x70F5C066),
        );
      // ignore: unreachable_switch_default
      default:
        // EnergyZone has exactly six values today, so the analyzer already
        // rejects a missing case above at compile time. This default is
        // belt-and-suspenders (mirrors EnergyZone.fromToken's runtime
        // throw) so a future zone added without a mapping here fails loudly
        // instead of falling through to an undefined treatment.
        throw ArgumentError.value(zone, 'zone', 'unknown EnergyZone');
    }
  }
}
