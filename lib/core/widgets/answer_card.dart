// Purpose: shared glass answer card (label + selected left accent) used by the
// Phase 1 assessment and the block-map runner. Extracted unchanged from
// assessment_screen.dart (block-map plan Task 1). Visuals: MASTER.md glass card,
// `neutralAccent` left border when selected.
import 'package:flutter/material.dart';

import '../design_tokens.dart';

class AnswerCard extends StatelessWidget {
  const AnswerCard({
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
