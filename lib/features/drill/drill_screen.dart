import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';
import 'drill_controller.dart';
import 'drill_questions.dart';
import 'drill_tokens.dart';

/// Phase 3 flow: three structured diagnostic questions (origin type, domain,
/// coping mechanism), each paired with a free-text elaboration. Q1's
/// free-text prompt is the user's own bridge question from Phase 2 — the
/// Phase 2->3 hand-off seam; Q2 and Q3 use the static prompts in
/// `drill_questions.dart`. One "Continue"/"Finish" CTA per page; selecting an
/// answer alone does not advance (unlike Phase 1) because a free-text answer
/// is also required.
///
/// Visual treatment: design-system/MASTER.md §1, §2. No zone context on this
/// screen (that lives on the Phase 2 reveal) — `neutralAccent`, no glow,
/// matching `AssessmentScreen`.
class DrillScreen extends StatefulWidget {
  const DrillScreen({super.key, required this.loopId});

  final String loopId;

  @override
  State<DrillScreen> createState() => _DrillScreenState();
}

class _DrillScreenState extends State<DrillScreen> {
  late final DrillController _controller;
  final PageController _pageController = PageController();
  final TextEditingController _q1Text = TextEditingController();
  final TextEditingController _q2Text = TextEditingController();
  final TextEditingController _q3Text = TextEditingController();
  int _currentPage = 0;

  static const int pageCount = 3;

  @override
  void initState() {
    super.initState();
    _controller = DrillController(loopId: widget.loopId);
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    _q1Text.dispose();
    _q2Text.dispose();
    _q3Text.dispose();
    super.dispose();
  }

  void _goBackOnePage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _onContinue() async {
    if (_currentPage < pageCount - 1) {
      await _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      await _submit();
    }
  }

  Future<void> _submit() async {
    try {
      await _controller.submit();
      if (!mounted) return;
      context.go('/');
    } catch (error) {
      if (!mounted) return;
      // Surface the full error string — never swallow it.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $error')),
      );
    }
  }

  bool get _canContinue {
    switch (_currentPage) {
      case 0:
        return _controller.originType != null &&
            _q1Text.text.trim().isNotEmpty;
      case 1:
        return _controller.originDomain != null &&
            _q2Text.text.trim().isNotEmpty;
      default:
        return _controller.copingMechanism != null &&
            _q3Text.text.trim().isNotEmpty;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final loading = _controller.loading;
        final error = _controller.error;
        final submitting = _controller.submitting;
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: _currentPage > 0
                ? IconButton(
                    tooltip: 'Previous question',
                    icon: const Icon(Icons.arrow_back, color: LevelsColors.textSecondary),
                    onPressed: submitting ? null : _goBackOnePage,
                  )
                : IconButton(
                    tooltip: 'Exit drill',
                    icon: const Icon(Icons.close, color: LevelsColors.textSecondary),
                    onPressed: () => context.go('/'),
                  ),
            title: Text('Question ${_currentPage + 1} of $pageCount', style: LevelsType.caption),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / pageCount,
                color: LevelsColors.neutralAccent,
                backgroundColor: LevelsColors.glassStroke,
              ),
            ),
          ),
          body: AuroraBackdrop(
            child: loading
                ? const Center(child: BreathingDot())
                : error != null
                    ? _DrillErrorView(error: error, onRetry: _controller.load)
                    : submitting
                        ? const Center(child: BreathingDot())
                        : PageView(
                            controller: _pageController,
                            // Continue/Finish drives navigation; swiping
                            // would let users skip the free-text answer.
                            physics: const NeverScrollableScrollPhysics(),
                            onPageChanged: (page) => setState(() => _currentPage = page),
                            children: [
                              _DrillQuestionPage<OriginType>(
                                title: originTypeTitle,
                                prompt: originTypePrompt,
                                options: [
                                  for (final o in originTypeOptions) (label: o.label, value: o.type),
                                ],
                                selected: _controller.originType,
                                onSelect: _controller.selectOriginType,
                                freeTextPrompt: _controller.bridgeQuestion ?? '',
                                freeTextController: _q1Text,
                                onFreeTextChanged: _controller.setQ1FreeText,
                              ),
                              _DrillQuestionPage<OriginDomain>(
                                title: originDomainTitle,
                                prompt: originDomainPrompt,
                                options: [
                                  for (final o in originDomainOptions) (label: o.label, value: o.domain),
                                ],
                                selected: _controller.originDomain,
                                onSelect: _controller.selectOriginDomain,
                                freeTextPrompt: originDomainFreeTextPrompt,
                                freeTextController: _q2Text,
                                onFreeTextChanged: _controller.setQ2FreeText,
                              ),
                              _DrillQuestionPage<CopingMechanism>(
                                title: copingMechanismTitle,
                                prompt: copingMechanismPrompt,
                                options: [
                                  for (final o in copingMechanismOptions) (label: o.label, value: o.mechanism),
                                ],
                                selected: _controller.copingMechanism,
                                onSelect: _controller.selectCopingMechanism,
                                freeTextPrompt: copingMechanismFreeTextPrompt,
                                freeTextController: _q3Text,
                                onFreeTextChanged: _controller.setQ3FreeText,
                              ),
                            ],
                          ),
          ),
          bottomNavigationBar: loading || error != null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(LevelsSpace.screenGutter),
                    child: FilledButton(
                      onPressed: submitting || !_canContinue ? null : _onContinue,
                      child: Text(_currentPage < pageCount - 1 ? 'Continue' : 'Finish'),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

/// One structured question + free-text elaboration, generic over the answer
/// token type ([OriginType], [OriginDomain], [CopingMechanism]).
class _DrillQuestionPage<T> extends StatelessWidget {
  const _DrillQuestionPage({
    super.key,
    required this.title,
    required this.prompt,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.freeTextPrompt,
    required this.freeTextController,
    required this.onFreeTextChanged,
  });

  final String title;
  final String prompt;
  final List<({String label, T value})> options;
  final T? selected;
  final ValueChanged<T> onSelect;
  final String freeTextPrompt;
  final TextEditingController freeTextController;
  final ValueChanged<String> onFreeTextChanged;

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
              Text(title, style: LevelsType.panelTitle.copyWith(color: LevelsColors.textSecondary)),
              const SizedBox(height: LevelsSpace.space8),
              Text(prompt, style: LevelsType.displayTitle),
              const SizedBox(height: LevelsSpace.space24),
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(bottom: LevelsSpace.space12),
                  child: _OptionCard(
                    label: option.label,
                    selected: option.value == selected,
                    onTap: () => onSelect(option.value),
                  ),
                ),
              const SizedBox(height: LevelsSpace.space24),
              if (freeTextPrompt.isNotEmpty) ...[
                Text(freeTextPrompt, style: LevelsType.invitation),
                const SizedBox(height: LevelsSpace.space12),
                TextField(
                  controller: freeTextController,
                  style: LevelsType.body,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'In your own words…'),
                  onChanged: onFreeTextChanged,
                ),
              ],
              const SizedBox(height: LevelsSpace.space64),
            ],
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
                color: selected ? LevelsColors.neutralAccent : LevelsColors.glassStroke,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: LevelsSpace.space16,
            vertical: LevelsSpace.space16,
          ),
          child: Text(label, style: LevelsType.body),
        ),
      ),
    );
  }
}

class _DrillErrorView extends StatelessWidget {
  const _DrillErrorView({required this.error, required this.onRetry});

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
            const Icon(Icons.error_outline, size: 32, color: LevelsColors.textSecondary),
            const SizedBox(height: LevelsSpace.space16),
            Text(
              'Could not load your origin drill.',
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
