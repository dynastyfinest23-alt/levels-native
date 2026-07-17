/// Pure day-gating for the embodiment track's 7-day
/// `embodiment_daily_logs` loop (PRD M4.5). No Supabase imports — testable
/// without a client, matching `lib/features/journey/loop_state.dart`'s
/// precedent for calendar-anchored phase logic.
library;

/// Which state today's embodiment check-in is in.
enum EmbodimentDayStatus {
  /// Today's day_number has no log yet — the screen should let the user
  /// complete it.
  open,

  /// Today's day_number is already logged — same-day re-entry shows it,
  /// read-only, rather than a second entry form.
  alreadyLoggedToday,

  /// More than 7 calendar days have passed since the session started —
  /// there is no day_number left to open today.
  windowElapsed,
}

class EmbodimentDayGate {
  const EmbodimentDayGate({required this.status, required this.dayNumber});

  final EmbodimentDayStatus status;

  /// 1-7, or null only when [status] is [EmbodimentDayStatus.windowElapsed].
  final int? dayNumber;
}

/// Decides which `day_number`'s slot is open today, and whether it's
/// already been logged. The gate is a fixed calendar mapping from the
/// session's start date — `dayNumber = elapsed calendar days since
/// startedAt + 1` — never "the next unlogged day", so a skipped day is
/// never offered later: there is no backfill (PRD M4.5, decided by Fable
/// 2026-07-17).
///
/// Both [startedAt] and [now] are compared as **local device calendar
/// dates** (decided 2026-07-17: the gate is behavioral — one entry per
/// waking day — not a UTC-day boundary that could flip mid-evening for the
/// user). [startedAt] is typically a UTC-aware `DateTime` read back from
/// `phase4_track_sessions.started_at`; this function converts it with
/// [DateTime.toLocal] before taking the calendar date. Callers must pass
/// [now] as a local `DateTime` (i.e. `DateTime.now()`, never `.toUtc()`).
EmbodimentDayGate embodimentDayGate({
  required DateTime startedAt,
  required DateTime now,
  required Set<int> completedDayNumbers,
}) {
  final localStart = startedAt.toLocal();
  final startDate = DateTime(localStart.year, localStart.month, localStart.day);
  final today = DateTime(now.year, now.month, now.day);
  final elapsedDays = today.difference(startDate).inDays;
  final dayNumber = elapsedDays + 1;

  if (dayNumber < 1 || dayNumber > 7) {
    return const EmbodimentDayGate(
      status: EmbodimentDayStatus.windowElapsed,
      dayNumber: null,
    );
  }
  if (completedDayNumbers.contains(dayNumber)) {
    return EmbodimentDayGate(
      status: EmbodimentDayStatus.alreadyLoggedToday,
      dayNumber: dayNumber,
    );
  }
  return EmbodimentDayGate(status: EmbodimentDayStatus.open, dayNumber: dayNumber);
}
