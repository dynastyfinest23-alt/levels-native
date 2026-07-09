import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/dashboard/dashboard_repository.dart';

/// Pins parseDashboardViewResponse against a captured fallback-path response
/// shape from generate-dashboard-copy (verified against the deployed
/// function body 2026-07-08 — cache-hit and cache-miss both return
/// `{cached, view}` with the same `view` shape). Widgetless: no Supabase
/// client involved, so it runs without a network call.
void main() {
  Map<String, dynamic> fixture({bool cached = false}) => {
        'cached': cached,
        'view': {
          'id': 'a1b2c3d4-0000-0000-0000-000000000001',
          'loop_id': 'e5f6a7b8-0000-0000-0000-000000000002',
          'zone_shown': 'builder',
          'generated_copy': {
            'reality_tunnel':
                "From here the world reads as something you're building "
                    'brick by brick, and momentum feels earned rather than '
                    'given.',
            'hidden_benefit':
                'Staying in motion has kept sharper questions about '
                    'direction from catching up with you.',
            'illusion':
                "The illusion is that the building never ends — that "
                    'arrival is one more milestone away rather than a '
                    'position you can already occupy.',
            'bridge_question':
                'What would it mean to call this enough for today?',
          },
          'bridge_question_shown': 'What would it mean to call this enough for today?',
          'copy_source': 'fallback',
          'generated_at': '2026-07-08T12:00:00Z',
        },
      };

  group('parseDashboardViewResponse', () {
    test('parses a captured fallback-path response', () {
      final view = parseDashboardViewResponse(fixture());
      expect(view.id, 'a1b2c3d4-0000-0000-0000-000000000001');
      expect(view.copy.realityTunnel, contains('brick by brick'));
      expect(
        view.copy.bridgeQuestion,
        'What would it mean to call this enough for today?',
      );
    });

    test('parses identically on a cache hit (cached: true)', () {
      final view = parseDashboardViewResponse(fixture(cached: true));
      expect(view.id, 'a1b2c3d4-0000-0000-0000-000000000001');
    });

    test('throws on a non-map response', () {
      expect(() => parseDashboardViewResponse('not a map'), throwsFormatException);
    });

    test('throws when "view" is missing', () {
      expect(() => parseDashboardViewResponse({'cached': false}), throwsFormatException);
    });

    test('throws when "generated_copy" is missing', () {
      final broken = fixture();
      (broken['view'] as Map<String, dynamic>).remove('generated_copy');
      expect(() => parseDashboardViewResponse(broken), throwsFormatException);
    });

    test('throws when "id" is missing', () {
      final broken = fixture();
      (broken['view'] as Map<String, dynamic>).remove('id');
      expect(() => parseDashboardViewResponse(broken), throwsFormatException);
    });

    test('throws when a required copy field is empty (DashboardCopy guard)', () {
      final broken = fixture();
      (broken['view'] as Map<String, dynamic>)['generated_copy']['illusion'] = '';
      expect(() => parseDashboardViewResponse(broken), throwsFormatException);
    });
  });
}
