import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';
import '../../core/zone_style.dart';
import '../assessment/assessment_controller.dart';
import 'dashboard_controller.dart';
import 'dashboard_copy.dart';

/// Phase 2 — the Variable Reward. Score and zone are fetched fresh from the
/// authoritative `phase1_assessments` row by [loopId] (so a refresh or deep
/// link works, not just navigation handed forward from Phase 1 submission);
/// the four-part reveal copy is fetched from the Edge Function and opened
/// one tap at a time.
///
/// Visual treatment: design-system/MASTER.md §6. The CoG anchor is the one
/// element allowed the `breath` idle-pulse (MASTER.md §8 anti-pattern #5 —
/// at most one `breath` element per screen); everything else on this screen
/// is deliberately still.
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Your dashboard'),
      ),
      body: AuroraBackdrop(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.loading) {
              return const Center(child: BreathingDot());
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
              'Could not load your dashboard.',
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

  static const List<String> _panelTitles = [
    'The pattern from here',
    'What this has protected you from',
    'The story that keeps it feeling permanent',
  ];

  /// Bridge question is reveal index 3 — the last slot — but it renders as
  /// the open invitation layout (`_BridgeQuestionSection`), never a glass
  /// panel (MASTER.md §6).
  static const int _bridgeIndex = 3;

  @override
  Widget build(BuildContext context) {
    final style = ZoneStyle.of(result.dominantZone);
    final panelBodies = [copy.realityTunnel, copy.hiddenBenefit, copy.illusion];
    final allRevealed = revealedCount >= DashboardController.panelCount;

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
              _CogAnchor(result: result),
              const SizedBox(height: LevelsSpace.space48),
              for (var i = 0; i < _panelTitles.length; i++) ...[
                _RevealPanel(
                  title: _panelTitles[i],
                  body: panelBodies[i],
                  state: _stateFor(i),
                  zoneColor: style.zoneColor,
                  onTap: () => onRevealPanel(i),
                ),
                const SizedBox(height: LevelsSpace.space12),
              ],
              _BridgeQuestionSection(
                question: copy.bridgeQuestion,
                state: _stateFor(_bridgeIndex),
                zoneColor: style.zoneColor,
                onTap: () => onRevealPanel(_bridgeIndex),
              ),
              if (allRevealed) ...[
                const SizedBox(height: LevelsSpace.space32),
                Text(
                  'Phase 3 coming soon.',
                  style: LevelsType.caption,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: LevelsSpace.space24),
                Center(child: _PrimaryCta(zoneColor: style.zoneColor)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _PanelState _stateFor(int index) {
    if (index < revealedCount) return _PanelState.revealed;
    if (index == revealedCount) return _PanelState.tappable;
    return _PanelState.locked;
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({required this.zoneColor});

  final Color zoneColor;

  @override
  Widget build(BuildContext context) {
    final fill = zoneColor.withValues(alpha: 0.9);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(LevelsSpace.radiusButton),
        boxShadow: [
          BoxShadow(
            color: zoneColor.withValues(alpha: 0.28),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: FilledButton(
        onPressed: () => context.go('/'),
        style: FilledButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: LevelsColors.voidColor,
          textStyle: LevelsType.button,
          padding: const EdgeInsets.symmetric(
            horizontal: LevelsSpace.space32,
            vertical: LevelsSpace.space16,
          ),
          shape: const StadiumBorder(),
        ),
        child: const Text('Done'),
      ),
    );
  }
}

/// design-system/MASTER.md §6 CoG anchor: `displayScore` numeral in
/// `zoneColor` over its `zoneGlow` halo (the sole `breath` element on this
/// screen), `zoneName` beneath in uppercase tracking. The score itself never
/// animates into place (§8 anti-pattern #6) — only the ambient glow breathes.
class _CogAnchor extends StatefulWidget {
  const _CogAnchor({required this.result});

  final AssessmentResult result;

  @override
  State<_CogAnchor> createState() => _CogAnchorState();
}

class _CogAnchorState extends State<_CogAnchor> with SingleTickerProviderStateMixin {
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
    final style = ZoneStyle.of(widget.result.dominantZone);
    return Column(
      children: [
        Text('Center of Gravity', style: LevelsType.caption),
        const SizedBox(height: LevelsSpace.space16),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = LevelsMotion.breathCurve.transform(_controller.value);
            final swing = LevelsMotion.breathAlphaSwing;
            final alphaScale = (1 - swing) + (swing * 2 * t);
            final glowAlpha = (style.zoneGlow.a * alphaScale).clamp(0.0, 1.0);
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                boxShadow: [
                  BoxShadow(
                    color: style.zoneGlow.withValues(alpha: glowAlpha),
                    blurRadius: 64,
                    spreadRadius: 16,
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Text(
            widget.result.centerOfGravity.toStringAsFixed(2),
            style: LevelsType.displayScore.copyWith(color: style.zoneColor),
          ),
        ),
        const SizedBox(height: LevelsSpace.space16),
        Text(
          style.displayName.toUpperCase(),
          style: LevelsType.zoneName.copyWith(color: style.zoneColor),
        ),
      ],
    );
  }
}

enum _PanelState { locked, tappable, revealed }

/// design-system/MASTER.md §6 reveal panel: glass card, min-height only
/// (§8 anti-pattern #4 — never a fixed height), body copy enters with the
/// `reveal` motion token on the locked/tappable -> revealed transition.
class _RevealPanel extends StatefulWidget {
  const _RevealPanel({
    required this.title,
    required this.body,
    required this.state,
    required this.zoneColor,
    required this.onTap,
  });

  final String title;
  final String body;
  final _PanelState state;
  final Color zoneColor;
  final VoidCallback onTap;

  @override
  State<_RevealPanel> createState() => _RevealPanelState();
}

class _RevealPanelState extends State<_RevealPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: LevelsMotion.reveal,
      value: widget.state == _PanelState.revealed ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _RevealPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != _PanelState.revealed && widget.state == _PanelState.revealed) {
      _revealController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final isTappable = widget.state == _PanelState.tappable;

    return ClipRRect(
      borderRadius: BorderRadius.circular(LevelsSpace.radiusPanel),
      child: InkWell(
        onTap: isTappable ? widget.onTap : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: LevelsColors.glassFill,
            border: Border(
              top: const BorderSide(color: LevelsColors.glassStroke),
              right: const BorderSide(color: LevelsColors.glassStroke),
              bottom: const BorderSide(color: LevelsColors.glassStroke),
              left: BorderSide(
                color: isTappable ? widget.zoneColor : LevelsColors.glassStroke,
                width: isTappable ? 2 : 1,
              ),
            ),
          ),
          padding: const EdgeInsets.all(LevelsSpace.space16),
          child: AnimatedSize(
            duration: LevelsMotion.reveal,
            curve: LevelsMotion.revealCurve,
            alignment: Alignment.topCenter,
            child: switch (widget.state) {
              _PanelState.locked => Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: LevelsType.panelTitle.copyWith(
                          color: LevelsColors.textFaint,
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: 0.4,
                      child: const Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: LevelsColors.textFaint,
                      ),
                    ),
                  ],
                ),
              _PanelState.tappable => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.title, style: LevelsType.panelTitle),
                    const SizedBox(height: LevelsSpace.space8),
                    Text(
                      'Tap to reveal',
                      style: LevelsType.caption.copyWith(
                        color: LevelsColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              _PanelState.revealed => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(widget.title, style: LevelsType.panelTitle),
                    const SizedBox(height: LevelsSpace.space12),
                    AnimatedBuilder(
                      animation: _revealController,
                      builder: (context, child) {
                        final curved =
                            LevelsMotion.revealCurve.transform(_revealController.value);
                        final rise = reducedMotion ? 0.0 : (1 - curved) * LevelsSpace.revealRise;
                        return Opacity(
                          opacity: curved.clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, rise),
                            child: child,
                          ),
                        );
                      },
                      child: Text(widget.body, style: LevelsType.body),
                    ),
                  ],
                ),
            },
          ),
        ),
      ),
    );
  }
}

/// design-system/MASTER.md §6 bridge question: NOT a glass card. A thin
/// `zoneColor` hairline above, question in `invitation` type, generous 32px
/// padding — reads as an invitation, not a fourth data panel.
class _BridgeQuestionSection extends StatefulWidget {
  const _BridgeQuestionSection({
    required this.question,
    required this.state,
    required this.zoneColor,
    required this.onTap,
  });

  final String question;
  final _PanelState state;
  final Color zoneColor;
  final VoidCallback onTap;

  @override
  State<_BridgeQuestionSection> createState() => _BridgeQuestionSectionState();
}

class _BridgeQuestionSectionState extends State<_BridgeQuestionSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _revealController;

  @override
  void initState() {
    super.initState();
    _revealController = AnimationController(
      vsync: this,
      duration: LevelsMotion.reveal,
      value: widget.state == _PanelState.revealed ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant _BridgeQuestionSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != _PanelState.revealed && widget.state == _PanelState.revealed) {
      _revealController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final isTappable = widget.state == _PanelState.tappable;

    return InkWell(
      onTap: isTappable ? widget.onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: LevelsSpace.space32),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: widget.zoneColor, width: 1)),
        ),
        child: AnimatedSize(
          duration: LevelsMotion.reveal,
          curve: LevelsMotion.revealCurve,
          alignment: Alignment.topCenter,
          child: switch (widget.state) {
            _PanelState.locked => Text(
                'A question worth sitting with',
                style: LevelsType.caption.copyWith(color: LevelsColors.textFaint),
              ),
            _PanelState.tappable => Text(
                'Tap to reveal a question worth sitting with',
                style: LevelsType.caption.copyWith(color: LevelsColors.textSecondary),
              ),
            _PanelState.revealed => AnimatedBuilder(
                animation: _revealController,
                builder: (context, child) {
                  final curved =
                      LevelsMotion.revealCurve.transform(_revealController.value);
                  final rise = reducedMotion ? 0.0 : (1 - curved) * LevelsSpace.revealRise;
                  return Opacity(
                    opacity: curved.clamp(0.0, 1.0),
                    child: Transform.translate(offset: Offset(0, rise), child: child),
                  );
                },
                child: Text(widget.question, style: LevelsType.invitation),
              ),
          },
        ),
      ),
    );
  }
}
