import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/aurora_backdrop.dart';
import '../../core/widgets/breathing_dot.dart';
import '../drill/drill_tokens.dart' show AscensionTrack;
import 'embodiment_daily_log_controller.dart';
import 'embodiment_gate.dart';
import 'track_content.dart';
import 'track_session_controller.dart';
import 'track_tokens.dart';
import 'track_widgets.dart';

/// embodiment track flow (PRD M4.5): the one-time session screen
/// (`body_location_tapped`/`sensation_words`/`stage4_response` on
/// `phase4_track_sessions`, via `TrackSessionController`), then — same
/// visit for day 1, a later visit each day after — the daily check-in
/// against `embodiment_daily_logs` (via `EmbodimentDailyLogController`),
/// gated by `embodimentDayGate` (calendar-anchored, no backfill for
/// skipped days). Day 7's confirmation writes
/// `TrackSessionController.finishEmbodiment` — the only place this track's
/// `success_state_reached` is decided.
///
/// The "already logged today" / "window elapsed" states below are plain
/// functional chrome (not narrative copy from `track_content.dart`, which
/// has no prompts for them) — same precedent as router.dart's "Coming
/// soon." placeholder; flagged in `ACTION-FOR-NOAH.md`.
class EmbodimentScreen extends StatefulWidget {
  const EmbodimentScreen({super.key, required this.loopId});

  final String loopId;

  @override
  State<EmbodimentScreen> createState() => _EmbodimentScreenState();
}

enum _SessionStage { location, sensation, stage4 }

enum _DailyStage { check, day6Delta, day7Action, day7Confirm }

class _EmbodimentScreenState extends State<EmbodimentScreen> {
  late final TrackSessionController _session;
  EmbodimentDailyLogController? _daily;

  final TextEditingController _locationText = TextEditingController();
  final TextEditingController _sensationText = TextEditingController();
  final TextEditingController _day7ActionText = TextEditingController();

  bool _inDailyPhase = false;
  _SessionStage _sessionStage = _SessionStage.location;
  _DailyStage _dailyStage = _DailyStage.check;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _session = TrackSessionController(
      loopId: widget.loopId,
      track: AscensionTrack.embodiment,
    );
    _session.load().then((_) => _resolveAfterSessionLoad());
  }

  @override
  void dispose() {
    _session.dispose();
    _daily?.dispose();
    _locationText.dispose();
    _sensationText.dispose();
    _day7ActionText.dispose();
    super.dispose();
  }

  void _resolveAfterSessionLoad() {
    if (!mounted || _session.error != null) return;
    if (_session.isEmbodimentSessionStageComplete) {
      _enterDailyPhase();
    } else {
      setState(() {
        _inDailyPhase = false;
        _sessionStage = _SessionStage.location;
      });
    }
  }

  void _enterDailyPhase() {
    final daily = EmbodimentDailyLogController(
      sessionId: _session.sessionId!,
      startedAt: _session.startedAt!,
    );
    daily.load().then((_) {
      if (!mounted) return;
      setState(() => _dailyStage = _DailyStage.check);
    });
    setState(() {
      _inDailyPhase = true;
      _daily = daily;
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

  // --- session screen navigation ---

  void _goBackSession() {
    setState(() {
      _sessionStage = switch (_sessionStage) {
        _SessionStage.location => _SessionStage.location,
        _SessionStage.sensation => _SessionStage.location,
        _SessionStage.stage4 => _SessionStage.sensation,
      };
    });
  }

  void _continueFromLocation() {
    _session.setBodyLocationTapped(_locationText.text.trim());
    setState(() => _sessionStage = _SessionStage.sensation);
  }

  void _continueFromSensation() {
    final words = _sensationText.text
        .split(',')
        .map((w) => w.trim())
        .where((w) => w.isNotEmpty)
        .toList();
    _session.setSensationWords(words);
    setState(() => _sessionStage = _SessionStage.stage4);
  }

  Future<void> _finishSessionScreen() => _runGuarded(() async {
        await _session.saveEmbodimentSessionStage();
        if (!mounted) return;
        _enterDailyPhase();
      });

  bool get _canContinueSession {
    switch (_sessionStage) {
      case _SessionStage.location:
        return _locationText.text.trim().isNotEmpty;
      case _SessionStage.sensation:
        return _sensationText.text.trim().isNotEmpty;
      case _SessionStage.stage4:
        return _session.stage4Response != null;
    }
  }

  VoidCallback? get _onContinueSession {
    if (_submitting || _session.saving || !_canContinueSession) return null;
    return switch (_sessionStage) {
      _SessionStage.location => _continueFromLocation,
      _SessionStage.sensation => _continueFromSensation,
      _SessionStage.stage4 => () => _finishSessionScreen(),
    };
  }

  // --- daily flow navigation ---

  Future<void> _saveAndGoHome(EmbodimentDailyLogController daily) =>
      _runGuarded(() async {
        await daily.saveDayLog();
        if (!mounted) return;
        context.go('/');
      });

  Future<void> _finishWeek(EmbodimentDailyLogController daily) =>
      _runGuarded(() async {
        await daily.saveDayLog();
        await _session.finishEmbodiment(
          day7ActionConfirmed: daily.day7ActionConfirmed!,
        );
        if (!mounted) return;
        context.go('/');
      });

  void _continueFromDailyCheck(EmbodimentDailyLogController daily) {
    final day = daily.gate!.dayNumber!;
    if (day == 6) {
      setState(() => _dailyStage = _DailyStage.day6Delta);
    } else if (day == 7) {
      setState(() => _dailyStage = _DailyStage.day7Action);
    } else {
      _saveAndGoHome(daily);
    }
  }

  bool _canContinueDaily(EmbodimentDailyLogController daily) {
    switch (_dailyStage) {
      case _DailyStage.check:
        return daily.isDayCheckComplete;
      case _DailyStage.day6Delta:
        return daily.isDay6Complete;
      case _DailyStage.day7Action:
        return daily.isDay7ActionCommittedComplete;
      case _DailyStage.day7Confirm:
        return daily.isDay7ConfirmComplete;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        if (_session.loading) {
          return const Scaffold(body: Center(child: BreathingDot()));
        }
        if (_session.error != null) {
          return Scaffold(
            body: TrackErrorView(
              message: 'Could not load your track.',
              error: _session.error!,
              onRetry: _session.load,
            ),
          );
        }
        if (!_inDailyPhase) {
          return _buildSessionScreen();
        }
        final daily = _daily!;
        return ListenableBuilder(
          listenable: daily,
          builder: (context, _) => _buildDailyScreen(daily),
        );
      },
    );
  }

  Widget _buildSessionScreen() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: _sessionStage == _SessionStage.location ? 'Exit' : 'Back',
          icon: Icon(
            _sessionStage == _SessionStage.location
                ? Icons.close
                : Icons.arrow_back,
            color: LevelsColors.textSecondary,
          ),
          onPressed: _submitting
              ? null
              : (_sessionStage == _SessionStage.location
                  ? () => context.go('/')
                  : _goBackSession),
        ),
      ),
      body: AuroraBackdrop(
        child: _submitting
            ? const Center(child: BreathingDot())
            : AnimatedSwitcher(
                duration: LevelsMotion.reveal,
                switchInCurve: LevelsMotion.revealCurve,
                switchOutCurve: LevelsMotion.revealCurve,
                child: KeyedSubtree(
                  key: ValueKey(_sessionStage),
                  child: _buildSessionStage(),
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LevelsSpace.screenGutter),
          child: FilledButton(
            onPressed: _onContinueSession,
            child: const Text('Continue'),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionStage() {
    switch (_sessionStage) {
      case _SessionStage.location:
        return TrackTextStage(
          title: embodimentLocationTitle,
          prompt: embodimentLocationPrompt,
          controller: _locationText,
          onChanged: (_) => setState(() {}),
          maxLines: 2,
        );
      case _SessionStage.sensation:
        return TrackTextStage(
          title: embodimentSensationTitle,
          prompt: embodimentSensationPrompt,
          controller: _sensationText,
          onChanged: (_) => setState(() {}),
          maxLines: 2,
        );
      case _SessionStage.stage4:
        return TrackOptionListStage(
          title: embodimentStage4Title,
          prompt: embodimentStage4Prompt,
          options: [
            for (final o in embodimentStage4Options) (label: o.label, value: o.response),
          ],
          selected: _session.stage4Response,
          onSelect: (v) => setState(() => _session.selectStage4Response(v)),
        );
    }
  }

  Widget _buildDailyScreen(EmbodimentDailyLogController daily) {
    if (daily.loading) {
      return const Scaffold(body: Center(child: BreathingDot()));
    }
    if (daily.error != null) {
      return Scaffold(
        body: TrackErrorView(
          message: "Could not load today's check-in.",
          error: daily.error!,
          onRetry: daily.load,
        ),
      );
    }
    final gate = daily.gate!;
    if (gate.status == EmbodimentDayStatus.windowElapsed) {
      return const _EmbodimentStatusScreen(
        title: 'Embodiment week',
        message: "This 7-day window has closed.",
      );
    }
    if (gate.status == EmbodimentDayStatus.alreadyLoggedToday) {
      return _EmbodimentStatusScreen(
        title: "Day ${gate.dayNumber} of 7",
        message: "You've already logged today. Come back tomorrow.",
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Exit',
          icon: const Icon(Icons.close, color: LevelsColors.textSecondary),
          onPressed: _submitting ? null : () => context.go('/'),
        ),
        title: Text('Day ${gate.dayNumber} of 7', style: LevelsType.caption),
      ),
      body: AuroraBackdrop(
        child: _submitting
            ? const Center(child: BreathingDot())
            : AnimatedSwitcher(
                duration: LevelsMotion.reveal,
                switchInCurve: LevelsMotion.revealCurve,
                switchOutCurve: LevelsMotion.revealCurve,
                child: KeyedSubtree(
                  key: ValueKey(_dailyStage),
                  child: _buildDailyStage(daily, gate.dayNumber!),
                ),
              ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(LevelsSpace.screenGutter),
          child: FilledButton(
            onPressed: _submitting || daily.saving || !_canContinueDaily(daily)
                ? null
                : _onContinueDaily(daily),
            child: Text(_dailyButtonLabel(daily, gate.dayNumber!)),
          ),
        ),
      ),
    );
  }

  VoidCallback _onContinueDaily(EmbodimentDailyLogController daily) {
    return switch (_dailyStage) {
      _DailyStage.check => () => _continueFromDailyCheck(daily),
      _DailyStage.day6Delta => () => _saveAndGoHome(daily),
      _DailyStage.day7Action => () =>
          setState(() => _dailyStage = _DailyStage.day7Confirm),
      _DailyStage.day7Confirm => () => _finishWeek(daily),
    };
  }

  /// "Save" when this stage is the terminal action for today (day 1-5's
  /// check, day 6's delta) — matches `CommitmentScreen`'s declaration
  /// stage, which uses "Save" rather than "Finish" for exactly this
  /// reason. "Continue" when more stages follow this same visit (day 6/7's
  /// check, day 7's action). "Finish" only on day 7's true confirmation.
  String _dailyButtonLabel(EmbodimentDailyLogController daily, int dayNumber) {
    switch (_dailyStage) {
      case _DailyStage.check:
        return dayNumber < 6 ? 'Save' : 'Continue';
      case _DailyStage.day6Delta:
        return 'Save';
      case _DailyStage.day7Action:
        return 'Continue';
      case _DailyStage.day7Confirm:
        return 'Finish';
    }
  }

  Widget _buildDailyStage(EmbodimentDailyLogController daily, int dayNumber) {
    switch (_dailyStage) {
      case _DailyStage.check:
        return _DailyCheckStage(
          statement: daily.todaysIdentityStatement!,
          selected: daily.bodyResponse,
          onSelect: (v) => setState(() => daily.selectBodyResponse(v)),
        );
      case _DailyStage.day6Delta:
        return TrackOptionListStage(
          title: embodimentDay6DeltaTitle,
          prompt: embodimentDay6DeltaPrompt,
          options: [
            for (final o in embodimentDay6DeltaOptions) (label: o.label, value: o.delta),
          ],
          selected: daily.day6Delta,
          onSelect: (v) => setState(() => daily.selectDay6Delta(v)),
        );
      case _DailyStage.day7Action:
        return TrackTextStage(
          title: embodimentDay7ActionTitle,
          prompt: embodimentDay7ActionPrompt,
          controller: _day7ActionText,
          onChanged: (v) => setState(() => daily.setDay7ActionCommitted(v)),
          maxLines: 2,
        );
      case _DailyStage.day7Confirm:
        return _Day7ConfirmStage(
          confirmed: daily.day7ActionConfirmed,
          onSelect: (v) => setState(() => daily.setDay7ActionConfirmed(v)),
        );
    }
  }
}

class _DailyCheckStage extends StatelessWidget {
  const _DailyCheckStage({
    required this.statement,
    required this.selected,
    required this.onSelect,
  });

  final String statement;
  final BodyResponse? selected;
  final ValueChanged<BodyResponse> onSelect;

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
              Text(statement, style: LevelsType.invitation),
              const SizedBox(height: LevelsSpace.space32),
              Text(
                embodimentBodyResponseTitle,
                style: LevelsType.panelTitle.copyWith(color: LevelsColors.textSecondary),
              ),
              const SizedBox(height: LevelsSpace.space8),
              Text(embodimentBodyResponsePrompt, style: LevelsType.displayTitle),
              const SizedBox(height: LevelsSpace.space24),
              for (final option in embodimentBodyResponseOptions)
                Padding(
                  padding: const EdgeInsets.only(bottom: LevelsSpace.space12),
                  child: TrackOptionCard(
                    label: option.label,
                    selected: option.response == selected,
                    onTap: () => onSelect(option.response),
                  ),
                ),
              const SizedBox(height: LevelsSpace.space64),
            ],
          ),
        ),
      ),
    );
  }
}

class _Day7ConfirmStage extends StatelessWidget {
  const _Day7ConfirmStage({required this.confirmed, required this.onSelect});

  final bool? confirmed;
  final ValueChanged<bool> onSelect;

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
                embodimentDay7ConfirmTitle,
                style: LevelsType.panelTitle.copyWith(color: LevelsColors.textSecondary),
              ),
              const SizedBox(height: LevelsSpace.space8),
              Text(embodimentDay7ConfirmPrompt, style: LevelsType.displayTitle),
              const SizedBox(height: LevelsSpace.space24),
              TrackOptionCard(
                label: 'Yes',
                selected: confirmed == true,
                onTap: () => onSelect(true),
              ),
              const SizedBox(height: LevelsSpace.space12),
              TrackOptionCard(
                label: 'No',
                selected: confirmed == false,
                onTap: () => onSelect(false),
              ),
              const SizedBox(height: LevelsSpace.space64),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain functional status view (already-logged-today / window-elapsed) —
/// see class doc for why this isn't gate-reviewed narrative copy.
class _EmbodimentStatusScreen extends StatelessWidget {
  const _EmbodimentStatusScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: LevelsType.displayTitle),
            const SizedBox(height: LevelsSpace.space8),
            Text(
              message,
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
