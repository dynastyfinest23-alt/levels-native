import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../assessment/assessment_controller.dart';
import 'dashboard_controller.dart';
import 'dashboard_copy.dart';

/// Phase 2 — the Variable Reward. Score and zone are fetched fresh from the
/// authoritative `phase1_assessments` row by [loopId] (so a refresh or deep
/// link works, not just navigation handed forward from Phase 1 submission);
/// the four-part reveal copy is fetched from the Edge Function and opened
/// one tap at a time.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.loopId});

  final String loopId;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DashboardController(loopId: widget.loopId);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.recordTimeOnScreen();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your dashboard')),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          final error = _controller.error;
          if (error != null) {
            return _DashboardErrorView(error: error, onRetry: _controller.load);
          }
          final copy = _controller.copy;
          final result = _controller.assessmentResult;
          if (copy == null || result == null) {
            // load() always sets both (or error) before clearing loading —
            // unreachable, but errors must surface, never render blank.
            return _DashboardErrorView(
              error: 'No dashboard data was returned.',
              onRetry: _controller.load,
            );
          }
          return _DashboardBody(
            result: result,
            copy: copy,
            revealedCount: _controller.revealedCount,
            onRevealPanel: _controller.revealPanel,
          );
        },
      ),
    );
  }
}

class _DashboardErrorView extends StatelessWidget {
  const _DashboardErrorView({required this.error, required this.onRetry});

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
            Text('Could not load your dashboard.', style: theme.textTheme.titleMedium),
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

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.result,
    required this.copy,
    required this.revealedCount,
    required this.onRevealPanel,
  });

  final AssessmentResult result;
  final DashboardCopy copy;
  final int revealedCount;
  final ValueChanged<int> onRevealPanel;

  static const List<String> _titles = [
    'The pattern from here',
    'What this has protected you from',
    'The story that keeps it feeling permanent',
    'A question worth sitting with',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bodies = [
      copy.realityTunnel,
      copy.hiddenBenefit,
      copy.illusion,
      copy.bridgeQuestion,
    ];
    final allRevealed = revealedCount >= DashboardController.panelCount;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Center of Gravity', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            result.centerOfGravity.toStringAsFixed(2),
            style: theme.textTheme.displayMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(result.dominantZone.token, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 32),
          for (var i = 0; i < _titles.length; i++) ...[
            _RevealPanel(
              title: _titles[i],
              body: bodies[i],
              state: i < revealedCount
                  ? _PanelState.revealed
                  : i == revealedCount
                      ? _PanelState.tappable
                      : _PanelState.locked,
              onTap: () => onRevealPanel(i),
            ),
            const SizedBox(height: 12),
          ],
          if (allRevealed) ...[
            const SizedBox(height: 12),
            Text(
              'Phase 3 coming soon.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/'),
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    );
  }
}

enum _PanelState { locked, tappable, revealed }

class _RevealPanel extends StatelessWidget {
  const _RevealPanel({
    required this.title,
    required this.body,
    required this.state,
    required this.onTap,
  });

  final String title;
  final String body;
  final _PanelState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: state == _PanelState.locked ? colors.surfaceContainerLow : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: state == _PanelState.tappable ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: switch (state) {
                  _PanelState.locked => Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  _PanelState.tappable => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.labelLarge),
                        const SizedBox(height: 4),
                        Text('Tap to reveal', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  _PanelState.revealed => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Text(body, style: theme.textTheme.bodyLarge),
                      ],
                    ),
                },
              ),
              if (state == _PanelState.tappable)
                const Icon(Icons.touch_app_outlined),
              if (state == _PanelState.locked)
                const Icon(Icons.lock_outline),
            ],
          ),
        ),
      ),
    );
  }
}
