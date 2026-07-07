/// Typed parser for the Phase 2 four-part reveal copy.
///
/// Canonical schema (must stay in sync with
/// `supabase/functions/generate-dashboard-copy/fallback.ts` — the TS and
/// Dart sides share no runtime, so drift is only caught by keeping both
/// against this list):
///   reality_tunnel, hidden_benefit, illusion, bridge_question
///
/// This is presentation copy only. The score and zone shown on the dashboard
/// are always read from the authoritative `phase1_assessments` row — if copy
/// and number ever disagree, the number wins.
library;

class DashboardCopy {
  const DashboardCopy({
    required this.realityTunnel,
    required this.hiddenBenefit,
    required this.illusion,
    required this.bridgeQuestion,
  });

  /// Parses the `generated_copy` JSONB payload. Throws [FormatException] on
  /// any missing or empty field — errors must surface, never render a blank
  /// reveal panel.
  factory DashboardCopy.fromJson(Map<String, dynamic> json) {
    String field(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException(
          'generated_copy is missing required field "$key"',
          json,
        );
      }
      return value;
    }

    return DashboardCopy(
      realityTunnel: field('reality_tunnel'),
      hiddenBenefit: field('hidden_benefit'),
      illusion: field('illusion'),
      bridgeQuestion: field('bridge_question'),
    );
  }

  final String realityTunnel;
  final String hiddenBenefit;
  final String illusion;
  final String bridgeQuestion;
}
