// Purpose: pins where the dashboard reveal leads (design review 2026-11-09, issue 23).
// Source of truth: the router table (`/drill/:loopId`) and the hub's drill CTA label
// in home_screen.dart. Verified against the code 2026-11-09.
import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/core/router.dart';
import 'package:levels_native/features/dashboard/dashboard_screen.dart';

void main() {
  group('reveal next step', () {
    test('leads into the origin drill for the same loop', () {
      expect(drillRouteFor('abc-123'), '/drill/abc-123');
    });

    test('the target is a registered route', () {
      expect(registeredRoutePaths, contains('/drill/:loopId'));
    });

    test('label matches the hub drill CTA and is not "Done"', () {
      expect(revealPrimaryCtaLabel, 'Start your origin drill');
    });
  });
}
