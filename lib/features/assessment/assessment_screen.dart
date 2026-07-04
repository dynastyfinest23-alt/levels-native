import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'assessment_controller.dart';
import 'questions.dart';
import 'scoring.dart';

/// Phase 1 flow: one question per page, one tap per answer to advance.
/// Selecting an answer on the last page triggers the single submit path.
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
      context.go('/assessment/result', extra: result);
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
      appBar: AppBar(
        leading: _currentPage > 0
            ? IconButton(
                tooltip: 'Previous question',
                icon: const Icon(Icons.arrow_back),
                onPressed: _controller.submitting ? null : _goBackOnePage,
              )
            : IconButton(
                tooltip: 'Exit assessment',
                icon: const Icon(Icons.close),
                onPressed: () => context.go('/'),
              ),
        title: Text(
          'Question ${_currentPage + 1} of '
          '${AssessmentController.questionCount}',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => LinearProgressIndicator(
              value:
                  (_currentPage + 1) / AssessmentController.questionCount,
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.submitting) {
            return _SubmittingView(previewScore: _controller.previewScore);
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
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(question.title, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(question.prompt, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 24),
          for (final option in question.options)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AnswerCard(
                label: option.label,
                selected: option.answer == selected,
                onTap: () => onTap(option.answer),
              ),
            ),
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: selected ? colors.primaryContainer : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ),
    );
  }
}

class _SubmittingView extends StatelessWidget {
  const _SubmittingView({required this.previewScore});

  final double? previewScore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            'Computing your Center of Gravity…',
            style: theme.textTheme.titleMedium,
          ),
          if (previewScore != null) ...[
            const SizedBox(height: 8),
            // Client-mirror preview only; the database result replaces it.
            Text(
              'Provisional: ~${previewScore!.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
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
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Your answers were not saved.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Retry submission'),
            ),
          ],
        ),
      ),
    );
  }
}
