/// Client-side mirrors of the deployed Postgres scoring functions.
///
/// These exist ONLY for instant provisional previews. The database result
/// (`compute_center_of_gravity`) is always authoritative. Every constant and
/// boundary here must remain an exact arithmetic mirror of the DEPLOYED
/// function bodies — those are the source of truth. The CLAUDE.md tables
/// match them (re-verified against production 2026-07-03). Drift is caught
/// by `test/scoring_mirror_test.dart`.
library;

/// Mirror of the `p1_answer` enum, v1.1 calibration tokens only.
///
/// The DB enum also still carries the stale v1.0 tokens
/// (`courage_neutrality`, `willingness_acceptance`, `reason`) because
/// Postgres enums cannot drop values; the client never sends them.
enum P1Answer {
  shameApathy('shame_apathy', 30),
  apathyGrief('apathy_grief', 65),
  fear('fear', 100),
  desire('desire', 125),
  anger('anger', 160),
  pride('pride', 190),
  contentment('contentment', 200),
  courage('courage', 275),
  willingness('willingness', 320),
  neutrality('neutrality', 400),
  loveFlow('love_flow', 530);

  const P1Answer(this.token, this.rawScore);

  /// Wire value sent to Postgres.
  final String token;

  /// Mirror of `answer_to_raw_score`.
  final int rawScore;
}

/// Mirror of the `energy_zone` enum.
enum EnergyZone {
  collapsed('collapsed'),
  contracted('contracted'),
  reactive('reactive'),
  threshold('threshold'),
  builder('builder'),
  flow('flow');

  const EnergyZone(this.token);

  final String token;

  static EnergyZone fromToken(String token) => values.firstWhere(
        (zone) => zone.token == token,
        orElse: () =>
            throw ArgumentError.value(token, 'token', 'unknown energy_zone'),
      );
}

/// Mirror of `apply_downward_anchor_weight`: raw scores below 200 are
/// multiplied by 1.5; scores at or above 200 pass through unchanged.
double applyDownwardAnchorWeight(int rawScore) =>
    rawScore < 200 ? rawScore * 1.5 : rawScore.toDouble();

/// Mirror of `score_to_zone` (deployed boundaries).
EnergyZone scoreToZone(num score) {
  if (score < 90) return EnergyZone.collapsed;
  if (score < 140) return EnergyZone.contracted;
  if (score < 200) return EnergyZone.reactive;
  if (score < 300) return EnergyZone.threshold;
  if (score < 500) return EnergyZone.builder;
  return EnergyZone.flow;
}

/// Mirror of the DB's `LEAST(v_cog, 499.99)` clamp: single assessments cap
/// below Flow (500). Flow zones are only reachable via accumulated verified
/// loops per the Flow reachability formula. Calibrated love_flow=530 would
/// otherwise allow an all-love_flow assessment to score into Flow directly.
const double singleAssessmentCogCap = 499.99;

/// Unrounded, unclamped weighted average — the DB's `v_cog` right after the
/// AVG and before the clamp. Shared by [computeCogPreview] and
/// [cogPreviewWasClamped] so both read the same pre-clamp value.
double _unclampedCog(List<P1Answer> answers) {
  if (answers.length != 7) {
    throw ArgumentError.value(
      answers.length,
      'answers',
      'exactly 7 answers are required',
    );
  }
  final weightedSum = answers.fold<double>(
    0,
    (total, answer) => total + applyDownwardAnchorWeight(answer.rawScore),
  );
  return weightedSum / 7;
}

/// Provisional Center of Gravity: weighted average of all 7 answers, clamped
/// to [singleAssessmentCogCap] and rounded to 2 decimals, in the same order
/// as the DB (`LEAST` before `ROUND(v_cog, 2)`).
double computeCogPreview(List<P1Answer> answers) {
  final cog = _unclampedCog(answers);
  final clamped = cog > singleAssessmentCogCap ? singleAssessmentCogCap : cog;
  return (clamped * 100).round() / 100;
}

/// Mirror of the DB's `v_was_clamped := (v_cog > 499.99)`, captured against
/// the pre-clamp average. Stored server-side in
/// `phase1_assessments.was_clamped`; the DB row is authoritative.
bool cogPreviewWasClamped(List<P1Answer> answers) =>
    _unclampedCog(answers) > singleAssessmentCogCap;
