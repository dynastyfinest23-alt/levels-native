import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/drill/drill_tokens.dart';

/// Pins the Phase 3 enum mirrors in `lib/features/drill/drill_tokens.dart` to
/// the wire tokens and counts verified against production 2026-07-08
/// (`docs/PRD.md` §2: Enum tokens the client must mirror). Must fail the
/// moment a token, count, or the fromToken guard drifts from that list.
void main() {
  group('OriginType mirrors origin_type (12)', () {
    const expectedTokens = [
      'childhood_conditioning',
      'acute_trauma',
      'inherited_belief',
      'identity_fusion',
      'conditional_approval',
      'humiliation_imprint',
      'modeled_identity',
      'betrayal_wound',
      'preparation_loop',
      'past_failure_imprint',
      'optionality_preservation',
      'worthiness_gap',
    ];

    test('has exactly 12 values', () {
      expect(OriginType.values, hasLength(12));
    });

    test('tokens match production exactly, in order', () {
      expect(OriginType.values.map((v) => v.token).toList(), expectedTokens);
    });

    for (final token in expectedTokens) {
      test('fromToken round-trips "$token"', () {
        expect(OriginType.fromToken(token).token, token);
      });
    }

    test('fromToken throws on unknown token', () {
      expect(() => OriginType.fromToken('reason'), throwsArgumentError);
    });
  });

  group('OriginDomain mirrors origin_domain (12)', () {
    const expectedTokens = [
      'relational_attachment',
      'adequacy_impostor',
      'existential_catastrophic',
      'autonomy_sovereignty',
      'status_achievement',
      'relational_reciprocity',
      'ideological_systemic',
      'internal_self_directed',
      'internalized_authority',
      'societal_comparative',
      'self_perfectionism',
      'visibility_fear',
    ];

    test('has exactly 12 values', () {
      expect(OriginDomain.values, hasLength(12));
    });

    test('tokens match production exactly, in order', () {
      expect(OriginDomain.values.map((v) => v.token).toList(), expectedTokens);
    });

    for (final token in expectedTokens) {
      test('fromToken round-trips "$token"', () {
        expect(OriginDomain.fromToken(token).token, token);
      });
    }

    test('fromToken throws on unknown token', () {
      expect(() => OriginDomain.fromToken('courage_neutrality'),
          throwsArgumentError);
    });
  });

  group('CopingMechanism mirrors coping_mechanism (12)', () {
    const expectedTokens = [
      'distraction_avoidance',
      'external_regulation',
      'collapse_shutdown',
      'cognitive_override',
      'justice_confusion',
      'control_dependency',
      'appointed_guardian',
      'sunk_cost_identity',
      'preserved_potential',
      'comfort_preservation',
      'responsibility_avoidance',
      'identity_continuity',
    ];

    test('has exactly 12 values', () {
      expect(CopingMechanism.values, hasLength(12));
    });

    test('tokens match production exactly, in order', () {
      expect(
          CopingMechanism.values.map((v) => v.token).toList(), expectedTokens);
    });

    for (final token in expectedTokens) {
      test('fromToken round-trips "$token"', () {
        expect(CopingMechanism.fromToken(token).token, token);
      });
    }

    test('fromToken throws on unknown token', () {
      expect(() => CopingMechanism.fromToken('willingness_acceptance'),
          throwsArgumentError);
    });
  });

  group('AscensionTrack mirrors ascension_track (4)', () {
    const expectedTokens = [
      'completion',
      'belief_audit',
      'embodiment',
      'commitment',
    ];

    test('has exactly 4 values', () {
      expect(AscensionTrack.values, hasLength(4));
    });

    test('tokens match production exactly, in order', () {
      expect(
          AscensionTrack.values.map((v) => v.token).toList(), expectedTokens);
    });

    for (final token in expectedTokens) {
      test('fromToken round-trips "$token"', () {
        expect(AscensionTrack.fromToken(token).token, token);
      });
    }

    test('fromToken throws on unknown token', () {
      expect(() => AscensionTrack.fromToken('unknown_track'),
          throwsArgumentError);
    });
  });
}
