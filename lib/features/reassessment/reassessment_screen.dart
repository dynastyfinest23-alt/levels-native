import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';
import '../journey/journey_repository.dart';
import 'reassessment_controller.dart';
import 'reassessment_questions.dart';
import 'reassessment_tokens.dart';

/// Phase 5 check-in at `/reassessment/:loopId/:window` (PRD M5.2).
///
/// The screen is gated: it only mounts the question flow when the loop's own
/// window is actually open (Window 2 = loop days 5-7, Window 3 = day 21+,
/// computed from `ascension_loops.started_at` by [LoopState]) and unanswered.
/// The home hub only links here when the gate is open; this check is the
/// backstop for direct URL access.
///
/// Visual treatment: design-system/MASTER.md §1, §2. No zone context on this
/// screen — `neutralAccent`, no glow, matching `DrillScreen`.
class ReassessmentScreen extends StatefulWidget {
  const ReassessmentScreen({
    super.key,
    required this.loopId,
    required this.window,
  });

  final String loopId;
  final ReassessmentWindow window;

  @override
  State<ReassessmentScreen> createState() => _ReassessmentScreenState();
}

class _ReassessmentScreenState extends State<ReassessmentScreen> {
  final JourneyRepository _repository = JourneyRepository();
  bool _loading = true;
  String? _error;
  bool _permitted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repository.fetchActiveLoop();
      if (!mounted) return;
      setState(() => _permitted = _gateOpen(data));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _gateOpen(JourneyData? data) {
    if (data == null || data.loopId != widget.loopId) return false;
    return switch (widget.window) {
      ReassessmentWindow.window2 =>
        data.loopState.window2Open && data.window2Reassessment == null,
      ReassessmentWindow.window3 => data.loopState.window3Open,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackdrop(
        child: _loading
            ? const Center(child: BreathingDot())
            : _error != null
                ? _ReassessmentErrorView(error: _error!, onRetry: _load)
                : _permitted
                    ? ReassessmentFlow(
                        loopId: widget.loopId,
                        window: widget.window,
                      )
                    : const _GateClosedView(),
      ),
    );
  }
}

/// The reassessment flow itself: three questions (Q1 trigger re-run, Q2
/// body-state re-scan, Q3 block flag) in a PageView, one submit path, then
/// the result rendered from the read-back row. Kept free of any direct
/// Supabase access (the controller owns that) so the flow is widget-testable
/// with a fake data source.
class ReassessmentFlow extends StatefulWidget {
  const ReassessmentFlow({
    super.key,
    required this.loopId,
    required this.window,
    this.controller,
  });

  final String loopId;
  final ReassessmentWindow window;

  /// Test seam — production callers leave this null and get a controller
  /// backed by [SupabaseReassessmentDataSource].
  final ReassessmentController? controller;

  @override
  State<ReassessmentFlow> createState() => ReassessmentFlowState();
}

@visibleForTesting
class ReassessmentFlowState extends State<ReassessmentFlow> {
  late final ReassessmentController _controller = widget.controller ??
      ReassessmentController(loopId: widget.loopId, window: widget.window);
  final PageController _pageController = PageController();
  final TextEditingController _rediagFreeTextController =
      TextEditingController();
  int _currentPage = 0;

  /// Set after the main submit returns `false_positive`: the id the rediag
  /// RPC needs, and the signal to mount the rediag pages. The rediag flow
  /// exists ONLY behind this flag (PRD M5.3 done-when).
  String? _rediagReassessmentId;

  /// The final read-back result, set by whichever submit path ran last.
  ReassessmentResult? _result;

  /// True once `submitRediag` succeeds — the result view then renders the
  /// post-rediag state instead of the classification copy.
  bool _finishedRediag = false;

  static const int _mainPageCount = 3;
  static const int _rediagPageCount = 4;

  int get _pageCount => _rediagReassessmentId == null
      ? _mainPageCount
      : _mainPageCount + _rediagPageCount;

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    _pageController.dispose();
    _rediagFreeTextController.dispose();
    super.dispose();
  }

  void _goBackOnePage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _onContinue() async {
    if (_currentPage < _pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else if (_rediagReassessmentId == null) {
      await _submit();
    } else {
      await _submitRediag();
    }
  }

  Future<void> _submit() async {
    try {
      final result = await _controller.submit();
      if (!mounted) return;
      if (result.classification == Phase5Classification.falsePositive) {
        // Continue into the rediag flow instead of showing a result.
        setState(() => _rediagReassessmentId = result.reassessmentId);
        await _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        setState(() => _result = result);
      }
    } catch (error) {
      if (!mounted) return;
      // Surface the full error string — never swallow it.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $error')),
      );
    }
  }

  Future<void> _submitRediag() async {
    try {
      final result = await _controller.submitRediag(_rediagReassessmentId!);
      if (!mounted) return;
      setState(() {
        _result = result;
        _finishedRediag = true;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $error')),
      );
    }
  }

  bool get _canContinue => switch (_currentPage) {
        0 => _controller.q1Answer != null,
        1 => _controller.q2Answer != null,
        2 => _controller.q3Answer != null,
        3 => _controller.rediagResistance != null,
        4 => _controller.rediagFeeling != null,
        5 => _controller.rediagPattern != null,
        // Rediag Q4 free text is optional (the RPC's free_text arg is too).
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final result = _result;
        if (result != null) {
          return _ResultView(result: result, afterRediag: _finishedRediag);
        }
        final submitting = _controller.submitting;
        final inRediag = _rediagReassessmentId != null;
        return Scaffold(
          extendBodyBehindAppBar: true,
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: _currentPage > 0
                ? IconButton(
                    tooltip: 'Previous question',
                    icon: const Icon(Icons.arrow_back,
                        color: LevelsColors.textSecondary),
                    onPressed: submitting ? null : _goBackOnePage,
                  )
                : IconButton(
                    tooltip: 'Exit check-in',
                    icon: const Icon(Icons.close,
                        color: LevelsColors.textSecondary),
                    onPressed: () => context.go('/'),
                  ),
            title: Text('Question ${_currentPage + 1} of $_pageCount',
                style: LevelsType.caption),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / _pageCount,
                color: LevelsColors.neutralAccent,
                backgroundColor: LevelsColors.glassStroke,
              ),
            ),
          ),
          body: submitting
              ? const Center(child: BreathingDot())
              : PageView(
                  controller: _pageController,
                  // Continue/Finish drives navigation, matching DrillScreen.
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentPage = page),
                  children: [
                    _QuestionPage(
                      title: reassessmentQ1Trigger.title,
                      prompt: reassessmentQ1Trigger.prompt,
                      options: [
                        for (final o in reassessmentQ1Trigger.options)
                          (label: o.label, value: o.answer),
                      ],
                      selected: _controller.q1Answer,
                      onSelect: _controller.selectQ1,
                    ),
                    _QuestionPage(
                      title: reassessmentQ2BodyState.title,
                      prompt: reassessmentQ2BodyState.prompt,
                      options: [
                        for (final o in reassessmentQ2BodyState.options)
                          (label: o.label, value: o.answer),
                      ],
                      selected: _controller.q2Answer,
                      onSelect: _controller.selectQ2,
                    ),
                    _QuestionPage(
                      title: reassessmentQ3BlockFlag.title,
                      prompt: reassessmentQ3BlockFlag.prompt,
                      options: [
                        for (final o in reassessmentQ3BlockFlag.options)
                          (label: o.label, value: o.value),
                      ],
                      selected: _controller.q3Answer,
                      onSelect: _controller.selectQ3,
                    ),
                    // Rediag pages mount only once the read-back row says
                    // false_positive (PRD M5.3).
                    if (inRediag) ...[
                      _QuestionPage(
                        title: rediagQ1Resistance.title,
                        prompt: rediagQ1Resistance.prompt,
                        options: [
                          for (final o in rediagQ1Resistance.options)
                            (label: o.label, value: o.value),
                        ],
                        selected: _controller.rediagResistance,
                        onSelect: _controller.selectRediagResistance,
                      ),
                      _QuestionPage(
                        title: rediagQ2Feeling.title,
                        prompt: rediagQ2Feeling.prompt,
                        options: [
                          for (final o in rediagQ2Feeling.options)
                            (label: o.label, value: o.value),
                        ],
                        selected: _controller.rediagFeeling,
                        onSelect: _controller.selectRediagFeeling,
                      ),
                      _QuestionPage(
                        title: rediagQ3Pattern.title,
                        prompt: rediagQ3Pattern.prompt,
                        options: [
                          for (final o in rediagQ3Pattern.options)
                            (label: o.label, value: o.value),
                        ],
                        selected: _controller.rediagPattern,
                        onSelect: _controller.selectRediagPattern,
                      ),
                      _RediagFreeTextPage(
                        controller: _rediagFreeTextController,
                        onChanged: _controller.setRediagFreeText,
                      ),
                    ],
                  ],
                ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(LevelsSpace.screenGutter),
              child: FilledButton(
                onPressed: submitting || !_canContinue ? null : _onContinue,
                child: Text(
                    _currentPage < _pageCount - 1 ? 'Continue' : 'Finish'),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Rediag Q4 — optional free text. Never sent to the LLM (product decision,
/// CLAUDE.md 2026-07-15): it goes to Postgres under RLS and nowhere else.
class _RediagFreeTextPage extends StatelessWidget {
  const _RediagFreeTextPage({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: LevelsSpace.contentMaxWidth),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: LevelsSpace.screenGutter,
              vertical: LevelsSpace.space32,
            ),
            children: [
              Text('In your own words',
                  style: LevelsType.panelTitle
                      .copyWith(color: LevelsColors.textSecondary)),
              const SizedBox(height: LevelsSpace.space8),
              const Text(rediagQ4Prompt, style: LevelsType.displayTitle),
              const SizedBox(height: LevelsSpace.space24),
              TextField(
                controller: controller,
                style: LevelsType.body,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Optional. Anything at all.',
                ),
                onChanged: onChanged,
              ),
              const SizedBox(height: LevelsSpace.space64),
            ],
          ),
        ),
      ),
    );
  }
}

/// One single-select question page, generic over the answer token type
/// ([P1Answer] for Q1/Q2, [Q3BlockFlag] for Q3, the rediag enums in M5.3).
class _QuestionPage<T> extends StatelessWidget {
  const _QuestionPage({
    required this.title,
    required this.prompt,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  final String title;
  final String prompt;
  final List<({String label, T value})> options;
  final T? selected;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: LevelsSpace.contentMaxWidth),
          // SingleChildScrollView + Column, not a lazy ListView: every
          // option card is always in the tree (no offstage marking), which
          // keeps the flow widget-testable and is cheap at this length.
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: LevelsSpace.screenGutter,
              vertical: LevelsSpace.space32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: LevelsType.panelTitle
                        .copyWith(color: LevelsColors.textSecondary)),
                const SizedBox(height: LevelsSpace.space8),
                Text(prompt, style: LevelsType.displayTitle),
                const SizedBox(height: LevelsSpace.space24),
                for (final option in options)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: LevelsSpace.space12),
                    child: _OptionCard(
                      label: option.label,
                      selected: option.value == selected,
                      onTap: () => onSelect(option.value),
                    ),
                  ),
                const SizedBox(height: LevelsSpace.space64),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.label, required this.selected, required this.onTap});

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
                color: selected
                    ? LevelsColors.neutralAccent
                    : LevelsColors.glassStroke,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          padding: const EdgeInsets.all(LevelsSpace.space16),
          child: Text(label, style: LevelsType.body),
        ),
      ),
    );
  }
}

/// The outcome, rendered from the read-back row only (never client math).
/// Classification text always comes through [ClassificationCopy.of] — raw
/// tokens never reach the UI (CLAUDE.md mechanic-leak rule). After the
/// rediag path, `rediag_classification` is deliberately NOT rendered (its
/// enum values are undocumented — see ACTION-FOR-NOAH.md); the view falls
/// back to a quiet acknowledgement plus the way home.
class _ResultView extends StatelessWidget {
  const _ResultView({required this.result, this.afterRediag = false});

  final ReassessmentResult result;
  final bool afterRediag;

  @override
  Widget build(BuildContext context) {
    final classification = result.classification;
    final copy =
        classification == null ? null : ClassificationCopy.of(classification);
    final String headline;
    final String body;
    if (afterRediag) {
      headline = 'Thank you';
      body =
          'That gives a much clearer picture. Your home screen has the '
          'right next step.';
    } else {
      headline = copy?.headline ?? 'Check-in saved';
      body = copy?.body ??
          'Your answers are in. Head home to see what is next.';
    }
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: LevelsSpace.contentMaxWidth),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(
              horizontal: LevelsSpace.screenGutter,
              vertical: LevelsSpace.space32,
            ),
            children: [
              Text(headline, style: LevelsType.displayTitle),
              const SizedBox(height: LevelsSpace.space16),
              Text(
                body,
                style:
                    LevelsType.body.copyWith(color: LevelsColors.textSecondary),
              ),
              const SizedBox(height: LevelsSpace.space32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to home'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the window is not open for this loop (wrong loop, wrong day,
/// or already answered). Functional chrome copy, same register as the
/// coming-soon placeholders.
class _GateClosedView extends StatelessWidget {
  const _GateClosedView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(LevelsSpace.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('This check-in is not open right now.',
                style: LevelsType.displayTitle, textAlign: TextAlign.center),
            const SizedBox(height: LevelsSpace.space8),
            Text(
              'It will appear on your home screen when its window opens.',
              style: LevelsType.body.copyWith(color: LevelsColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LevelsSpace.space16),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReassessmentErrorView extends StatelessWidget {
  const _ReassessmentErrorView({required this.error, required this.onRetry});

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
            const Icon(Icons.error_outline,
                size: 32, color: LevelsColors.textSecondary),
            const SizedBox(height: LevelsSpace.space16),
            Text(
              'Could not load your check-in.',
              style: LevelsType.body.copyWith(color: LevelsColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: LevelsSpace.space8),
            Text(error, style: LevelsType.caption, textAlign: TextAlign.center),
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
