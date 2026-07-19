import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reassessment_questions.dart'
    show Q3BlockFlag, RediagFeeling, RediagPattern, RediagResistance;
import 'reassessment_tokens.dart';
import '../assessment/scoring.dart' show P1Answer;
import '../journey/journey_repository.dart' show UserCalibration;

/// Authoritative Phase 5 outcome, read back from the database after the
/// processing RPC runs. Never constructed from client math (CLAUDE.md:
/// client mirrors, DB decides).
///
/// [classification] and [routingOutcome] are nullable because the columns
/// are only written by the processing RPC — a row left behind by a failed
/// submit (insert succeeded, RPC did not) reads back as nulls. The Window 2
/// submit path treats missing values as a loud error; the Window 3 closing
/// screen (M5.5) renders calibration instead.
class ReassessmentResult {
  const ReassessmentResult({
    required this.reassessmentId,
    required this.classification,
    required this.routingOutcome,
    this.rediagClassification,
    this.calibration,
  });

  final String reassessmentId;
  final Phase5Classification? classification;
  final RoutingOutcome? routingOutcome;

  /// The `rediag_classification` after `route_false_positive` runs, parsed
  /// through the throwing mirror in reassessment_tokens.dart (enum values
  /// verified against production 2026-07-19 via a read-only schema dump).
  final RediagClassification? rediagClassification;

  /// The `user_calibration` row as `process_window3_durability` left it
  /// (Window 3 only, PRD M5.5). Read back after the RPC — the closing
  /// screen renders this, never client math.
  final UserCalibration? calibration;

  ReassessmentResult withCalibration(UserCalibration calibration) =>
      ReassessmentResult(
        reassessmentId: reassessmentId,
        classification: classification,
        routingOutcome: routingOutcome,
        rediagClassification: rediagClassification,
        calibration: calibration,
      );
}

/// Seam over the Supabase calls [ReassessmentController] makes, so the
/// insert -> RPC -> read-back submit order can be pinned by a fake without a
/// real Supabase client (mirrors `DrillDataSource`).
abstract class ReassessmentDataSource {
  /// Inserts the bare row (loop, user, window). The answers are NOT written
  /// here: the processing RPC takes them as arguments and writes them to
  /// the row itself (`q1_trigger_answer`, `q2_body_state_answer`,
  /// `q3_block_flag` — verified against the deployed function bodies
  /// 2026-07-19 via a read-only schema dump).
  Future<String> insertReassessment({
    required String loopId,
    required ReassessmentWindow window,
  });

  /// Dispatches to the window's processing RPC
  /// (`process_phase5_reassessment` for Window 2, `process_window3_durability`
  /// for Window 3 — same args per PRD §2). Decides AND persists, like
  /// `compute_center_of_gravity`.
  Future<void> processReassessment({
    required ReassessmentWindow window,
    required String reassessmentId,
    required String q1Answer,
    required String q2Answer,
    required String q3Flag,
  });

  Future<ReassessmentResult> fetchResult(String reassessmentId);

  /// `route_false_positive` — the false-positive re-diagnosis (PRD M5.3).
  /// Writes the rediag columns, `rediag_classification`, and the resulting
  /// `routing_outcome` to the same row (always `track_reassignment` per the
  /// deployed body, verified 2026-07-19).
  Future<void> routeFalsePositive({
    required String reassessmentId,
    required String resistance,
    required String feeling,
    required String pattern,
    String? freeText,
  });

  /// Reads the caller's `user_calibration` row (written ONLY by DB
  /// functions — the client never writes it). Used by the Window 3 submit
  /// path after `process_window3_durability` runs (PRD M5.5). Null when no
  /// calibration row exists yet.
  Future<UserCalibration?> fetchCalibration();
}

/// NOTE on `new_loop` (PRD M5.4): there is deliberately no client-side
/// "mark loop complete" write. The deployed `process_phase5_reassessment`
/// already persists the full consequence on `true_ascension` (loop
/// `status = 'complete'`, `completed_at`, `exit_score`, `exit_zone`), and
/// `route_false_positive` never returns `new_loop` — both verified against
/// production 2026-07-19 via a read-only schema dump. A client UPDATE would
/// be a redundant no-op that could only ever write an *incomplete* version
/// of the same fact (status without the exit data).

/// Real implementation, talking straight to the deployed schema/RPC.
class SupabaseReassessmentDataSource implements ReassessmentDataSource {
  SupabaseReassessmentDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<String> insertReassessment({
    required String loopId,
    required ReassessmentWindow window,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No active session. Please sign in again.');
    }
    final row = await _client
        .from('phase5_reassessments')
        .insert({
          'loop_id': loopId,
          'user_id': user.id,
          'window_number': window.token,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  @override
  Future<void> processReassessment({
    required ReassessmentWindow window,
    required String reassessmentId,
    required String q1Answer,
    required String q2Answer,
    required String q3Flag,
  }) {
    // Both RPCs share one signature (PRD §2, verified 2026-07-19):
    // (p_reassessment_id uuid, p_q1_new_answer p1_answer,
    //  p_q2_new_answer p1_answer, p_q3_flag q3_block_flag).
    final functionName = switch (window) {
      ReassessmentWindow.window2 => 'process_phase5_reassessment',
      ReassessmentWindow.window3 => 'process_window3_durability',
    };
    return _client.rpc<void>(
      functionName,
      params: {
        'p_reassessment_id': reassessmentId,
        'p_q1_new_answer': q1Answer,
        'p_q2_new_answer': q2Answer,
        'p_q3_flag': q3Flag,
      },
    );
  }

  @override
  Future<ReassessmentResult> fetchResult(String reassessmentId) async {
    final row = await _client
        .from('phase5_reassessments')
        .select('classification, routing_outcome, rediag_classification')
        .eq('id', reassessmentId)
        .single();
    final classification = row['classification'] as String?;
    final routingOutcome = row['routing_outcome'] as String?;
    return ReassessmentResult(
      reassessmentId: reassessmentId,
      classification: classification == null
          ? null
          : Phase5Classification.fromToken(classification),
      routingOutcome:
          routingOutcome == null ? null : RoutingOutcome.fromToken(routingOutcome),
      rediagClassification: row['rediag_classification'] == null
          ? null
          : RediagClassification.fromToken(
              row['rediag_classification'] as String,
            ),
    );
  }

  @override
  Future<void> routeFalsePositive({
    required String reassessmentId,
    required String resistance,
    required String feeling,
    required String pattern,
    String? freeText,
  }) =>
      _client.rpc<void>(
        'route_false_positive',
        params: {
          // Exact deployed signature, verified against production 2026-07-19
          // (read-only schema dump): p_reassessment_id, p_resistance,
          // p_feeling, p_pattern, p_free_text DEFAULT NULL.
          'p_reassessment_id': reassessmentId,
          'p_resistance': resistance,
          'p_feeling': feeling,
          'p_pattern': pattern,
          // Optional arg: omitted entirely when the user left it blank.
          'p_free_text': ?freeText,
        },
      );

  @override
  Future<UserCalibration?> fetchCalibration() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('No active session. Please sign in again.');
    }
    final row = await _client
        .from('user_calibration')
        .select(
          'calibrated_level, verified_floor, consecutive_verified_loops, '
          'peak_level, flow_resident',
        )
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return UserCalibration(
      calibratedLevel: (row['calibrated_level'] as num).toDouble(),
      verifiedFloor: (row['verified_floor'] as num).toDouble(),
      consecutiveVerifiedLoops: row['consecutive_verified_loops'] as int,
      peakLevel: (row['peak_level'] as num).toDouble(),
      flowResident: row['flow_resident'] as bool,
    );
  }
}

/// Single typed state object for the reassessment: Q1, Q2, Q3 answers, one
/// submit path, one RPC call. Mirrors [AssessmentController]'s discipline.
class ReassessmentController extends ChangeNotifier {
  ReassessmentController({
    required this.loopId,
    required this.window,
    ReassessmentDataSource? dataSource,
  }) : _dataSource = dataSource ?? SupabaseReassessmentDataSource();

  final String loopId;
  final ReassessmentWindow window;
  final ReassessmentDataSource _dataSource;

  P1Answer? _q1Answer;
  P1Answer? _q2Answer;
  Q3BlockFlag? _q3Answer;
  bool _submitting = false;

  RediagResistance? _rediagResistance;
  RediagFeeling? _rediagFeeling;
  RediagPattern? _rediagPattern;
  String _rediagFreeText = '';

  P1Answer? get q1Answer => _q1Answer;
  P1Answer? get q2Answer => _q2Answer;
  Q3BlockFlag? get q3Answer => _q3Answer;
  bool get submitting => _submitting;

  RediagResistance? get rediagResistance => _rediagResistance;
  RediagFeeling? get rediagFeeling => _rediagFeeling;
  RediagPattern? get rediagPattern => _rediagPattern;
  String get rediagFreeText => _rediagFreeText;

  bool get isComplete =>
      _q1Answer != null && _q2Answer != null && _q3Answer != null;

  /// The three rediag selects are required; Q4 free text stays optional
  /// (the RPC's `free_text` arg is optional per PRD §2).
  bool get isRediagComplete =>
      _rediagResistance != null &&
      _rediagFeeling != null &&
      _rediagPattern != null;

  void selectQ1(P1Answer answer) {
    _q1Answer = answer;
    notifyListeners();
  }

  void selectQ2(P1Answer answer) {
    _q2Answer = answer;
    notifyListeners();
  }

  void selectQ3(Q3BlockFlag answer) {
    _q3Answer = answer;
    notifyListeners();
  }

  void selectRediagResistance(RediagResistance answer) {
    _rediagResistance = answer;
    notifyListeners();
  }

  void selectRediagFeeling(RediagFeeling answer) {
    _rediagFeeling = answer;
    notifyListeners();
  }

  void selectRediagPattern(RediagPattern answer) {
    _rediagPattern = answer;
    notifyListeners();
  }

  void setRediagFreeText(String value) {
    _rediagFreeText = value;
    notifyListeners();
  }

  /// The single write path: insert the reassessment row with all three
  /// answers -> the window's processing RPC -> read the authoritative row
  /// back. Throws on any failure; callers surface the error, never swallow
  /// it.
  Future<ReassessmentResult> submit() async {
    if (!isComplete) {
      throw StateError(
        'All three questions must be answered before submitting.',
      );
    }
    _submitting = true;
    notifyListeners();
    try {
      final reassessmentId = await _dataSource.insertReassessment(
        loopId: loopId,
        window: window,
      );
      await _dataSource.processReassessment(
        window: window,
        reassessmentId: reassessmentId,
        q1Answer: _q1Answer!.token,
        q2Answer: _q2Answer!.token,
        q3Flag: _q3Answer!.token,
      );
      final result = await _dataSource.fetchResult(reassessmentId);
      if (window == ReassessmentWindow.window2 &&
          (result.classification == null || result.routingOutcome == null)) {
        throw StateError(
          'process_phase5_reassessment returned without writing '
          'classification/routing to the row.',
        );
      }
      if (window == ReassessmentWindow.window3) {
        // Window 3's result IS the calibration change (PRD M5.5) — read it
        // back after the RPC, loud if the row is missing.
        final calibration = await _dataSource.fetchCalibration();
        if (calibration == null) {
          throw StateError(
            'process_window3_durability returned without a calibration row.',
          );
        }
        return result.withCalibration(calibration);
      }
      return result;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  /// The rediag write path (PRD M5.3), run only when the read-back
  /// classification is `false_positive`: `route_false_positive` -> read the
  /// updated row back. Same errors-surface discipline as [submit].
  Future<ReassessmentResult> submitRediag(String reassessmentId) async {
    if (!isRediagComplete) {
      throw StateError(
        'All three rediag questions must be answered before submitting.',
      );
    }
    _submitting = true;
    notifyListeners();
    try {
      final freeText = _rediagFreeText.trim();
      await _dataSource.routeFalsePositive(
        reassessmentId: reassessmentId,
        resistance: _rediagResistance!.token,
        feeling: _rediagFeeling!.token,
        pattern: _rediagPattern!.token,
        freeText: freeText.isEmpty ? null : freeText,
      );
      return await _dataSource.fetchResult(reassessmentId);
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
