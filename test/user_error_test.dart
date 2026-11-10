// Purpose: pins how failures reach the user (design review 2026-11-09, issue 27).
// Source of truth: lib/core/user_error.dart and CLAUDE.md client rule 3 (errors
// surface for developers, never swallowed). Verified against the code 2026-11-09.
import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/core/user_error.dart';

void main() {
  final raw = Exception('PostgrestException(code: 42501, message: row-level security)');

  group('friendlyError', () {
    test('release path shows plain copy and none of the raw text', () {
      final shown = friendlyError(saveFailedCopy, raw, showDetail: false);
      expect(shown, saveFailedCopy);
      expect(shown, isNot(contains('Postgrest')));
      expect(shown, isNot(contains('42501')));
    });

    test('debug path keeps the raw detail so errors still surface for developers', () {
      final shown = friendlyError(saveFailedCopy, raw, showDetail: true);
      expect(shown, startsWith(saveFailedCopy));
      expect(shown, contains('PostgrestException'));
    });

    test('tests run in debug mode, so the default shows detail', () {
      expect(showErrorDetail, isTrue);
    });
  });

  test('shared save-failure copy is plain: no exception talk, no blame', () {
    expect(saveFailedCopy, isNot(contains('Exception')));
    expect(saveFailedCopy.toLowerCase(), isNot(contains('failed')));
  });
}
