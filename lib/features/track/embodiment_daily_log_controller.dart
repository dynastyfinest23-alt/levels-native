import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'embodiment_gate.dart';
import 'track_content.dart' show embodimentDailyIdentityStatements;
import 'track_tokens.dart';

/// Seam over the Supabase calls [EmbodimentDailyLogController] makes, so
/// gate/save behavior can be pinned by a fake without a real client.
/// Mirrors `lib/features/track/track_session_controller.dart`'s
/// `TrackSessionDataSource` pattern. A separate table/flow from
/// `phase4_track_sessions` — see that file's class doc for the scope split.
abstract class EmbodimentDailyLogDataSource {
  Future<List<Map<String, dynamic>>> fetchLogs(String sessionId);

  Future<void> insertLog(Map<String, dynamic> row);
}

class SupabaseEmbodimentDailyLogDataSource
    implements EmbodimentDailyLogDataSource {
  SupabaseEmbodimentDailyLogDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> fetchLogs(String sessionId) => _client
      .from('embodiment_daily_logs')
      .select()
      .eq('session_id', sessionId);

  @override
  Future<void> insertLog(Map<String, dynamic> row) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // The auth gate should make this unreachable; fail loudly if it isn't.
      throw StateError('No active session. Please sign in again.');
    }
    await _client
        .from('embodiment_daily_logs')
        .insert({...row, 'user_id': user.id});
  }
}

/// Drives one day's embodiment check-in: reads which `day_number` is open
/// today via [embodimentDayGate] (the session's `started_at` is the fixed
/// calendar anchor — no backfill for skipped days), then saves that one
/// day's row in a single insert (day6/day7's extra fields only apply on
/// those days).
///
/// Scope note: `body_location`/`sensation_words` also exist as columns on
/// `embodiment_daily_logs`, but `track_content.dart` (M4.1, gate-approved)
/// has no per-day prompt for them — only the one-time session screen asks
/// for those. Left unwritten here rather than inventing new copy; flagged
/// in `ACTION-FOR-NOAH.md`.
class EmbodimentDailyLogController extends ChangeNotifier {
  EmbodimentDailyLogController({
    required this.sessionId,
    required this.startedAt,
    EmbodimentDailyLogDataSource? dataSource,
    DateTime Function() now = DateTime.now,
  })  : _dataSource = dataSource ?? SupabaseEmbodimentDailyLogDataSource(),
        // `this._now` would force the external param name to match the
        // private field name, but tests need to pass `now:` from outside.
        // ignore: prefer_initializing_formals
        _now = now;

  final String sessionId;
  final DateTime startedAt;
  final EmbodimentDailyLogDataSource _dataSource;
  final DateTime Function() _now;

  bool _loading = true;
  String? _error;
  bool _saving = false;
  EmbodimentDayGate? _gate;

  BodyResponse? _bodyResponse;
  EmbodimentDelta? _day6Delta;
  String? _day7ActionCommitted;
  bool? _day7ActionConfirmed;

  bool get loading => _loading;
  String? get error => _error;
  bool get saving => _saving;
  EmbodimentDayGate? get gate => _gate;

  /// The static copy for today's day_number (`track_content.dart`), or
  /// null before [load] completes / once the window has elapsed.
  String? get todaysIdentityStatement {
    final day = _gate?.dayNumber;
    if (day == null) return null;
    return embodimentDailyIdentityStatements[day - 1];
  }

  BodyResponse? get bodyResponse => _bodyResponse;
  EmbodimentDelta? get day6Delta => _day6Delta;
  String? get day7ActionCommitted => _day7ActionCommitted;
  bool? get day7ActionConfirmed => _day7ActionConfirmed;

  bool get isDayCheckComplete => _bodyResponse != null;
  bool get isDay6Complete => _day6Delta != null;
  bool get isDay7ActionCommittedComplete =>
      _day7ActionCommitted?.trim().isNotEmpty ?? false;
  bool get isDay7ConfirmComplete => _day7ActionConfirmed != null;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final rows = await _dataSource.fetchLogs(sessionId);
      final completed = rows
          .where((r) => r['completed_at'] != null)
          .map((r) => r['day_number'] as int)
          .toSet();
      _gate = embodimentDayGate(
        startedAt: startedAt,
        now: _now(),
        completedDayNumbers: completed,
      );
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectBodyResponse(BodyResponse value) {
    _bodyResponse = value;
    notifyListeners();
  }

  void selectDay6Delta(EmbodimentDelta value) {
    _day6Delta = value;
    notifyListeners();
  }

  void setDay7ActionCommitted(String value) {
    _day7ActionCommitted = value;
    notifyListeners();
  }

  void setDay7ActionConfirmed(bool value) {
    _day7ActionConfirmed = value;
    notifyListeners();
  }

  /// Saves today's log in one insert. Throws if [gate] isn't open, or if
  /// the day-specific required fields aren't filled.
  Future<void> saveDayLog() async {
    final day = _gate?.dayNumber;
    if (_gate?.status != EmbodimentDayStatus.open || day == null) {
      throw StateError('No day is open to log right now.');
    }
    if (!isDayCheckComplete) {
      throw StateError('body_response is required.');
    }
    if (day == 6 && !isDay6Complete) {
      throw StateError('day6_delta_reported is required on day 6.');
    }
    if (day == 7 && (!isDay7ActionCommittedComplete || !isDay7ConfirmComplete)) {
      throw StateError(
        'day7_action_committed and day7_action_confirmed are both required '
        'on day 7.',
      );
    }
    _saving = true;
    notifyListeners();
    try {
      await _dataSource.insertLog({
        'session_id': sessionId,
        'day_number': day,
        'identity_statement_shown': embodimentDailyIdentityStatements[day - 1],
        'body_response': _bodyResponse!.token,
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        if (day == 6) 'day6_delta_reported': _day6Delta!.token,
        if (day == 7) 'day7_action_committed': _day7ActionCommitted!.trim(),
        if (day == 7) 'day7_action_confirmed': _day7ActionConfirmed,
      });
    } finally {
      _saving = false;
      notifyListeners();
    }
  }
}
