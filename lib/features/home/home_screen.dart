import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../journey/journey_repository.dart';
import '../journey/loop_state.dart';

/// The journey hub: shows where the user is in their current loop and
/// routes to exactly one next action. No active loop -> "Begin assessment".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final JourneyRepository _repository = JourneyRepository();
  bool _loading = true;
  String? _error;
  JourneyData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.fetchActiveLoop();
      if (!mounted) return;
      setState(() => _data = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      // The router redirects to /login via the auth state change.
    } on AuthException catch (error) {
      if (!context.mounted) return;
      _showError(context, error.message);
    } catch (error) {
      if (!context.mounted) return;
      _showError(context, 'Sign-out failed: $error');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = Supabase.instance.client.auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Levels'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _HubErrorView(error: _error!, onRetry: _load)
                : _HubBody(email: email, data: _data),
      ),
    );
  }
}

class _HubErrorView extends StatelessWidget {
  const _HubErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Could not load your journey.', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(error, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Where each phase's primary CTA sends the user, and what it says.
class _PhaseCta {
  const _PhaseCta(this.label, this.route);
  final String label;
  final String route;
}

_PhaseCta _ctaFor(JourneyPhase phase, String? loopId) {
  return switch (phase) {
    JourneyPhase.assessment => const _PhaseCta('Begin assessment', '/assessment'),
    JourneyPhase.dashboard => _PhaseCta('See your dashboard', '/dashboard/$loopId'),
    JourneyPhase.drill => const _PhaseCta('Start your origin drill', '/drill'),
    JourneyPhase.track => const _PhaseCta('Continue your track', '/track'),
    JourneyPhase.window2 => const _PhaseCta('Day 5–7 check-in', '/reassessment'),
    JourneyPhase.window3 => const _PhaseCta('Day 21 durability check', '/reassessment'),
    JourneyPhase.complete => const _PhaseCta('Start a new loop', '/assessment'),
  };
}

String _phaseLabel(JourneyPhase phase) => switch (phase) {
      JourneyPhase.assessment => 'Not started',
      JourneyPhase.dashboard => 'Dashboard reveal',
      JourneyPhase.drill => 'Origin drill',
      JourneyPhase.track => 'Working your track',
      JourneyPhase.window2 => 'Day 5–7 check-in open',
      JourneyPhase.window3 => 'Day 21 durability check open',
      JourneyPhase.complete => 'Loop complete',
    };

class _HubBody extends StatelessWidget {
  const _HubBody({required this.email, required this.data});

  final String? email;
  final JourneyData? data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = this.data;
    final phase = data?.loopState.currentPhase ?? JourneyPhase.assessment;
    final cta = _ctaFor(phase, data?.loopId);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Signed in as ${email ?? 'unknown'}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
        if (data != null) ...[
          Text('Loop ${data.loopNumber}', style: theme.textTheme.labelLarge),
          const SizedBox(height: 4),
          Text('Day ${data.loopState.loopDay}', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(_phaseLabel(phase), style: theme.textTheme.bodyMedium),
          const SizedBox(height: 24),
        ],
        FilledButton(
          onPressed: () => context.go(cta.route),
          child: Text(cta.label),
        ),
        if (data?.calibration case final calibration?) ...[
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          Text('Calibration', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            'Verified floor: ${calibration.verifiedFloor.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            'Consecutive verified loops: ${calibration.consecutiveVerifiedLoops}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}
