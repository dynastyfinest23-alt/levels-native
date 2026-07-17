import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';

/// Shared presentational widgets for the Phase 4 track screens
/// (`CompletionScreen`, `CommitmentScreen`, ...) — the same title/prompt/
/// input shape `DrillScreen`'s private widgets use, extracted once two
/// screens needed it instead of duplicated per screen.

/// One free-text stage: title, prompt, single text field.
class TrackTextStage extends StatelessWidget {
  const TrackTextStage({
    super.key,
    required this.title,
    required this.prompt,
    required this.controller,
    required this.onChanged,
    this.maxLines = 4,
    this.keyboardType,
    this.hintText = 'In your own words…',
  });

  final String title;
  final String prompt;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int maxLines;
  final TextInputType? keyboardType;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LevelsSpace.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: LevelsSpace.screenGutter,
              vertical: LevelsSpace.space32,
            ),
            children: [
              Text(title, style: LevelsType.panelTitle.copyWith(color: LevelsColors.textSecondary)),
              const SizedBox(height: LevelsSpace.space8),
              Text(prompt, style: LevelsType.displayTitle),
              const SizedBox(height: LevelsSpace.space24),
              TextField(
                controller: controller,
                style: LevelsType.body,
                maxLines: maxLines,
                keyboardType: keyboardType,
                decoration: InputDecoration(hintText: hintText),
                onChanged: onChanged,
              ),
              const SizedBox(height: LevelsSpace.space64),
            ],
          ),
        ),
      ),
    );
  }
}

/// One multiple-choice stage, generic over the option's token type.
class TrackOptionListStage<T> extends StatelessWidget {
  const TrackOptionListStage({
    super.key,
    required this.title,
    required this.prompt,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.trailing,
  });

  final String title;
  final String prompt;
  final List<({String label, T value})> options;
  final T? selected;
  final ValueChanged<T> onSelect;

  /// Extra content below the options (e.g. a conditional free-text field).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LevelsSpace.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: LevelsSpace.screenGutter,
              vertical: LevelsSpace.space32,
            ),
            children: [
              Text(title, style: LevelsType.panelTitle.copyWith(color: LevelsColors.textSecondary)),
              const SizedBox(height: LevelsSpace.space8),
              Text(prompt, style: LevelsType.displayTitle),
              const SizedBox(height: LevelsSpace.space24),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: LevelsSpace.space12),
                  child: TrackOptionCard(
                    label: option.label,
                    selected: option.value == selected,
                    onTap: () => onSelect(option.value),
                  ),
                ),
              if (trailing != null) ...[
                const SizedBox(height: LevelsSpace.space12),
                trailing!,
              ],
              const SizedBox(height: LevelsSpace.space64),
            ],
          ),
        ),
      ),
    );
  }
}

class TrackOptionCard extends StatelessWidget {
  const TrackOptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(LevelsSpace.radiusPanel),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: LevelsColors.glassFill,
            border: Border(
              top: const BorderSide(color: LevelsColors.glassStroke),
              right: const BorderSide(color: LevelsColors.glassStroke),
              bottom: const BorderSide(color: LevelsColors.glassStroke),
              left: BorderSide(
                color: selected ? LevelsColors.neutralAccent : LevelsColors.glassStroke,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: LevelsSpace.space16,
            vertical: LevelsSpace.space16,
          ),
          child: Text(label, style: LevelsType.body),
        ),
      ),
    );
  }
}

/// Load-failure view shared by the track screens. `message` names what
/// failed to load ("your track", "your check-in", ...).
class TrackErrorView extends StatelessWidget {
  const TrackErrorView({
    super.key,
    required this.message,
    required this.error,
    required this.onRetry,
  });

  final String message;
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
            const Icon(Icons.error_outline, size: 32, color: LevelsColors.textSecondary),
            const SizedBox(height: LevelsSpace.space16),
            Text(
              message,
              style: LevelsType.body.copyWith(color: LevelsColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LevelsSpace.space8),
            Text(error, style: LevelsType.caption, textAlign: TextAlign.center),
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
