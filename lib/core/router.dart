import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/assessment/assessment_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/signup_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/home/home_screen.dart';

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
// Placeholder scaffolds — real screens land in M3-M5 (PRD M1.4). Existing now
// so the home hub's phase CTAs resolve and the auth gate covers them.
Widget _buildDrill(BuildContext context, GoRouterState state) =>
    const _ComingSoonScreen(title: 'Origin drill');
Widget _buildTrack(BuildContext context, GoRouterState state) =>
    const _ComingSoonScreen(title: 'Track');
Widget _buildReassessment(BuildContext context, GoRouterState state) =>
    const _ComingSoonScreen(title: 'Reassessment');

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
  '/drill': _buildDrill,
  '/track': _buildTrack,
  '/reassessment': _buildReassessment,
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
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Page not found: ${state.uri.path}'),
          TextButton(
            onPressed: () => context.go('/'),
            child: const Text('Go home'),
          ),
        ],
      ),
    ),
  ),
);

class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$title coming soon.', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
