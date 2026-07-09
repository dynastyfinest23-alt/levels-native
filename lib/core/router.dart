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
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/assessment',
      builder: (context, state) => const AssessmentScreen(),
    ),
    GoRoute(
      path: '/dashboard/:loopId',
      builder: (context, state) => DashboardScreen(
        loopId: state.pathParameters['loopId']!,
      ),
    ),
    // Placeholder scaffolds — real screens land in M3-M5 (PRD M1.4). Existing
    // now so the home hub's phase CTAs resolve and the auth gate covers them.
    GoRoute(
      path: '/drill',
      builder: (context, state) => const _ComingSoonScreen(title: 'Origin drill'),
    ),
    GoRoute(
      path: '/track',
      builder: (context, state) => const _ComingSoonScreen(title: 'Track'),
    ),
    GoRoute(
      path: '/reassessment',
      builder: (context, state) => const _ComingSoonScreen(title: 'Reassessment'),
    ),
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
