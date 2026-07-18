import 'package:supabase_flutter/supabase_flutter.dart';

import '../drill/drill_tokens.dart' show AscensionTrack;
import '../track/embodiment_gate.dart';
import 'loop_state.dart';

/// Read-only snapshot of `user_calibration` — written only by deployed DB
/// functions (CLAUDE.md); the client never writes this table.
class UserCalibration {
  const UserCalibration({
    required this.calibratedLevel,
    required this.verifiedFloor,
    required this.consecutiveVerifiedLoops,
    required this.peakLevel,
    required this.flowResident,
  });

  final double calibratedLevel;
  final double verifiedFloor;
  final int consecutiveVerifiedLoops;
  final double peakLevel;
  final bool flowResident;
}

/// The active loop plus everything [LoopState] and the home hub need.
class JourneyData {
  const JourneyData({
    required this.loopId,
    required this.loopNumber,
    required this.loopState,
    required this.calibration,
    required this.trackProgress,
  });

  final String loopId;
  final int loopNumber;
  final LoopState loopState;

  /// Null until `seed_calibration_from_assessment` has run at least once.
  final UserCalibration? calibration;

  /// Null until the loop's `phase4_track_sessions` row exists (PRD M4.6).
  final TrackProgress? trackProgress;
}

/// Home hub's view of the loop's track session (PRD M4.6): which track,
/// whether it's done, and — for embodiment only, while still open — the
/// day gate so the hub can show "Day N of 7" instead of generic copy.
class TrackProgress {
  const TrackProgress({
    required this.track,
    required this.completed,
    required this.embodimentGate,
  });

  final AscensionTrack track;
  final bool completed;

  /// Only computed for an open embodiment session (CLAUDE.md: mechanic-free
  /// hub copy elsewhere doesn't need this). Null for every other track, and
  /// null for a completed embodiment session.
  final EmbodimentDayGate? embodimentGate;
}

/// Single read path for "where is this user in their journey". Follows
/// [AssessmentController]'s error discipline: throws, never swallows.
///
/// NOTE: `users.current_loop_id` exists in the deployed schema but is never
/// written anywhere in this codebase (checked 2026-07-08) — it is a dead
/// column, not a source of truth. The active loop is the most recent by
/// `loop_number`, the same lookup `AssessmentController.submit` already
/// uses to number the next loop.
class JourneyRepository {
  JourneyRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Fetches the user's most recent loop and the phase row-existence flags
  /// [LoopState.compute] needs, plus their calibration snapshot. Returns
  /// null if the user has never taken Phase 1 (no loop exists yet).
  Future<JourneyData?> fetchActiveLoop() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // The auth gate should make this unreachable; fail loudly if it isn't.
      throw StateError('No active session. Please sign in again.');
    }

    final loopRow = await _client
        .from('ascension_loops')
        .select('id, loop_number, started_at, status')
        .eq('user_id', user.id)
        .order('loop_number', ascending: false)
        .limit(1)
        .maybeSingle();
    if (loopRow == null) return null;

    final loopId = loopRow['id'] as String;

    final rows = await Future.wait<Map<String, dynamic>?>([
      _client
          .from('phase2_dashboard_views')
          .select('id')
          .eq('loop_id', loopId)
          .maybeSingle(),
      _client
          .from('phase3_origin_drills')
          .select('id')
          .eq('loop_id', loopId)
          .maybeSingle(),
      _client
          .from('phase4_track_sessions')
          .select('id, track_type, started_at, completed_at')
          .eq('loop_id', loopId)
          .limit(1)
          .maybeSingle(),
      _client
          .from('phase5_reassessments')
          .select('id')
          .eq('loop_id', loopId)
          .eq('window_number', 'window_2')
          .maybeSingle(),
      _client
          .from('phase5_reassessments')
          .select('id')
          .eq('loop_id', loopId)
          .eq('window_number', 'window_3')
          .maybeSingle(),
      _client
          .from('user_calibration')
          .select(
            'calibrated_level, verified_floor, consecutive_verified_loops, '
            'peak_level, flow_resident',
          )
          .eq('user_id', user.id)
          .maybeSingle(),
    ]);

    final loopState = LoopState.compute(
      loopStartedAt: DateTime.parse(loopRow['started_at'] as String),
      loopComplete: (loopRow['status'] as String) == 'complete',
      hasPhase2View: rows[0] != null,
      hasPhase3Drill: rows[1] != null,
      hasPhase4Session: rows[2] != null,
      hasWindow2Reassessment: rows[3] != null,
      hasWindow3Reassessment: rows[4] != null,
      now: DateTime.now(),
    );

    final calibrationRow = rows[5];
    final calibration = calibrationRow == null
        ? null
        : UserCalibration(
            calibratedLevel: (calibrationRow['calibrated_level'] as num)
                .toDouble(),
            verifiedFloor: (calibrationRow['verified_floor'] as num)
                .toDouble(),
            consecutiveVerifiedLoops:
                calibrationRow['consecutive_verified_loops'] as int,
            peakLevel: (calibrationRow['peak_level'] as num).toDouble(),
            flowResident: calibrationRow['flow_resident'] as bool,
          );

    final sessionRow = rows[2];
    final trackProgress = sessionRow == null
        ? null
        : await _fetchTrackProgress(sessionRow);

    return JourneyData(
      loopId: loopId,
      loopNumber: loopRow['loop_number'] as int,
      loopState: loopState,
      calibration: calibration,
      trackProgress: trackProgress,
    );
  }

  /// Only queries `embodiment_daily_logs` when the session is an open
  /// embodiment track — every other track has no gate to compute.
  Future<TrackProgress> _fetchTrackProgress(
    Map<String, dynamic> sessionRow,
  ) async {
    final track = AscensionTrack.fromToken(sessionRow['track_type'] as String);
    final completed = sessionRow['completed_at'] != null;

    if (track != AscensionTrack.embodiment || completed) {
      return TrackProgress(
        track: track,
        completed: completed,
        embodimentGate: null,
      );
    }

    final logRows = await _client
        .from('embodiment_daily_logs')
        .select('day_number')
        .eq('session_id', sessionRow['id'] as String)
        .not('completed_at', 'is', null);

    final gate = embodimentDayGate(
      startedAt: DateTime.parse(sessionRow['started_at'] as String),
      now: DateTime.now(),
      completedDayNumbers: logRows.map((r) => r['day_number'] as int).toSet(),
    );

    return TrackProgress(
      track: track,
      completed: false,
      embodimentGate: gate,
    );
  }
}
