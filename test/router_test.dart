import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/core/router.dart';

/// Pins that every route the home hub's phase CTAs can navigate to is
/// actually registered. `registeredRoutePaths` is read from the same table
/// that builds `appRouter.routes` (lib/core/router.dart), so removing a
/// route from that table — accidentally or via a partial revert — fails
/// this test instead of only surfacing as a runtime "Page not found".
void main() {
  test('registeredRoutePaths contains every app + placeholder route', () {
    expect(
      registeredRoutePaths,
      containsAll(<String>[
        '/',
        '/assessment',
        '/dashboard/:loopId',
        '/drill',
        '/track',
        '/reassessment',
      ]),
    );
  });
}
