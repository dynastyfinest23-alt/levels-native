import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'reassessment_questions.dart' show Q3BlockFlag;
import 'reassessment_tokens.dart';
import '../assessment/scoring.dart' show P1Answer;

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
  });

  final String reassessmentId;
  final Phase5Classification? classification;
  final RoutingOutcome? routingOutcome;
}

/// Seam over the Supabase calls [ReassessmentController] makes, so the
/// insert -> RPC -> read-back submit order can be pinned by a fake without a
/// real Supabase client (mirrors `DrillDataSource`).
abstract class ReassessmentDataSource {
  Future<String> insertReassessment({
    required String loopId,
    required ReassessmentWindow window,
    required String q1Answer,
    required String q2Answer,
    required String q3Flag,
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
}

/// Real implementation, talking straight to the deployed schema/RPC.
class SupabaseReassessmentDataSource implements ReassessmentDataSource {
  SupabaseReassessmentDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<String> insertReassessment({
    required String loopId,
    required ReassessmentWindow window,
    required String q1Answer,
    required String q2Answer,
    required String q3Flag,
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
          'q1_answer': q1Answer,
          'q2_answer': q2Answer,
          'q3_block_flag': q3Flag,
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
        .select('classification, routing_outcome')
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

  P1Answer? get q1Answer => _q1Answer;
  P1Answer? get q2Answer => _q2Answer;
  Q3BlockFlag? get q3Answer => _q3Answer;
  bool get submitting => _submitting;

  bool get isComplete =>
      _q1Answer != null && _q2Answer != null && _q3Answer != null;

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
        q1Answer: _q1Answer!.token,
        q2Answer: _q2Answer!.token,
        q3Flag: _q3Answer!.token,
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
      return result;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
