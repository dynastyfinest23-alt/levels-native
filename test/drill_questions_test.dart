import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/drill/drill_questions.dart';
import 'package:levels_native/features/drill/drill_tokens.dart';

/// Structural coverage checks only — not a tone judgment. Content approval
/// is a review-gate task (PRD M3.2), not a pinned-contract test; this file
/// only guards against a genuinely mechanical bug: a missing or duplicated
/// token mapping, which would silently make an origin/domain/mechanism
/// unreachable from the drill UI.
void main() {
  test('originTypeOptions covers every OriginType exactly once', () {
    expect(originTypeOptions, hasLength(12));
    expect(
      originTypeOptions.map((o) => o.type).toSet(),
      OriginType.values.toSet(),
    );
  });

  test('originDomainOptions covers every OriginDomain exactly once', () {
    expect(originDomainOptions, hasLength(12));
    expect(
      originDomainOptions.map((o) => o.domain).toSet(),
      OriginDomain.values.toSet(),
    );
  });

  test('copingMechanismOptions covers every CopingMechanism exactly once',
      () {
    expect(copingMechanismOptions, hasLength(12));
    expect(
      copingMechanismOptions.map((o) => o.mechanism).toSet(),
      CopingMechanism.values.toSet(),
    );
  });
}
