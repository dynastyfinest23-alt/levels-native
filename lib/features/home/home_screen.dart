import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';
import '../../core/widgets/progress_dots.dart';
import '../journey/journey_repository.dart';
import '../journey/loop_state.dart';
import '../reassessment/routing.dart';
import '../track/embodiment_gate.dart';

/// The journey hub: shows where the user is in their current loop and
/// routes to exactly one next action. No active loop -> "Begin assessment".
///
/// Visual treatment: design-system/MASTER.md §6. This screen has no zone
/// context (no score is shown here), so it uses `neutralAccent` with no
/// glow (MASTER.md §2) rather than `ZoneStyle`.
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Levels'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, color: LevelsColors.textSecondary),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: AuroraBackdrop(
        child: SafeArea(
          child: _loading
              ? const Center(child: BreathingDot())
              : _error != null
                  ? _HubErrorView(error: _error!, onRetry: _load)
                  : _HubBody(email: email, data: _data),
        ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LevelsSpace.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 32,
              color: LevelsColors.textSecondary,
            ),
            const SizedBox(height: LevelsSpace.space16),
            Text(
              'Could not load your journey.',
              style: LevelsType.body.copyWith(color: LevelsColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LevelsSpace.space8),
            Text(
              error,
              style: LevelsType.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LevelsSpace.space24),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: LevelsColors.textPrimary,
                side: const BorderSide(color: LevelsColors.glassStroke),
                shape: const StadiumBorder(),
                textStyle: LevelsType.button,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Where each phase's primary CTA sends the user, and what it says.
class _PhaseCta {
  const _PhaseCta(this.label, this.route, {this.enabled = true});
  final String label;
  final String route;

  /// False only for the retest wait (PRD M5.4): the CTA renders disabled
  /// until the 48-hour gate lifts. Quiet text, never a countdown.
  final bool enabled;
}

_PhaseCta _ctaFor(JourneyPhase phase, String? loopId, TrackProgress? track) {
  return switch (phase) {
    JourneyPhase.assessment => const _PhaseCta('Begin assessment', '/assessment'),
    JourneyPhase.dashboard => _PhaseCta('See your dashboard', '/dashboard/$loopId'),
    JourneyPhase.drill => _PhaseCta('Start your origin drill', '/drill/$loopId'),
    JourneyPhase.track => _PhaseCta(_trackCtaLabel(track), '/track/$loopId'),
    JourneyPhase.window2 =>
      _PhaseCta('Day 5–7 check-in', '/reassessment/$loopId/window_2'),
    JourneyPhase.window3 =>
      _PhaseCta('Day 21 durability check', '/reassessment/$loopId/window_3'),
    JourneyPhase.complete => const _PhaseCta('Start a new loop', '/assessment'),
  };
}

/// The embodiment track is the only one with a daily beat worth surfacing
/// on the hub (PRD M4.6) — every other track (and a completed or gate-less
/// embodiment session) keeps the generic label.
String _trackCtaLabel(TrackProgress? track) {
  final gate = track?.embodimentGate;
  if (gate == null) return 'Continue your track';
  return switch (gate.status) {
    EmbodimentDayStatus.open => 'Day ${gate.dayNumber} of 7',
    EmbodimentDayStatus.alreadyLoggedToday =>
      'Day ${gate.dayNumber} logged. Come back tomorrow',
    EmbodimentDayStatus.windowElapsed => 'Continue your track',
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
    final data = this.data;
    final phase = data?.loopState.currentPhase ?? JourneyPhase.assessment;
    var cta = _ctaFor(phase, data?.loopId, data?.trackProgress);

    // PRD M5.4: once Window 2 has been routed, the hub's next action is the
    // routing outcome's destination, not the generic track CTA. (For
    // `new_loop` the loop is already marked complete, so this branch is the
    // belt-and-suspenders view before the next fetch.)
    final w2 = data?.window2Reassessment;
    if (phase == JourneyPhase.track && w2?.routingOutcome != null) {
      final followUp = hubFollowUpFor(
        w2!.routingOutcome!,
        retestOpen: retestGateOpen(
          reassessedAt: w2.administeredAt,
          now: DateTime.now(),
        ),
      );
      cta = _PhaseCta(
        followUp.label,
        routeForDestination(followUp.destination, data!.loopId),
        enabled: followUp.enabled,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: LevelsSpace.contentMaxWidth),
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: LevelsSpace.screenGutter,
            vertical: LevelsSpace.space32,
          ),
          children: [
            Text(
              'Signed in as ${email ?? 'unknown'}',
              style: LevelsType.caption,
            ),
            const SizedBox(height: LevelsSpace.space32),
            if (data != null) ...[
              Text('Loop ${data.loopNumber}', style: LevelsType.displayTitle),
              const SizedBox(height: LevelsSpace.space8),
              Text(
                'Day ${data.loopState.loopDay} · ${_phaseLabel(phase)}',
                style: LevelsType.body.copyWith(color: LevelsColors.textSecondary),
              ),
              const SizedBox(height: LevelsSpace.space32),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: cta.enabled ? () => context.go(cta.route) : null,
                child: Text(cta.label),
              ),
            ),
            if (data?.calibration case final calibration?) ...[
              const SizedBox(height: LevelsSpace.space32),
              _CalibrationStrip(calibration: calibration),
            ],
          ],
        ),
      ),
    );
  }
}

/// design-system/MASTER.md §6 calibration strip: `caption` type on
/// `surface`, no glass, no glow — an instrument readout, deliberately quiet.
///
/// Shows verification progress as dots, not the raw `verified_floor` /
/// `consecutive_verified_loops` values — those are climb mechanics and must
/// stay off-screen as numbers (CLAUDE.md tone rule).
class _CalibrationStrip extends StatelessWidget {
  const _CalibrationStrip({required this.calibration});

  final UserCalibration calibration;

  @override
  Widget build(BuildContext context) {
    final loopsVerified = calibration.consecutiveVerifiedLoops < flowGateLoops
        ? calibration.consecutiveVerifiedLoops
        : flowGateLoops;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(LevelsSpace.space16),
      decoration: BoxDecoration(
        color: LevelsColors.surface,
        borderRadius: BorderRadius.circular(LevelsSpace.radiusPanel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Calibration', style: LevelsType.panelTitle),
          const SizedBox(height: LevelsSpace.space8),
          Row(
            children: [
              Text('Verified climb', style: LevelsType.caption),
              const SizedBox(width: LevelsSpace.space8),
              ProgressDots(filled: loopsVerified, total: flowGateLoops),
            ],
          ),
        ],
      ),
    );
  }
}
