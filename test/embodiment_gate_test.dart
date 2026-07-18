import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/track/embodiment_gate.dart';

/// Pins PRD M4.5's three named gating scenarios: same-day re-entry shows
/// today's completed log, the next calendar day unlocks the next
/// day_number, and skipped days never allow backfill.
void main() {
  final start = DateTime(2026, 7, 1, 9); // local, 9am day 1

  group('embodimentDayGate — day 1 (the start day)', () {
    test('is open before anything is logged', () {
      final gate = embodimentDayGate(
        startedAt: start,
        now: DateTime(2026, 7, 1, 20), // later same day
        completedDayNumbers: {},
      );
      expect(gate.status, EmbodimentDayStatus.open);
      expect(gate.dayNumber, 1);
    });

    test('same-day re-entry shows today\'s completed log', () {
      final gate = embodimentDayGate(
        startedAt: start,
        now: DateTime(2026, 7, 1, 22), // still day 1, later
        completedDayNumbers: {1},
      );
      expect(gate.status, EmbodimentDayStatus.alreadyLoggedToday);
      expect(gate.dayNumber, 1);
    });
  });

  group('embodimentDayGate — next calendar day', () {
    test('unlocks day 2 once day 1 is done', () {
      final gate = embodimentDayGate(
        startedAt: start,
        now: DateTime(2026, 7, 2, 7), // next calendar day, early morning
        completedDayNumbers: {1},
      );
      expect(gate.status, EmbodimentDayStatus.open);
      expect(gate.dayNumber, 2);
    });

    test('unlocks day 2 even if day 1 was never logged (no forced catch-up '
        'before it opens)', () {
      final gate = embodimentDayGate(
        startedAt: start,
        now: DateTime(2026, 7, 2, 7),
        completedDayNumbers: {},
      );
      expect(gate.status, EmbodimentDayStatus.open);
      expect(gate.dayNumber, 2);
    });
  });

  group('embodimentDayGate — skipped days never allow backfill', () {
    test('day 2 and 3 skipped: day 4 opens, not day 2 or 3', () {
      final gate = embodimentDayGate(
        startedAt: start,
        now: DateTime(2026, 7, 4, 10), // 3 calendar days later -> day 4
        completedDayNumbers: {1}, // only day 1 was ever logged
      );
      expect(gate.status, EmbodimentDayStatus.open);
      expect(gate.dayNumber, 4);
      expect(gate.dayNumber, isNot(anyOf(2, 3)));
    });

    test('a completed day 4 does not retroactively open days 2-3', () {
      final gate = embodimentDayGate(
        startedAt: start,
        now: DateTime(2026, 7, 4, 10),
        completedDayNumbers: {1, 4},
      );
      expect(gate.status, EmbodimentDayStatus.alreadyLoggedToday);
      expect(gate.dayNumber, 4);
    });
  });

  group('embodimentDayGate — window boundaries', () {
    test('day 7 is the last open day', () {
      final gate = embodimentDayGate(
        startedAt: start,
        now: DateTime(2026, 7, 7, 12),
        completedDayNumbers: {1, 2, 3, 4, 5, 6},
      );
      expect(gate.status, EmbodimentDayStatus.open);
      expect(gate.dayNumber, 7);
    });

    test('past day 7, the window has elapsed with no day_number to open',
        () {
      final gate = embodimentDayGate(
        startedAt: start,
        now: DateTime(2026, 7, 8, 9),
        completedDayNumbers: {1, 2, 3, 4, 5, 6, 7},
      );
      expect(gate.status, EmbodimentDayStatus.windowElapsed);
      expect(gate.dayNumber, isNull);
    });

    test('window elapsed even if day 7 was never logged (no late finish)',
        () {
      final gate = embodimentDayGate(
        startedAt: start,
        now: DateTime(2026, 7, 8, 9),
        completedDayNumbers: {1, 2, 3, 4, 5, 6},
      );
      expect(gate.status, EmbodimentDayStatus.windowElapsed);
      expect(gate.dayNumber, isNull);
    });
  });

  group('embodimentDayGate — local calendar date, not UTC (decided '
      '2026-07-17)', () {
    test('uses the local calendar date of a UTC-aware startedAt, not the '
        'UTC date', () {
      // Discriminating case for a machine west of UTC (this dev sandbox
      // runs UTC-5): pick a `startedAt` whose UTC date is one day ahead of
      // its own local date (03:00 UTC = 22:00 the previous day at UTC-5),
      // and a `now` on that same local day. Without `.toLocal()`, the gate
      // would compare against the UTC date (one day later than local),
      // making day 1 look already past -> windowElapsed. With it, day 1 is
      // correctly still open.
      final utcStart = DateTime.utc(2026, 7, 2, 3, 0);
      final localSameDay = DateTime(2026, 7, 1, 23, 0);
      final gate = embodimentDayGate(
        startedAt: utcStart,
        now: localSameDay,
        completedDayNumbers: {},
      );
      expect(gate.status, EmbodimentDayStatus.open);
      expect(gate.dayNumber, 1);
    });
  });
}
