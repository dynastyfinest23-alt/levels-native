import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/reassessment/reassessment_tokens.dart';
import 'package:levels_native/features/reassessment/routing.dart';

/// Pins PRD M5.4's routing contract: every `routing_outcome` reaches a real
/// destination, the 48-hour retest gate boundary, and the hub's follow-up
/// CTA for each outcome. Pure functions — no Supabase involved.
void main() {
  group('destinationFor — all four outcomes lead somewhere real', () {
    test('new_loop -> new assessment', () {
      expect(
        destinationFor(RoutingOutcome.newLoop),
        ReassessmentDestination.newLoopAssessment,
      );
    });

    test('deepening_protocol -> drill one layer deeper', () {
      expect(
        destinationFor(RoutingOutcome.deepeningProtocol),
        ReassessmentDestination.deepeningDrill,
      );
    });

    test('track_reassignment -> fresh drill', () {
      expect(
        destinationFor(RoutingOutcome.trackReassignment),
        ReassessmentDestination.freshDrill,
      );
    });

    test('retest_scheduled -> retest gate', () {
      expect(
        destinationFor(RoutingOutcome.retestScheduled),
        ReassessmentDestination.retestGate,
      );
    });

    test('the mapping covers every RoutingOutcome exactly once', () {
      // Pins exhaustiveness against a future enum addition: this loop must
      // run for exactly the four known outcomes.
      expect(RoutingOutcome.values, hasLength(4));
      for (final outcome in RoutingOutcome.values) {
        expect(() => destinationFor(outcome), returnsNormally);
      }
    });
  });

  group('routeForDestination', () {
    test('each destination resolves to its route', () {
      expect(
        routeForDestination(ReassessmentDestination.newLoopAssessment, 'l1'),
        '/assessment',
      );
      expect(
        routeForDestination(ReassessmentDestination.deepeningDrill, 'l1'),
        '/drill/l1?deepen=1',
      );
      expect(
        routeForDestination(ReassessmentDestination.freshDrill, 'l1'),
        '/drill/l1',
      );
      expect(
        routeForDestination(ReassessmentDestination.retestGate, 'l1'),
        '/reassessment/l1/window_2',
      );
    });

    test('a retestGate result CTA goes home instead of back into the flow',
        () {
      final cta = resultCtaFor(RoutingOutcome.retestScheduled);
      expect(routeForResultCta(cta, 'l1'), '/');
    });
  });

  group('retestGateOpen — the 48-hour boundary', () {
    final reassessedAt = DateTime.utc(2026, 7, 19, 12);

    test('closed one minute before 48 hours', () {
      expect(
        retestGateOpen(
          reassessedAt: reassessedAt,
          now: reassessedAt.add(const Duration(hours: 47, minutes: 59)),
        ),
        isFalse,
      );
    });

    test('open at exactly 48 hours', () {
      expect(
        retestGateOpen(
          reassessedAt: reassessedAt,
          now: reassessedAt.add(const Duration(hours: 48)),
        ),
        isTrue,
      );
    });

    test('open well past 48 hours (the retest is not re-windowed)', () {
      expect(
        retestGateOpen(
          reassessedAt: reassessedAt,
          now: reassessedAt.add(const Duration(days: 30)),
        ),
        isTrue,
      );
    });
  });

  group('hubFollowUpFor — the hub reflects each outcome', () {
    test('new_loop offers a new assessment', () {
      final followUp =
          hubFollowUpFor(RoutingOutcome.newLoop, retestOpen: false);
      expect(followUp.destination, ReassessmentDestination.newLoopAssessment);
      expect(followUp.enabled, isTrue);
      expect(followUp.label, 'Start a new loop');
    });

    test('deepening_protocol offers the deeper drill', () {
      final followUp =
          hubFollowUpFor(RoutingOutcome.deepeningProtocol, retestOpen: false);
      expect(followUp.destination, ReassessmentDestination.deepeningDrill);
      expect(followUp.enabled, isTrue);
    });

    test('track_reassignment offers a fresh drill', () {
      final followUp = hubFollowUpFor(RoutingOutcome.trackReassignment,
          retestOpen: false);
      expect(followUp.destination, ReassessmentDestination.freshDrill);
      expect(followUp.enabled, isTrue);
    });

    test('retest_scheduled disables the CTA while the gate is closed',
        () {
      final followUp =
          hubFollowUpFor(RoutingOutcome.retestScheduled, retestOpen: false);
      expect(followUp.destination, ReassessmentDestination.retestGate);
      expect(followUp.enabled, isFalse);
    });

    test('retest_scheduled re-enables the CTA once the gate lifts', () {
      final followUp =
          hubFollowUpFor(RoutingOutcome.retestScheduled, retestOpen: true);
      expect(followUp.enabled, isTrue);
      expect(followUp.label, 'Take your check-in');
    });
  });
}
