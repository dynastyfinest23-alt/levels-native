import 'package:flutter/material.dart';

import '../design_tokens.dart';

/// Consecutive verified loops needed before Flow-band framing opens
/// (CLAUDE.md "Flow reachability", FLOW_GATE = 3). Sizes [ProgressDots]
/// only — never rendered as a number on screen (copy never mentions
/// numbers, scores, or zone names as mechanics).
const flowGateLoops = 3;

/// Mechanic-free verification progress: filled/empty dots, never the raw
/// `consecutive_verified_loops` / `verified_floor` values (CLAUDE.md tone
/// rule — those are climb mechanics and stay off-screen as numbers). Used
/// by the home hub's calibration strip and the Window 3 closing screen.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.filled, required this.total});

  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        return Container(
          margin: const EdgeInsets.only(right: LevelsSpace.space4),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < filled
                ? LevelsColors.neutralAccent
                : LevelsColors.textFaint,
          ),
        );
      }),
    );
  }
}
