/// Where a user sits within one ascension loop's five-phase journey.
///
/// `assessment` is only reached via [LoopState.noActiveLoop] — once a loop
/// row exists, Phase 1 is already scored (the loop and its
/// `phase1_assessments` row are created together in one submit path), so
/// [LoopState.compute] never produces it.
enum JourneyPhase { assessment, dashboard, drill, track, window2, window3, complete }

/// Pure, immutable snapshot of where a loop stands. Computed entirely from
/// plain inputs (loop fields, row-existence flags, the current time) — no
/// Supabase imports, so the phase-progression and window-boundary rules are
/// testable without a client. [JourneyRepository] supplies the inputs.
class LoopState {
  const LoopState({
    required this.currentPhase,
    required this.loopDay,
    required this.window2Open,
    required this.window3Open,
  });

  /// Day 5 of the loop opens the Window 2 check-in; day 7 is the last day
  /// it's open. Day 21 opens the Window 3 durability check (no close).
  static const int window2OpenDay = 5;
  static const int window2CloseDay = 7;
  static const int window3OpenDay = 21;

  final JourneyPhase currentPhase;

  /// 1-based day count from `ascension_loops.started_at` — the loop's only
  /// clock (CLAUDE.md / PRD §7).
  final int loopDay;
  final bool window2Open;
  final bool window3Open;

  /// The state before any loop exists — home shows "Begin assessment".
  factory LoopState.noActiveLoop() => const LoopState(
        currentPhase: JourneyPhase.assessment,
        loopDay: 0,
        window2Open: false,
        window3Open: false,
      );

  /// Derives the current phase and window gates for an existing loop.
  factory LoopState.compute({
    required DateTime loopStartedAt,
    required bool loopComplete,
    required bool hasPhase2View,
    required bool hasPhase3Drill,
    required bool hasPhase4Session,
    required bool hasWindow2Reassessment,
    required bool hasWindow3Reassessment,
    required DateTime now,
  }) {
    final loopDay = now.difference(loopStartedAt).inDays + 1;
    final window2Open = loopDay >= window2OpenDay && loopDay <= window2CloseDay;
    final window3Open = loopDay >= window3OpenDay;

    final JourneyPhase phase;
    if (loopComplete || hasWindow3Reassessment) {
      phase = JourneyPhase.complete;
    } else if (window3Open) {
      phase = JourneyPhase.window3;
    } else if (hasWindow2Reassessment) {
      // Window 2 answered; routing outcome (M5.4) decides the specific next
      // screen — until Window 3 opens, the general phase is "working the
      // track".
      phase = JourneyPhase.track;
    } else if (window2Open) {
      phase = JourneyPhase.window2;
    } else if (hasPhase4Session) {
      phase = JourneyPhase.track;
    } else if (hasPhase3Drill) {
      phase = JourneyPhase.track;
    } else if (hasPhase2View) {
      phase = JourneyPhase.drill;
    } else {
      phase = JourneyPhase.dashboard;
    }

    return LoopState(
      currentPhase: phase,
      loopDay: loopDay,
      window2Open: window2Open,
      window3Open: window3Open,
    );
  }
}
