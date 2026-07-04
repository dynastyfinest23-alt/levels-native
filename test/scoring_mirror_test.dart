import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/assessment/scoring.dart';

/// Golden-mirror suite: asserts the Dart preview functions produce the exact
/// outputs of the deployed Postgres functions, so client/DB drift is caught
/// in CI. Two sources of truth are pinned here:
///
/// 1. The CLAUDE.md golden set (score_to_zone / apply_downward_anchor_weight
///    spot values and classification-adjacent scoring checks).
/// 2. The full deployed `answer_to_raw_score` mapping and `score_to_zone`
///    boundaries, read back from production via
///    `SELECT pg_get_functiondef(...)` on 2026-07-03.
void main() {
  group('answer_to_raw_score mirror (deployed mapping)', () {
    const expected = {
      P1Answer.shameApathy: 30,
      P1Answer.apathyGrief: 65,
      P1Answer.fear: 100,
      P1Answer.desire: 120,
      P1Answer.anger: 160,
      P1Answer.pride: 190,
      P1Answer.contentment: 200,
      P1Answer.courage: 275,
      P1Answer.willingness: 320,
      P1Answer.neutrality: 400,
      P1Answer.loveFlow: 530,
    };

    test('covers every token exactly once', () {
      expect(expected.keys.toSet(), P1Answer.values.toSet());
    });

    for (final entry in expected.entries) {
      test('${entry.key.token} -> ${entry.value}', () {
        expect(entry.key.rawScore, entry.value);
      });
    }
  });

  group('apply_downward_anchor_weight mirror', () {
    test('CLAUDE.md golden set', () {
      expect(applyDownwardAnchorWeight(100), 150.00);
      expect(applyDownwardAnchorWeight(225), 225.00);
    });

    test('boundary at 200: 199 is weighted, 200 passes through', () {
      expect(applyDownwardAnchorWeight(199), 298.5);
      expect(applyDownwardAnchorWeight(200), 200.0);
    });
  });

  group('score_to_zone mirror', () {
    test('CLAUDE.md golden set', () {
      expect(scoreToZone(60), EnergyZone.collapsed);
      expect(scoreToZone(110), EnergyZone.contracted);
      expect(scoreToZone(165), EnergyZone.reactive);
      expect(scoreToZone(230), EnergyZone.threshold);
      expect(scoreToZone(380), EnergyZone.builder);
      expect(scoreToZone(520), EnergyZone.flow);
    });

    test('deployed boundaries (exclusive upper bounds)', () {
      expect(scoreToZone(89.99), EnergyZone.collapsed);
      expect(scoreToZone(90), EnergyZone.contracted);
      expect(scoreToZone(139.99), EnergyZone.contracted);
      expect(scoreToZone(140), EnergyZone.reactive);
      expect(scoreToZone(199.99), EnergyZone.reactive);
      expect(scoreToZone(200), EnergyZone.threshold);
      expect(scoreToZone(299.99), EnergyZone.threshold);
      expect(scoreToZone(300), EnergyZone.builder);
      expect(scoreToZone(499.99), EnergyZone.builder);
      expect(scoreToZone(500), EnergyZone.flow);
    });
  });

  group('computeCogPreview mirror', () {
    test('uniform answers: 7x fear -> weighted 150 each -> CoG 150.00', () {
      final answers = List.filled(7, P1Answer.fear);
      expect(computeCogPreview(answers), 150.00);
      expect(scoreToZone(computeCogPreview(answers)), EnergyZone.reactive);
    });

    test('mixed answers round like ROUND(numeric, 2)', () {
      // Weighted: 30*1.5=45, 100*1.5=150, 160*1.5=240, 190*1.5=285,
      // 200, 320, 530 -> sum 1770 / 7 = 252.857142... -> 252.86
      final answers = [
        P1Answer.shameApathy,
        P1Answer.fear,
        P1Answer.anger,
        P1Answer.pride,
        P1Answer.contentment,
        P1Answer.willingness,
        P1Answer.loveFlow,
      ];
      expect(computeCogPreview(answers), 252.86);
      expect(scoreToZone(computeCogPreview(answers)), EnergyZone.threshold);
    });

    test('rejects incomplete assessments like the DB guard', () {
      expect(
        () => computeCogPreview([P1Answer.fear]),
        throwsArgumentError,
      );
    });
  });

  group('EnergyZone.fromToken', () {
    test('round-trips every zone token', () {
      for (final zone in EnergyZone.values) {
        expect(EnergyZone.fromToken(zone.token), zone);
      }
    });

    test('throws on unknown token instead of silently defaulting', () {
      expect(() => EnergyZone.fromToken('ascended'), throwsArgumentError);
    });
  });
}
