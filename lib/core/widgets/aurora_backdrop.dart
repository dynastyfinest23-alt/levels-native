/// Full-screen aurora backdrop (design-system/MASTER.md §1): one soft mesh
/// of `auroraA -> auroraB -> auroraC`, extremely low contrast against
/// `void`. Applied ONLY to full-screen backdrops (home hub, dashboard,
/// auth) — never on panels (MASTER.md §8 anti-pattern #5). Relies on the
/// screen behind it already painting `LevelsColors.voidColor` (the app
/// theme's `scaffoldBackgroundColor`) so the gradient's transparent edges
/// resolve to void rather than needing a second background layer here.
library;

import 'package:flutter/material.dart';

import '../design_tokens.dart';

class AuroraBackdrop extends StatelessWidget {
  const AuroraBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.9),
          radius: 1.6,
          colors: [
            LevelsColors.auroraC.withValues(alpha: 0.30),
            LevelsColors.auroraB.withValues(alpha: 0.20),
            LevelsColors.auroraA.withValues(alpha: 0.12),
            LevelsColors.auroraA.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ),
      ),
      child: child,
    );
  }
}
