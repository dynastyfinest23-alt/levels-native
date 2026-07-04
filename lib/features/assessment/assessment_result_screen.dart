import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'assessment_controller.dart';

/// Phase 1 end-of-flow placeholder: shows the database-computed Center of
/// Gravity and dominant zone. The Phase 2 dashboard replaces this later.
class AssessmentResultScreen extends StatelessWidget {
  const AssessmentResultScreen({super.key, this.result});

  final AssessmentResult? result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = this.result;
    if (result == null) {
      // Reached without a result (deep link / refresh): there is nothing to
      // show — results are only handed forward from a completed submission.
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No assessment result to display.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Go home'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Your result')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Center of Gravity',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                result.centerOfGravity.toStringAsFixed(2),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                result.dominantZone.token,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Text(
                'Phase 2 dashboard coming soon.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go('/'),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
