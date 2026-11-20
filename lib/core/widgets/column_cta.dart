// Purpose: the bottom primary button for paged flows (drill, reassessment).
// Fix 5 (design review 2026-11-09, issue 2): constrained to the same
// content column as the page above it instead of running edge to edge.
import 'package:flutter/material.dart';

import '../design_tokens.dart';

class ColumnCta extends StatelessWidget {
  const ColumnCta({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LevelsSpace.contentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.all(LevelsSpace.screenGutter),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: onPressed, child: Text(label)),
            ),
          ),
        ),
      ),
    );
  }
}
