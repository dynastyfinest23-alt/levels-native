import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/core/zone_style.dart';
import 'package:levels_native/features/assessment/scoring.dart';

/// Pins `ZoneStyle.of` to the exact six-zone spectrum table in
/// design-system/MASTER.md §2. This is a golden-mirror test in the same
/// spirit as `test/scoring_mirror_test.dart`: it must fail the moment any
/// mapping in `lib/core/zone_style.dart` drifts from MASTER.md, since that
/// file is the source of truth for the zone→color system.
void main() {
  group('ZoneStyle.of pins MASTER.md §2', () {
    const expected = {
      EnergyZone.collapsed: (
        displayName: 'Collapsed',
        zoneColor: Color(0xFF4E5578),
        zoneGlow: Color(0x334E5578),
      ),
      EnergyZone.contracted: (
        displayName: 'Contracted',
        zoneColor: Color(0xFF5F6FC0),
        zoneGlow: Color(0x3D5F6FC0),
      ),
      EnergyZone.reactive: (
        displayName: 'Reactive',
        zoneColor: Color(0xFF7D6DD8),
        zoneGlow: Color(0x477D6DD8),
      ),
      EnergyZone.threshold: (
        displayName: 'Threshold',
        zoneColor: Color(0xFFA96FD6),
        zoneGlow: Color(0x52A96FD6),
      ),
      EnergyZone.builder: (
        displayName: 'Builder',
        zoneColor: Color(0xFFDB7E93),
        zoneGlow: Color(0x5CDB7E93),
      ),
      EnergyZone.flow: (
        displayName: 'Flow',
        zoneColor: Color(0xFFF5C066),
        zoneGlow: Color(0x70F5C066),
      ),
    };

    test('covers every EnergyZone exactly once', () {
      expect(expected.keys.toSet(), EnergyZone.values.toSet());
    });

    for (final entry in expected.entries) {
      test('${entry.key.token} -> ${entry.value.displayName}', () {
        final style = ZoneStyle.of(entry.key);
        expect(style.displayName, entry.value.displayName);
        expect(style.zoneColor, entry.value.zoneColor);
        expect(style.zoneGlow, entry.value.zoneGlow);
      });
    }

    test('display names are never the raw enum token (MASTER.md §2 rule)',
        () {
      for (final zone in EnergyZone.values) {
        expect(ZoneStyle.of(zone).displayName, isNot(equals(zone.token)));
      }
    });
  });
}
