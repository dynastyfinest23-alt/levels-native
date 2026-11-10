import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/answer_card.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';
import 'assessment_controller.dart';
import 'questions.dart';
import 'scoring.dart';

/// Phase 1 flow: one question per page, one tap per answer to advance.
/// Selecting an answer on the last page triggers the single submit path.
///
/// Visual treatment: design-system/MASTER.md §1, §2. No zone is known yet
/// (that's Phase 2's reveal) — `neutralAccent` throughout, no glow.
class AssessmentScreen extends StatefulWidget {
  const AssessmentScreen({super.key});

  @override
  State<AssessmentScreen> createState() => _AssessmentScreenState();
}

class _AssessmentScreenState extends State<AssessmentScreen> {
  final AssessmentController _controller = AssessmentController();
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _submitError;

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onAnswerTap(int questionIndex, P1Answer answer) async {
    if (_controller.submitting) return;
    _controller.selectAnswer(questionIndex, answer);
    if (questionIndex < AssessmentController.questionCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      await _submit();
    }
  }

  Future<void> _submit() async {
    setState(() => _submitError = null);
    try {
      final result = await _controller.submit();
      if (!mounted) return;
      context.go('/dashboard/${result.loopId}');
    } catch (error) {
      if (!mounted) return;
      // Surface the full error string — never swallow it.
      setState(() => _submitError = error.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $error')),
      );
    }
  }

  void _goBackOnePage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                tooltip: 'Previous question',
                icon: const Icon(Icons.arrow_back, color: LevelsColors.textSecondary),
                onPressed: _controller.submitting ? null : _goBackOnePage,
              )
            : IconButton(
                tooltip: 'Exit assessment',
                icon: const Icon(Icons.close, color: LevelsColors.textSecondary),
                onPressed: () => context.go('/'),
              ),
        title: Text(
          'Question ${_currentPage + 1} of '
          '${AssessmentController.questionCount}',
          style: LevelsType.caption,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => LinearProgressIndicator(
              value: (_currentPage + 1) / AssessmentController.questionCount,
              color: LevelsColors.neutralAccent,
              backgroundColor: LevelsColors.glassStroke,
            ),
          ),
        ),
      ),
      body: AuroraBackdrop(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            if (_controller.submitting) {
              return const _SubmittingView();
            }
            if (_submitError != null) {
              return _SubmitErrorView(
                error: _submitError!,
                onRetry: _submit,
              );
            }
            return PageView.builder(
              controller: _pageController,
              // Answer taps drive navigation; swiping would let users skip
              // questions without answering.
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemCount: assessmentQuestions.length,
              itemBuilder: (context, index) => _QuestionPage(
                question: assessmentQuestions[index],
                selected: _controller.answerFor(index),
                onTap: (answer) => _onAnswerTap(index, answer),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _QuestionPage extends StatelessWidget {
  const _QuestionPage({
    required this.question,
    required this.selected,
    required this.onTap,
  });

  final AssessmentQuestion question;
  final P1Answer? selected;
  final ValueChanged<P1Answer> onTap;

  @override
  Widget build(BuildContext context) {
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
              Text(
                question.title,
                style: LevelsType.panelTitle.copyWith(color: LevelsColors.textSecondary),
              ),
              const SizedBox(height: LevelsSpace.space8),
              Text(question.prompt, style: LevelsType.displayTitle),
              const SizedBox(height: LevelsSpace.space24),
              for (final option in question.options)
                Padding(
                  padding: const EdgeInsets.only(bottom: LevelsSpace.space12),
                  child: AnswerCard(
                    label: option.label,
                    selected: option.answer == selected,
                    onTap: () => onTap(option.answer),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Deliberately shows no number: the first sight of the score is the
/// dashboard reveal (design review 2026-11-09, issue 21). The client-mirror
/// `previewScore` stays on the controller for the scoring mirror contract.
class _SubmittingView extends StatelessWidget {
  const _SubmittingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BreathingDot(),
          const SizedBox(height: LevelsSpace.space24),
          Text(
            'Reading your answers…',
            style: LevelsType.body.copyWith(color: LevelsColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SubmitErrorView extends StatelessWidget {
  const _SubmitErrorView({required this.error, required this.onRetry});

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
              'Your answers were not saved.',
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
              child: const Text('Retry submission'),
            ),
          ],
        ),
      ),
    );
  }
}
