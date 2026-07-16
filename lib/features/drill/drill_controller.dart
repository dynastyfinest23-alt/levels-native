import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'drill_tokens.dart';

/// Authoritative Phase 3 outcome, read back from the database after
/// `process_phase3_drill` runs. Track assignment is DB-decided
/// (`assign_phase4_track`), never derived client-side.
class DrillResult {
  const DrillResult({required this.drillId, required this.assignedTrack});

  final String drillId;
  final AscensionTrack assignedTrack;
}

/// Seam over the Supabase calls [DrillController] makes, so the
/// insert -> RPC -> read-back submit order can be pinned by a fake without a
/// real Supabase client (test/drill_controller_test.dart).
abstract class DrillDataSource {
  /// Reads the user's own `bridge_question_shown` from the Phase 2 row —
  /// the Phase 2->3 hand-off seam (PRD M3.2/M3.4).
  Future<String> fetchBridgeQuestion(String loopId);

  Future<String> insertDrill({
    required String loopId,
    required OriginType originType,
    required OriginDomain originDomain,
    required CopingMechanism copingMechanism,
    required String q1FreeText,
    required String q2FreeText,
    required String q3FreeText,
    required int deepeningLayer,
  });

  Future<void> processDrill(String drillId);

  Future<AscensionTrack> fetchAssignedTrack(String drillId);
}

/// Real implementation, talking straight to the deployed schema/RPC.
class SupabaseDrillDataSource implements DrillDataSource {
  SupabaseDrillDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<String> fetchBridgeQuestion(String loopId) async {
    final row = await _client
        .from('phase2_dashboard_views')
        .select('bridge_question_shown')
        .eq('loop_id', loopId)
        .single();
    final question = row['bridge_question_shown'] as String?;
    if (question == null || question.isEmpty) {
      throw StateError('No bridge question recorded for loop $loopId.');
    }
    return question;
  }

  @override
  Future<String> insertDrill({
    required String loopId,
    required OriginType originType,
    required OriginDomain originDomain,
    required CopingMechanism copingMechanism,
    required String q1FreeText,
    required String q2FreeText,
    required String q3FreeText,
    required int deepeningLayer,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // The auth gate should make this unreachable; fail loudly if it isn't.
      throw StateError('No active session. Please sign in again.');
    }
    final drill = await _client
        .from('phase3_origin_drills')
        .insert({
          'loop_id': loopId,
          'user_id': user.id,
          'q1_origin_type': originType.token,
          'q2_domain': originDomain.token,
          'q3_mechanism': copingMechanism.token,
          'q1_free_text': q1FreeText,
          'q2_free_text': q2FreeText,
          'q3_free_text': q3FreeText,
          'deepening_layer': deepeningLayer,
        })
        .select('id')
        .single();
    return drill['id'] as String;
  }

  @override
  Future<void> processDrill(String drillId) => _client.rpc<void>(
        'process_phase3_drill',
        params: {'p_drill_id': drillId},
      );

  @override
  Future<AscensionTrack> fetchAssignedTrack(String drillId) async {
    final row = await _client
        .from('phase3_origin_drills')
        .select('assigned_protocol')
        .eq('id', drillId)
        .single();
    return AscensionTrack.fromToken(row['assigned_protocol'] as String);
  }
}

/// Single typed state object for the whole drill: the three structured
/// answers plus their free-text elaborations, one submit path, one RPC call.
/// Mirrors [AssessmentController]'s discipline (in
/// `lib/features/assessment/assessment_controller.dart`) — nothing touches
/// the network until [submit], and errors are never swallowed.
class DrillController extends ChangeNotifier {
  DrillController({
    required this.loopId,
    this.deepeningLayer = 1,
    DrillDataSource? dataSource,
  }) : _dataSource = dataSource ?? SupabaseDrillDataSource();

  final String loopId;

  /// Default 1; M5 deepening protocols pass 2+ (PRD M3.4).
  final int deepeningLayer;

  final DrillDataSource _dataSource;

  bool _loading = true;
  String? _error;
  String? _bridgeQuestion;
  OriginType? _originType;
  OriginDomain? _originDomain;
  CopingMechanism? _copingMechanism;
  String _q1FreeText = '';
  String _q2FreeText = '';
  String _q3FreeText = '';
  bool _submitting = false;

  bool get loading => _loading;
  String? get error => _error;

  /// The user's own bridge question from Phase 2 — Q1's free-text prompt.
  /// Null until [load] completes.
  String? get bridgeQuestion => _bridgeQuestion;

  OriginType? get originType => _originType;
  OriginDomain? get originDomain => _originDomain;
  CopingMechanism? get copingMechanism => _copingMechanism;
  String get q1FreeText => _q1FreeText;
  String get q2FreeText => _q2FreeText;
  String get q3FreeText => _q3FreeText;
  bool get submitting => _submitting;

  bool get isComplete =>
      _originType != null &&
      _originDomain != null &&
      _copingMechanism != null &&
      _q1FreeText.trim().isNotEmpty &&
      _q2FreeText.trim().isNotEmpty &&
      _q3FreeText.trim().isNotEmpty;

  /// Fetches the bridge question. Errors surface via [error] — never
  /// swallowed, never rendered as a blank prompt.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _bridgeQuestion = await _dataSource.fetchBridgeQuestion(loopId);
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectOriginType(OriginType value) {
    _originType = value;
    notifyListeners();
  }

  void selectOriginDomain(OriginDomain value) {
    _originDomain = value;
    notifyListeners();
  }

  void selectCopingMechanism(CopingMechanism value) {
    _copingMechanism = value;
    notifyListeners();
  }

  void setQ1FreeText(String value) {
    _q1FreeText = value;
    notifyListeners();
  }

  void setQ2FreeText(String value) {
    _q2FreeText = value;
    notifyListeners();
  }

  void setQ3FreeText(String value) {
    _q3FreeText = value;
    notifyListeners();
  }

  /// The single write path: insert the drill row with all answers + free
  /// text -> RPC `process_phase3_drill` -> read the authoritative row back.
  /// Throws on any failure; callers surface the error, never swallow it.
  Future<DrillResult> submit() async {
    if (!isComplete) {
      throw StateError(
        'All three questions and their free-text answers are required '
        'before submitting.',
      );
    }
    _submitting = true;
    notifyListeners();
    try {
      final drillId = await _dataSource.insertDrill(
        loopId: loopId,
        originType: _originType!,
        originDomain: _originDomain!,
        copingMechanism: _copingMechanism!,
        q1FreeText: _q1FreeText.trim(),
        q2FreeText: _q2FreeText.trim(),
        q3FreeText: _q3FreeText.trim(),
        deepeningLayer: deepeningLayer,
      );
      await _dataSource.processDrill(drillId);
      final track = await _dataSource.fetchAssignedTrack(drillId);
      return DrillResult(drillId: drillId, assignedTrack: track);
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }
}
