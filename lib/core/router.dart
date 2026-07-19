import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/assessment/assessment_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/drill/drill_screen.dart';
import '../features/home/home_screen.dart';
import '../features/reassessment/reassessment_screen.dart';
import '../features/reassessment/reassessment_tokens.dart';
import '../features/track/track_screen.dart';
import 'design_tokens.dart';

/// The only locations reachable without a session.
const Set<String> publicPaths = {'/login', '/signup'};

/// Root auth gate, applied to every navigation.
///
/// Default-deny: any location not in [publicPaths] requires a live session,
/// including routes that don't exist yet. A signed-in user is bounced off the
/// auth screens back to home. Pure function so the gate contract is testable
/// without Supabase.
String? authRedirect({required bool signedIn, required String location}) {
  final isPublic = publicPaths.contains(location);
  if (!signedIn && !isPublic) return '/login';
  if (signedIn && isPublic) return '/';
  return null;
}

/// Re-evaluates router redirects whenever Supabase auth state changes
/// (sign-in, sign-out, token refresh). Screens never navigate manually after
/// auth calls — the session is the single source of navigation truth.
class AuthStateListenable extends ChangeNotifier {
  AuthStateListenable(Stream<AuthState> authStateChanges) {
    _subscription = authStateChanges.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

typedef _RouteBuilder = Widget Function(BuildContext context, GoRouterState state);

Widget _buildHome(BuildContext context, GoRouterState state) => const HomeScreen();
Widget _buildLogin(BuildContext context, GoRouterState state) => const LoginScreen();
Widget _buildSignup(BuildContext context, GoRouterState state) => const SignupScreen();
Widget _buildAssessment(BuildContext context, GoRouterState state) =>
    const AssessmentScreen();
Widget _buildDashboard(BuildContext context, GoRouterState state) =>
    DashboardScreen(loopId: state.pathParameters['loopId']!);
Widget _buildDrill(BuildContext context, GoRouterState state) => DrillScreen(
      loopId: state.pathParameters['loopId']!,
      // M5.4 deepening_protocol entry point ("/drill/:loopId?deepen=1").
      deepen: state.uri.queryParameters['deepen'] == '1',
    );
Widget _buildTrack(BuildContext context, GoRouterState state) =>
    TrackScreen(loopId: state.pathParameters['loopId']!);
// Real screen landed in M5.2 (PRD). The window path param is parsed through
// the typed mirror — an unknown token (including `window_1`, which this
// build never uses) renders the not-found scaffold instead of the flow.
Widget _buildReassessment(BuildContext context, GoRouterState state) {
  final window =
      ReassessmentWindow.tryFromToken(state.pathParameters['window'] ?? '');
  if (window == null) return _NotFoundScreen(path: state.uri.path);
  return ReassessmentScreen(
    loopId: state.pathParameters['loopId']!,
    window: window,
  );
}

/// Single source of truth for every path [appRouter] serves: `routes` below
/// is built by iterating this table, and [registeredRoutePaths] reads its
/// keys — so removing an entry here drops it from the live router and from
/// the paths `test/router_test.dart` pins in the same stroke. A route added
/// only to `GoRouter.routes` directly (bypassing this table) would not be
/// caught by that test; route registration always goes through this map.
const Map<String, _RouteBuilder> _routeTable = {
  '/': _buildHome,
  '/login': _buildLogin,
  '/signup': _buildSignup,
  '/assessment': _buildAssessment,
  '/dashboard/:loopId': _buildDashboard,
  '/drill/:loopId': _buildDrill,
  '/track/:loopId': _buildTrack,
  '/reassessment/:loopId/:window': _buildReassessment,
};

/// Every path registered with [appRouter]. Pinned by `test/router_test.dart`.
final List<String> registeredRoutePaths = _routeTable.keys.toList();

/// Root router. Lazy top-level final: first accessed from [LevelsApp.build],
/// which runs only after `Supabase.initialize` completes.
final GoRouter appRouter = GoRouter(
  refreshListenable:
      AuthStateListenable(Supabase.instance.client.auth.onAuthStateChange),
  redirect: (context, state) => authRedirect(
    signedIn: Supabase.instance.client.auth.currentSession != null,
    location: state.matchedLocation,
  ),
  routes: [
    for (final entry in _routeTable.entries)
      GoRoute(path: entry.key, builder: entry.value),
  ],
  errorBuilder: (context, state) => _NotFoundScreen(path: state.uri.path),
);

/// Not-found scaffold, shared by the router's [GoRouter.errorBuilder] and
/// route builders that reject an invalid path parameter (e.g. an unknown
/// reassessment window token).
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Page not found: $path',
              style: LevelsType.body.copyWith(color: LevelsColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}
