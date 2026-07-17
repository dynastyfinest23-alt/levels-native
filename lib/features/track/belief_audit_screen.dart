import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';
import '../drill/drill_tokens.dart' show AscensionTrack;
import 'track_content.dart';
import 'track_session_controller.dart';
import 'track_widgets.dart';

/// belief_audit track flow (PRD M4.4): flag a belief, then work it through
/// authorship (when/where it came from) and a cross-exam verdict
/// (fact/conclusion) — repeating for up to
/// `TrackSessionController.maxBeliefCount` beliefs (min
/// `TrackSessionController.minBeliefCount`), per the approved belief-count
/// cap (`ACTION-FOR-NOAH.md`, approved 2026-07-16). All four arrays
/// (`flagged_beliefs`/`belief_authorship_age`/`belief_authorship_source`/
/// `cross_exam_verdict`) are only ever written together, fully aligned, by
/// `TrackSessionController.saveBeliefAuditStage` — nothing is persisted
/// mid-flow.
///
/// Unlike `CompletionScreen`/`CommitmentScreen`, back navigation is only
/// offered within the belief currently being worked — stepping back across
/// a belief boundary would mean silently un-flagging a completed belief,
/// which this screen does not attempt (out of scope; not required by PRD).
class BeliefAuditScreen extends StatefulWidget {
  const BeliefAuditScreen({super.key, required this.loopId});

  final String loopId;

  @override
  State<BeliefAuditScreen> createState() => _BeliefAuditScreenState();
}

enum _Stage { flag, authorshipAge, authorshipSource, crossExam }

class _BeliefAuditScreenState extends State<BeliefAuditScreen> {
  late final TrackSessionController _controller;
  final TextEditingController _beliefText = TextEditingController();
  final TextEditingController _ageText = TextEditingController();
  final TextEditingController _sourceText = TextEditingController();
  _Stage _stage = _Stage.flag;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TrackSessionController(
      loopId: widget.loopId,
      track: AscensionTrack.beliefAudit,
    );
    _controller.load().then((_) => _resolveInitialStage());
  }

  @override
  void dispose() {
    _controller.dispose();
    _beliefText.dispose();
    _ageText.dispose();
    _sourceText.dispose();
    super.dispose();
  }

  int get _currentBeliefIndex => _controller.flaggedBeliefs.length - 1;

  void _resolveInitialStage() {
    if (!mounted || _controller.error != null) return;
    if (_controller.isBeliefAuditStageComplete) {
      // A prior visit already flagged, authored, and cross-examined a
      // fully aligned set — resume means finishing the interrupted save.
      _finish();
      return;
    }
    // Otherwise nothing durable exists yet for this track (see class doc:
    // belief data is never partially persisted) — always start fresh.
    setState(() => _stage = _Stage.flag);
  }

  void _goBack() {
    setState(() {
      _stage = switch (_stage) {
        _Stage.flag => _Stage.flag,
        _Stage.authorshipAge => _Stage.flag,
        _Stage.authorshipSource => _Stage.authorshipAge,
        _Stage.crossExam => _Stage.authorshipSource,
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

  void _continueFromFlag() {
    _controller.addFlaggedBelief(_beliefText.text.trim());
    _beliefText.clear();
    setState(() => _stage = _Stage.authorshipAge);
  }

  void _continueFromAge() {
    setState(() => _stage = _Stage.authorshipSource);
  }

  void _continueFromSource() {
    _controller.setBeliefAuthorship(
      _currentBeliefIndex,
      age: int.parse(_ageText.text.trim()),
      source: _sourceText.text.trim(),
    );
    _ageText.clear();
    _sourceText.clear();
    setState(() => _stage = _Stage.crossExam);
  }

  void _addAnotherBelief() {
    setState(() => _stage = _Stage.flag);
  }

  Future<void> _finish() => _runGuarded(() async {
        await _controller.saveBeliefAuditStage();
        await _controller.finishBeliefAudit();
        if (!mounted) return;
        context.go('/');
      });

  bool get _canContinue {
    switch (_stage) {
      case _Stage.flag:
        return _beliefText.text.trim().isNotEmpty;
      case _Stage.authorshipAge:
        final age = int.tryParse(_ageText.text.trim());
        return age != null && age > 0;
      case _Stage.authorshipSource:
        return _sourceText.text.trim().isNotEmpty;
      case _Stage.crossExam:
        return _controller.crossExamVerdict[_currentBeliefIndex] != null;
    }
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
              tooltip: _stage == _Stage.flag ? 'Exit' : 'Back',
              icon: Icon(
                _stage == _Stage.flag ? Icons.close : Icons.arrow_back,
                color: LevelsColors.textSecondary,
              ),
              onPressed: _submitting
                  ? null
                  : (_stage == _Stage.flag
                      ? () => context.go('/')
                      : _goBack),
            ),
            title: !loading && error == null
                ? Text(
                    'Belief ${_controller.flaggedBeliefs.length + (_stage == _Stage.flag ? 1 : 0)} '
                    'of up to ${TrackSessionController.maxBeliefCount}',
                    style: LevelsType.caption,
                  )
                : null,
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
                              key: ValueKey((_stage, _currentBeliefIndex)),
                              child: _buildStage(),
                            ),
                          ),
          ),
          bottomNavigationBar:
              loading || error != null ? null : _buildBottomBar(),
        );
      },
    );
  }

  Widget _buildBottomBar() {
    if (_stage == _Stage.crossExam && _controller.canAddMoreBeliefs) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LevelsSpace.screenGutter),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _submitting || !_canContinue
                      ? null
                      : _addAnotherBelief,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LevelsColors.textPrimary,
                    side: const BorderSide(color: LevelsColors.glassStroke),
                    shape: const StadiumBorder(),
                    textStyle: LevelsType.button,
                    padding: const EdgeInsets.symmetric(
                      vertical: LevelsSpace.space16,
                    ),
                  ),
                  child: const Text('Add another belief'),
                ),
              ),
              const SizedBox(width: LevelsSpace.space12),
              Expanded(
                child: FilledButton(
                  onPressed: _submitting || !_canContinue ? null : _finish,
                  child: const Text('Finish'),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(LevelsSpace.screenGutter),
        child: FilledButton(
          onPressed: _submitting || !_canContinue ? null : _onContinue,
          child: Text(_stage == _Stage.crossExam ? 'Finish' : 'Continue'),
        ),
      ),
    );
  }

  VoidCallback? get _onContinue {
    return switch (_stage) {
      _Stage.flag => _continueFromFlag,
      _Stage.authorshipAge => _continueFromAge,
      _Stage.authorshipSource => _continueFromSource,
      _Stage.crossExam => () => _finish(),
    };
  }

  Widget _buildStage() {
    switch (_stage) {
      case _Stage.flag:
        return TrackTextStage(
          title: beliefFlagTitle,
          prompt: beliefFlagPrompt,
          controller: _beliefText,
          onChanged: (_) => setState(() {}),
          maxLines: 2,
        );
      case _Stage.authorshipAge:
        return TrackTextStage(
          title: beliefAuthorshipAgeTitle,
          prompt: beliefAuthorshipAgePrompt,
          controller: _ageText,
          onChanged: (_) => setState(() {}),
          maxLines: 1,
          keyboardType: TextInputType.number,
          hintText: 'Age…',
        );
      case _Stage.authorshipSource:
        return TrackTextStage(
          title: beliefAuthorshipSourceTitle,
          prompt: beliefAuthorshipSourcePrompt,
          controller: _sourceText,
          onChanged: (_) => setState(() {}),
          maxLines: 2,
        );
      case _Stage.crossExam:
        return TrackOptionListStage(
          title: beliefCrossExamTitle,
          prompt: beliefCrossExamPrompt,
          options: [
            for (final o in beliefCrossExamOptions) (label: o.label, value: o.verdict),
          ],
          selected: _controller.crossExamVerdict[_currentBeliefIndex],
          onSelect: (v) =>
              setState(() => _controller.setCrossExamVerdict(_currentBeliefIndex, v)),
        );
    }
  }
}
