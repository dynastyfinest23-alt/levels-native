import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';
import '../drill/drill_tokens.dart' show AscensionTrack;
import 'track_content.dart';
import 'track_session_controller.dart';
import 'track_widgets.dart';

/// completion track flow (PRD M4.3): name the unfinished thing, size the
/// timeline, then — only when `completionIntegrityCheckTriggered` fires — a
/// reflective third stage before finishing. Reaching the end always counts
/// as success (`TrackSessionController.finishCompletion`); the integrity
/// check is reflective, never a fail state (ACTION-FOR-NOAH.md, approved
/// 2026-07-16).
///
/// Stage transitions use `AnimatedSwitcher` (docs/m4-ui-pattern-notes.md
/// finding 1) rather than a fixed-length `PageView` like `DrillScreen`,
/// since the third stage is conditional on the controller's own state.
class CompletionScreen extends StatefulWidget {
  const CompletionScreen({super.key, required this.loopId});

  final String loopId;

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

enum _Stage { statement, duration, integrityCheck }

class _CompletionScreenState extends State<CompletionScreen> {
  late final TrackSessionController _controller;
  final TextEditingController _statementText = TextEditingController();
  _Stage _stage = _Stage.statement;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TrackSessionController(
      loopId: widget.loopId,
      track: AscensionTrack.completion,
    );
    _controller.load().then((_) => _resolveInitialStage());
  }

  @override
  void dispose() {
    _controller.dispose();
    _statementText.dispose();
    super.dispose();
  }

  void _resolveInitialStage() {
    if (!mounted || _controller.error != null) return;
    _statementText.text = _controller.completionStatement ?? '';
    setState(() {
      if (_controller.completionStatement == null) {
        _stage = _Stage.statement;
      } else if (_controller.prepDuration == null) {
        _stage = _Stage.duration;
      } else if (_controller.integrityCheckTriggered) {
        _stage = _Stage.integrityCheck;
      } else {
        // Both fields were already saved on a prior visit and no reflection
        // is due — finish immediately rather than re-showing done stages.
        _finish();
      }
    });
  }

  void _goBack() {
    setState(() {
      _stage = switch (_stage) {
        _Stage.statement => _Stage.statement,
        _Stage.duration => _Stage.statement,
        _Stage.integrityCheck => _Stage.duration,
      };
    });
  }

  Future<void> _runGuarded(Future<void> Function() action) async {
    setState(() => _submitting = true);
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Something went wrong: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _continueFromStatement() async {
    _controller.setCompletionStatement(_statementText.text.trim());
    setState(() => _stage = _Stage.duration);
  }

  Future<void> _continueFromDuration() => _runGuarded(() async {
        await _controller.saveCompletionStage();
        if (_controller.integrityCheckTriggered) {
          if (!mounted) return;
          setState(() => _stage = _Stage.integrityCheck);
        } else {
          await _finish();
        }
      });

  Future<void> _finish() => _runGuarded(() async {
        await _controller.finishCompletion();
        if (!mounted) return;
        context.go('/');
      });

  bool get _canContinue {
    switch (_stage) {
      case _Stage.statement:
        return _statementText.text.trim().isNotEmpty;
      case _Stage.duration:
        return _controller.prepDuration != null;
      case _Stage.integrityCheck:
        return true;
    }
  }

  String get _continueLabel {
    switch (_stage) {
      case _Stage.statement:
        return 'Continue';
      case _Stage.duration:
        final duration = _controller.prepDuration;
        final willReflect =
            duration != null && completionIntegrityCheckTriggered(duration);
        return willReflect ? 'Continue' : 'Finish';
      case _Stage.integrityCheck:
        return 'Finish';
    }
  }

  VoidCallback? get _onContinue {
    if (_submitting || _controller.saving || !_canContinue) return null;
    return switch (_stage) {
      _Stage.statement => () => _continueFromStatement(),
      _Stage.duration => () => _continueFromDuration(),
      _Stage.integrityCheck => () => _finish(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final loading = _controller.loading;
        final error = _controller.error;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              tooltip: _stage == _Stage.statement ? 'Exit' : 'Back',
              icon: Icon(
                _stage == _Stage.statement ? Icons.close : Icons.arrow_back,
                color: LevelsColors.textSecondary,
              ),
              onPressed: _submitting
                  ? null
                  : (_stage == _Stage.statement
                      ? () => context.go('/')
                      : _goBack),
            ),
          ),
          body: AuroraBackdrop(
            child: loading
                ? const Center(child: BreathingDot())
                : error != null
                    ? TrackErrorView(
                        message: 'Could not load your track.',
                        error: error,
                        onRetry: _controller.load,
                      )
                    : _submitting
                        ? const Center(child: BreathingDot())
                        : AnimatedSwitcher(
                            duration: LevelsMotion.reveal,
                            switchInCurve: LevelsMotion.revealCurve,
                            switchOutCurve: LevelsMotion.revealCurve,
                            child: KeyedSubtree(
                              key: ValueKey(_stage),
                              child: _buildStage(),
                            ),
                          ),
          ),
          bottomNavigationBar: loading || error != null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(LevelsSpace.screenGutter),
                    child: FilledButton(
                      onPressed: _onContinue,
                      child: Text(_continueLabel),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.statement:
        return TrackTextStage(
          title: completionStatementTitle,
          prompt: completionStatementPrompt,
          controller: _statementText,
          onChanged: (_) => setState(() {}),
        );
      case _Stage.duration:
        return TrackOptionListStage(
          title: completionDurationTitle,
          prompt: completionDurationPrompt,
          options: [
            for (final o in completionDurationOptions) (label: o.label, value: o.duration),
          ],
          selected: _controller.prepDuration,
          onSelect: (d) => setState(() => _controller.selectPrepDuration(d)),
        );
      case _Stage.integrityCheck:
        return const _IntegrityCheckStage();
    }
  }
}

class _IntegrityCheckStage extends StatelessWidget {
  const _IntegrityCheckStage();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: LevelsSpace.contentMaxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: LevelsSpace.screenGutter),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  completionIntegrityCheckTitle,
                  style: LevelsType.panelTitle.copyWith(color: LevelsColors.textSecondary),
                ),
                const SizedBox(height: LevelsSpace.space16),
                Text(completionIntegrityCheckCopy, style: LevelsType.invitation),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
