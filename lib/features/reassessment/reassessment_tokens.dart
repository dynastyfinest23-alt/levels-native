/// Wire-token mirrors for the Phase 5 reassessment enums, plus the display
/// copy lookups every user-facing surface must go through.
///
/// Token sets verified against production 2026-07-19 via `pg_enum` (M5.1).
/// House rule (CLAUDE.md mechanic-leak class 1): raw tokens never reach the
/// UI — classification and routing values render through the typed lookups
/// at the bottom of this file, which throw on unknown values rather than
/// silently defaulting (the `ZoneStyle.of` pattern).
library;

/// Mirror of the `reassessment_window` enum, restricted to the two windows
/// this build uses. `window_1` exists in the DB enum but is unused and must
/// never be written (PRD §2), so it is deliberately absent here — parsing it
/// throws.
enum ReassessmentWindow {
  window2('window_2'),
  window3('window_3');

  const ReassessmentWindow(this.token);

  /// Wire value sent to Postgres.
  final String token;

  static ReassessmentWindow fromToken(String token) => values.firstWhere(
        (v) => v.token == token,
        orElse: () => throw ArgumentError.value(
          token,
          'token',
          'unknown reassessment_window',
        ),
      );

  /// Null-returning variant for route parsing, where an unknown token means
  /// "not a valid route" rather than a data error.
  static ReassessmentWindow? tryFromToken(String token) {
    for (final v in values) {
      if (v.token == token) return v;
    }
    return null;
  }
}

/// Mirror of the `phase5_classification` enum — verified against production
/// 2026-07-19 via `pg_enum`.
enum Phase5Classification {
  trueAscension('true_ascension'),
  residualCharge('residual_charge'),
  falsePositive('false_positive');

  const Phase5Classification(this.token);
  final String token;

  static Phase5Classification fromToken(String token) => values.firstWhere(
        (v) => v.token == token,
        orElse: () => throw ArgumentError.value(
          token,
          'token',
          'unknown phase5_classification',
        ),
      );
}

/// Mirror of the `routing_outcome` enum — verified against production
/// 2026-07-19 via `pg_enum`.
enum RoutingOutcome {
  newLoop('new_loop'),
  deepeningProtocol('deepening_protocol'),
  retestScheduled('retest_scheduled'),
  trackReassignment('track_reassignment');

  const RoutingOutcome(this.token);
  final String token;

  static RoutingOutcome fromToken(String token) => values.firstWhere(
        (v) => v.token == token,
        orElse: () => throw ArgumentError.value(
          token,
          'token',
          'unknown routing_outcome',
        ),
      );
}

/// Mirror of the `rediag_classification` enum — verified against production
/// 2026-07-19 via a read-only `supabase db dump --linked` of the live schema
/// (compliance_bypass, surface_contact, method_mismatch,
/// reclassify_residual, in that enum sort order).
///
/// What each value means, from the deployed `route_false_positive` body
/// (same dump): [reclassifyResidual] = behavior showed real movement
/// despite flat scores (same track, deeper); [methodMismatch] = skepticism
/// about the instrument (rotate the track format); [surfaceContact] =
/// specific resistance with relief/flatness (body-first work next);
/// [complianceBypass] = the default (the check-in did not make honest
/// contact).
enum RediagClassification {
  complianceBypass('compliance_bypass'),
  surfaceContact('surface_contact'),
  methodMismatch('method_mismatch'),
  reclassifyResidual('reclassify_residual');

  const RediagClassification(this.token);
  final String token;

  static RediagClassification fromToken(String token) => values.firstWhere(
        (v) => v.token == token,
        orElse: () => throw ArgumentError.value(
          token,
          'token',
          'unknown rediag_classification',
        ),
      );
}

/// Display copy for a [Phase5Classification]. The only path from the DB
/// value to user-facing text — never render the raw token.
class ClassificationCopy {
  const ClassificationCopy._({required this.headline, required this.body});

  final String headline;
  final String body;

  /// Functional result copy (same register as the hub's status text — warm,
  /// direct, no mechanics, no shaming, no urgency). Throws on an unknown
  /// classification rather than rendering a blank or a token.
  static ClassificationCopy of(Phase5Classification classification) {
    switch (classification) {
      case Phase5Classification.trueAscension:
        return const ClassificationCopy._(
          headline: 'The change held',
          body:
              'When the old situation showed up again, you met it '
              'differently. That is what real movement looks like, and it '
              'earns what comes next.',
        );
      case Phase5Classification.residualCharge:
        return const ClassificationCopy._(
          headline: 'Real movement, with something left',
          body:
              'Part of the old pattern is still charged. That is expected '
              'at this point in the climb, and the next step is shaped for '
              'exactly what remains.',
        );
      case Phase5Classification.falsePositive:
        return const ClassificationCopy._(
          headline: 'Worth a second look',
          body:
              'What you reported and what actually happened do not quite '
              'agree. A few more questions will help find where you truly '
              'stand.',
        );
      // ignore: unreachable_switch_default
      default:
        // Belt-and-suspenders alongside the compiler's exhaustiveness check
        // (mirrors ZoneStyle.of): a future classification added without copy
        // here must fail loudly, never render a token or a blank.
        throw ArgumentError.value(
          classification,
          'classification',
          'unknown Phase5Classification',
        );
    }
  }
}

/// Display copy for a [RediagClassification] — the post-rediag result.
/// Same rules as [ClassificationCopy]: the only path from the DB value to
/// user-facing text; never render the raw token, never name a track, never
/// shame the miss.
class RediagCopy {
  const RediagCopy._({required this.headline, required this.body});

  final String headline;
  final String body;

  /// Throws on an unknown classification rather than rendering a blank or
  /// a token.
  static RediagCopy of(RediagClassification classification) {
    switch (classification) {
      case RediagClassification.reclassifyResidual:
        return const RediagCopy._(
          headline: 'The change is real',
          body:
              'What you reported stayed flat, but your behavior did not. '
              'What you do in the moment counts more, and it says the work '
              'is landing. The next step goes deeper on the same path.',
        );
      case RediagClassification.methodMismatch:
        return const RediagCopy._(
          headline: 'The effort was real. The fit was not.',
          body:
              'Nothing is wrong with you or the work you put in. A '
              'different kind of practice will meet you better, and your '
              'next sessions are already pointed at it.',
        );
      case RediagClassification.surfaceContact:
        return const RediagCopy._(
          headline: 'You reached the edge of it',
          body:
              'Part of this sits deeper than thinking can reach. The next '
              'phase of work goes through the body instead.',
        );
      case RediagClassification.complianceBypass:
        return const RediagCopy._(
          headline: 'An honest miss',
          body:
              'These questions did not catch the real thing this time. '
              'That happens. The next round is built to make contact with '
              'it directly.',
        );
      // ignore: unreachable_switch_default
      default:
        throw ArgumentError.value(
          classification,
          'classification',
          'unknown RediagClassification',
        );
    }
  }
}
