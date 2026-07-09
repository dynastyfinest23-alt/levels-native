/// Loading indicator (design-system/MASTER.md §6): a slow-breathing 8px dot
/// in the accent color, replacing spinners where feasible. Uses the same
/// `breath` motion token as the CoG glow — but a dot and a CoG glow never
/// share a screen, so the "one `breath` element per screen" rule (MASTER.md
/// §8 anti-pattern #5) is never violated.
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

class BreathingDot extends StatefulWidget {
  const BreathingDot({
    super.key,
    this.color = LevelsColors.neutralAccent,
    this.size = 8,
  });

  final Color color;
  final double size;

  @override
  State<BreathingDot> createState() => _BreathingDotState();
}

class _BreathingDotState extends State<BreathingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: LevelsMotion.breath);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
      _controller.value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = LevelsMotion.breathCurve.transform(_controller.value);
        final swing = LevelsMotion.breathAlphaSwing;
        final opacity = (1 - swing) + (swing * 2 * t);
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
          ),
        );
      },
    );
  }
}
