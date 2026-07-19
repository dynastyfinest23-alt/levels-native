/// Pure routing for the four Phase 5 `routing_outcome` destinations (PRD
/// M5.4). No Supabase imports — the outcome -> destination mapping and the
/// 48-hour retest gate are pinned by test/routing_test.dart without a
/// client.
///
/// The mapping is total and compiler-checked: adding a [RoutingOutcome]
/// without a destination breaks the build, and the copy lives here so the
/// hub and the reassessment result screen can never drift apart.
library;

import 'reassessment_tokens.dart';

/// Where a routing outcome sends the user next.
enum ReassessmentDestination {
  /// `new_loop` — loop is complete; begin a fresh assessment.
  newLoopAssessment,

  /// `deepening_protocol` — re-enter the drill one layer deeper.
  deepeningDrill,

  /// `track_reassignment` — re-enter the drill fresh (layer 1).
  freshDrill,

  /// `retest_scheduled` — wait out the 48-hour gate, then retest.
  retestGate,
}

/// The one mapping from DB routing outcome to destination. Exhaustive by
/// construction — a new outcome without a destination is a compile error,
/// never a silent default.
ReassessmentDestination destinationFor(RoutingOutcome outcome) =>
    switch (outcome) {
      RoutingOutcome.newLoop => ReassessmentDestination.newLoopAssessment,
      RoutingOutcome.deepeningProtocol =>
        ReassessmentDestination.deepeningDrill,
      RoutingOutcome.trackReassignment =>
        ReassessmentDestination.freshDrill,
      RoutingOutcome.retestScheduled => ReassessmentDestination.retestGate,
    };

/// The wait between a `retest_scheduled` reassessment and its retest
/// (CLAUDE.md classification rules: "Delta <= 0 with movement flag ->
/// false_positive -> retest in 48h").
const retestWait = Duration(hours: 48);

/// Pure 48-hour gate: the retest opens at `reassessedAt + 48h`, inclusive.
bool retestGateOpen({required DateTime reassessedAt, required DateTime now}) =>
    !now.isBefore(reassessedAt.add(retestWait));

/// The route for a destination. Centralized so the hub CTA and the result
/// screen CTA can never disagree about where an outcome leads.
String routeForDestination(ReassessmentDestination destination, String loopId) =>
    switch (destination) {
      ReassessmentDestination.newLoopAssessment => '/assessment',
      ReassessmentDestination.deepeningDrill => '/drill/$loopId?deepen=1',
      ReassessmentDestination.freshDrill => '/drill/$loopId',
      ReassessmentDestination.retestGate => '/reassessment/$loopId/window_2',
    };

/// What the hub's primary CTA says and whether it is tappable, after a
/// Window 2 reassessment has been routed. `label` is functional chrome copy
/// — mechanic-free, no urgency, no countdown (MASTER.md §8 anti-pattern 7:
/// the disabled retest state is quiet text, not a timer).
class HubFollowUp {
  const HubFollowUp({
    required this.label,
    required this.destination,
    required this.enabled,
  });

  final String label;
  final ReassessmentDestination destination;

  /// False only for the retest wait: the CTA renders disabled until
  /// [retestGateOpen] flips.
  final bool enabled;
}

/// Hub CTA for a routed Window 2 outcome. [retestOpen] is the caller's
/// [retestGateOpen] result, so this stays pure and clock-free.
HubFollowUp hubFollowUpFor(
  RoutingOutcome outcome, {
  required bool retestOpen,
}) {
  final destination = destinationFor(outcome);
  return switch (destination) {
    ReassessmentDestination.newLoopAssessment => HubFollowUp(
        label: 'Start a new loop',
        destination: destination,
        enabled: true,
      ),
    ReassessmentDestination.deepeningDrill => HubFollowUp(
        label: 'Continue your practice',
        destination: destination,
        enabled: true,
      ),
    ReassessmentDestination.freshDrill => HubFollowUp(
        label: 'Start a fresh drill',
        destination: destination,
        enabled: true,
      ),
    ReassessmentDestination.retestGate => retestOpen
        ? HubFollowUp(
            label: 'Take your check-in',
            destination: destination,
            enabled: true,
          )
        : HubFollowUp(
            label: 'Your check-in opens soon',
            destination: destination,
            enabled: false,
          ),
  };
}

/// The result screen's CTA after a reassessment (or rediag) completes.
/// Unlike the hub, a just-finished retest-scheduled user goes home — the
/// hub carries the waiting state from then on.
class ResultCta {
  const ResultCta({required this.label, required this.destination});

  final String label;
  final ReassessmentDestination destination;
}

/// Result-screen CTA for a routing outcome. Exhaustive, same guarantee as
/// [destinationFor].
ResultCta resultCtaFor(RoutingOutcome outcome) {
  final destination = destinationFor(outcome);
  return switch (destination) {
    ReassessmentDestination.newLoopAssessment =>
      ResultCta(label: 'Start a new loop', destination: destination),
    ReassessmentDestination.deepeningDrill =>
      ResultCta(label: 'Continue your practice', destination: destination),
    ReassessmentDestination.freshDrill =>
      ResultCta(label: 'Start a fresh drill', destination: destination),
    ReassessmentDestination.retestGate =>
      ResultCta(label: 'Back to home', destination: destination),
  };
}

/// The route a result-screen CTA navigates to. Identical to
/// [routeForDestination] except `retestGate`: a user who just finished the
/// check-in goes home, and the hub carries the 48-hour waiting state (the
/// gated CTA) from then on.
String routeForResultCta(ResultCta cta, String loopId) =>
    cta.destination == ReassessmentDestination.retestGate
        ? '/'
        : routeForDestination(cta.destination, loopId);
