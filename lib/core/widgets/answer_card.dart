// Purpose: the one shared answer card (label + selected state) used by the
// Phase 1 assessment, the drill, the reassessment, the tracks and the
// block-map runner. Fix 5 (design review 2026-11-09, issues 3 and 4): it is
// always full column width, and the selected state is a uniform 2px accent
// border on a rounded shape, so ink and hover stay inside the corners.
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
    return Semantics(
      button: true,
      selected: selected,
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: LevelsColors.glassFill,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LevelsSpace.radiusPanel),
            side: BorderSide(
              color: selected ? LevelsColors.neutralAccent : LevelsColors.glassStroke,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(LevelsSpace.space16),
              child: Text(label, style: LevelsType.body),
            ),
          ),
        ),
      ),
    );
  }
}
