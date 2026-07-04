import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'scoring.dart';

/// Authoritative Phase 1 outcome, read back from the database after
/// `compute_center_of_gravity` runs. Never constructed from client math.
class AssessmentResult {
  const AssessmentResult({
    required this.centerOfGravity,
    required this.dominantZone,
    required this.consistencyFlag,
  });

  final double centerOfGravity;
  final EnergyZone dominantZone;
  final String consistencyFlag;
}

/// Single typed state object for the whole assessment: all 7 answers, one
/// submit path, one RPC call. No per-question write chains — nothing touches
/// the network until [submit].
class AssessmentController extends ChangeNotifier {
  AssessmentController({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const int questionCount = 7;

  final SupabaseClient _client;
  final List<P1Answer?> _answers = List.filled(questionCount, null);
  bool _submitting = false;

  P1Answer? answerFor(int questionIndex) => _answers[questionIndex];

  bool get isComplete => !_answers.contains(null);

  bool get submitting => _submitting;

  /// Provisional CoG from the client mirror — display only, never persisted.
  double? get previewScore =>
      isComplete ? computeCogPreview(_answers.cast<P1Answer>()) : null;

  void selectAnswer(int questionIndex, P1Answer answer) {
    _answers[questionIndex] = answer;
    notifyListeners();
  }

  /// The single write path: insert loop → insert assessment → RPC → read the
  /// authoritative result back. Throws on any failure; callers surface the
  /// error, never swallow it.
  Future<AssessmentResult> submit() async {
    if (!isComplete) {
      throw StateError('All 7 questions must be answered before submitting.');
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      // The auth gate should make this unreachable; fail loudly if it isn't.
      throw StateError('No active session. Please sign in again.');
    }
    final answers = _answers.cast<P1Answer>();

    _submitting = true;
    notifyListeners();
    try {
      final latestLoop = await _client
          .from('ascension_loops')
          .select('loop_number')
          .eq('user_id', user.id)
          .order('loop_number', ascending: false)
          .limit(1)
          .maybeSingle();
      final nextLoopNumber = ((latestLoop?['loop_number'] as int?) ?? 0) + 1;

      final loop = await _client
          .from('ascension_loops')
          .insert({'user_id': user.id, 'loop_number': nextLoopNumber})
          .select('id')
          .single();
      final loopId = loop['id'] as String;

      final assessment = await _client
          .from('phase1_assessments')
          .insert({
            'loop_id': loopId,
            'user_id': user.id,
            for (var i = 0; i < questionCount; i++)
              'q${i + 1}_answer': answers[i].token,
          })
          .select('id')
          .single();
      final assessmentId = assessment['id'] as String;

      await _client.rpc<void>(
        'compute_center_of_gravity',
        params: {'p_assessment_id': assessmentId},
      );

      final scored = await _client
          .from('phase1_assessments')
          .select('center_of_gravity, dominant_zone, consistency_flag')
          .eq('id', assessmentId)
          .single();

      return AssessmentResult(
        centerOfGravity: (scored['center_of_gravity'] as num).toDouble(),
        dominantZone: EnergyZone.fromToken(scored['dominant_zone'] as String),
        consistencyFlag: scored['consistency_flag'] as String,
      );
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
