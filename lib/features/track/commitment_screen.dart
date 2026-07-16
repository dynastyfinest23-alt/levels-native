import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';
import '../drill/drill_tokens.dart' show AscensionTrack;
import 'track_content.dart';
import 'track_session_controller.dart';
import 'track_tokens.dart';
import 'track_widgets.dart';

/// commitment track flow (PRD M4.3): declare + pick a constraint now, then
/// — on a later visit, once the ~72h check-in is due — report whether it
/// happened. The session stays open between visits (never `finish`ed at
/// declaration time); success is `checkin_response == yes` only
/// (`TrackSessionController.finishCommitmentCheckin`,
/// ACTION-FOR-NOAH.md, approved 2026-07-16).
class CommitmentScreen extends StatefulWidget {
  const CommitmentScreen({super.key, required this.loopId});

  final String loopId;

  @override
  State<CommitmentScreen> createState() => _CommitmentScreenState();
}

enum _Stage { declaration, constraint, checkin }

class _CommitmentScreenState extends State<CommitmentScreen> {
  late final TrackSessionController _controller;
  final TextEditingController _declarationText = TextEditingController();
  final TextEditingController _blockerText = TextEditingController();
  _Stage _stage = _Stage.declaration;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TrackSessionController(
      loopId: widget.loopId,
      track: AscensionTrack.commitment,
    );
    _controller.load().then((_) => _resolveInitialStage());
  }

  @override
  void dispose() {
    _controller.dispose();
    _declarationText.dispose();
    _blockerText.dispose();
    super.dispose();
  }

  void _resolveInitialStage() {
    if (!mounted || _controller.error != null) return;
    _declarationText.text = _controller.declarationText ?? '';
    _blockerText.text = _controller.checkinBlockerText ?? '';
    setState(() {
      if (_controller.declarationText == null) {
        _stage = _Stage.declaration;
      } else if (_controller.constraintChosen == null) {
        _stage = _Stage.constraint;
      } else {
        // Declaration already saved on a prior visit — resuming means the
        // check-in is the reason the user is back.
        _stage = _Stage.checkin;
      }
    });
  }

  void _goBack() {
    setState(() {
      _stage = switch (_stage) {
        _Stage.declaration => _Stage.declaration,
        _Stage.constraint => _Stage.declaration,
        _Stage.checkin => _Stage.checkin,
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

  Future<void> _continueFromDeclaration() async {
    _controller.setDeclarationText(_declarationText.text.trim());
    setState(() => _stage = _Stage.constraint);
  }

  Future<void> _saveDeclaration() => _runGuarded(() async {
        await _controller.saveDeclarationStage();
        if (!mounted) return;
        context.go('/');
      });

  Future<void> _finishCheckin() => _runGuarded(() async {
        if (_controller.checkinResponse != CheckinResponse.yes) {
          _controller.setCheckinBlockerText(_blockerText.text.trim());
        }
        await _controller.saveCheckinStage();
        await _controller.finishCommitmentCheckin();
        if (!mounted) return;
        context.go('/');
      });

  bool get _canContinue {
    switch (_stage) {
      case _Stage.declaration:
        return _declarationText.text.trim().isNotEmpty;
      case _Stage.constraint:
        return _controller.constraintChosen != null;
      case _Stage.checkin:
        final response = _controller.checkinResponse;
        if (response == null) return false;
        return response == CheckinResponse.yes ||
            _blockerText.text.trim().isNotEmpty;
    }
  }

  String get _continueLabel {
    switch (_stage) {
      case _Stage.declaration:
        return 'Continue';
      case _Stage.constraint:
        return 'Save';
      case _Stage.checkin:
        return 'Finish';
    }
  }

  VoidCallback? get _onContinue {
    if (_submitting || _controller.saving || !_canContinue) return null;
    return switch (_stage) {
      _Stage.declaration => () => _continueFromDeclaration(),
      _Stage.constraint => () => _saveDeclaration(),
      _Stage.checkin => () => _finishCheckin(),
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
              tooltip: _stage == _Stage.constraint ? 'Back' : 'Exit',
              icon: Icon(
                _stage == _Stage.constraint ? Icons.arrow_back : Icons.close,
                color: LevelsColors.textSecondary,
              ),
              onPressed: _submitting
                  ? null
                  : (_stage == _Stage.constraint
                      ? _goBack
                      : () => context.go('/')),
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
      case _Stage.declaration:
        return TrackTextStage(
          title: commitmentDeclarationTitle,
          prompt: commitmentDeclarationPrompt,
          controller: _declarationText,
          onChanged: (_) => setState(() {}),
        );
      case _Stage.constraint:
        return TrackOptionListStage(
          title: commitmentConstraintTitle,
          prompt: commitmentConstraintPrompt,
          options: [
            for (final o in commitmentConstraintOptions) (label: o.label, value: o.constraint),
          ],
          selected: _controller.constraintChosen,
          onSelect: (c) => setState(() => _controller.selectConstraintType(c)),
        );
      case _Stage.checkin:
        final response = _controller.checkinResponse;
        return TrackOptionListStage(
          title: commitmentCheckinTitle,
          prompt: commitmentCheckinPrompt,
          options: [
            for (final o in commitmentCheckinOptions) (label: o.label, value: o.response),
          ],
          selected: response,
          onSelect: (r) => setState(() => _controller.selectCheckinResponse(r)),
          trailing: response == null || response == CheckinResponse.yes
              ? null
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(commitmentBlockerPrompt, style: LevelsType.invitation),
                    const SizedBox(height: LevelsSpace.space12),
                    TextField(
                      controller: _blockerText,
                      style: LevelsType.body,
                      maxLines: 3,
                      decoration: const InputDecoration(hintText: 'In your own words…'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
        );
    }
  }
}
