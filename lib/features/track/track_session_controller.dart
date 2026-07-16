import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../drill/drill_tokens.dart' show AscensionTrack;
import 'track_tokens.dart';

/// Seam over the Supabase calls [TrackSessionController] makes, so
/// start/resume + per-stage save behavior can be pinned by a fake without a
/// real Supabase client (test/track_session_controller_test.dart). Mirrors
/// `lib/features/drill/drill_controller.dart`'s `DrillDataSource` pattern.
abstract class TrackSessionDataSource {
  /// The loop's open (`completed_at IS NULL`) session row for [track], if
  /// one exists — the resume path. Null means no session has started yet.
  Future<Map<String, dynamic>?> fetchOpenSession({
    required String loopId,
    required AscensionTrack track,
  });

  Future<String> insertSession({
    required String loopId,
    required AscensionTrack track,
  });

  Future<void> updateSession({
    required String sessionId,
    required Map<String, dynamic> patch,
  });
}

/// Real implementation, talking straight to the deployed
/// `phase4_track_sessions` table (no RPC — there is no deployed decision
/// function for this table; verified against production 2026-07-16, so
/// `success_state_reached` is a value the calling screen decides and passes
/// to [TrackSessionController.finish], not something this layer computes).
class SupabaseTrackSessionDataSource implements TrackSessionDataSource {
  SupabaseTrackSessionDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  @override
  Future<Map<String, dynamic>?> fetchOpenSession({
    required String loopId,
    required AscensionTrack track,
  }) async {
    final rows = await _client
        .from('phase4_track_sessions')
        .select()
        .eq('loop_id', loopId)
        .eq('track_type', track.token)
        .filter('completed_at', 'is', null)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first;
  }

  @override
  Future<String> insertSession({
    required String loopId,
    required AscensionTrack track,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      // The auth gate should make this unreachable; fail loudly if it isn't.
      throw StateError('No active session. Please sign in again.');
    }
    final row = await _client
        .from('phase4_track_sessions')
        .insert({
          'loop_id': loopId,
          'user_id': user.id,
          'track_type': track.token,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  @override
  Future<void> updateSession({
    required String sessionId,
    required Map<String, dynamic> patch,
  }) =>
      _client.from('phase4_track_sessions').update(patch).eq('id', sessionId);
}

/// completion track's integrity-check rule (`ACTION-FOR-NOAH.md`, "Resolved
/// — M4.2 open product decisions", approved by Noah 2026-07-16): fires once
/// the stated `preparation_duration` is a year or more. The statement itself
/// is free text, so the duration enum is the only structured input a
/// deterministic rule may use — no language classification.
bool completionIntegrityCheckTriggered(PrepDuration duration) =>
    duration == PrepDuration.years1to3 || duration == PrepDuration.over3yr;

/// commitment track's success rule (same approval): only a full "yes"
/// counts as success — behavior tells the truth over self-report, mirroring
/// the Phase 5 classification stance (CLAUDE.md).
bool commitmentCheckedInSuccessfully(CheckinResponse response) =>
    response == CheckinResponse.yes;

/// Starts or resumes the loop's `phase4_track_sessions` row for one
/// `AscensionTrack` and exposes typed setters + one save path per stage.
///
/// Scope note: this controller owns `phase4_track_sessions` only. The
/// embodiment track's 7-day `embodiment_daily_logs` loop (M4.5) is a
/// separate table/flow and is out of scope here — the embodiment stage
/// below is only the initial session screen
/// (`body_location_tapped`/`sensation_words`/`stage4_response`).
///
/// `success_state_reached` has no deployed decision function (verified
/// against production 2026-07-16 — no function body references
/// `phase4_track_sessions`), so success is computed by the pure functions
/// above and applied via the per-track `finishX` methods below, never left
/// for a screen to decide ad hoc (`ACTION-FOR-NOAH.md`, approved
/// 2026-07-16). [finish] itself stays as the low-level primitive those
/// methods call.
class TrackSessionController extends ChangeNotifier {
  TrackSessionController({
    required this.loopId,
    required this.track,
    TrackSessionDataSource? dataSource,
  }) : _dataSource = dataSource ?? SupabaseTrackSessionDataSource();

  final String loopId;
  final AscensionTrack track;
  final TrackSessionDataSource _dataSource;

  bool _loading = true;
  String? _error;
  String? _sessionId;

  // completion
  String? _completionStatement;
  PrepDuration? _prepDuration;
  bool _integrityCheckTriggered = false;

  // belief_audit (index-aligned across all four lists)
  final List<String> _flaggedBeliefs = [];
  final List<int?> _beliefAuthorshipAge = [];
  final List<String?> _beliefAuthorshipSource = [];
  final List<BeliefVerdict?> _crossExamVerdict = [];

  // embodiment (session screen only — see class doc)
  String? _bodyLocationTapped;
  List<String> _sensationWords = [];
  Stage4Response? _stage4Response;

  // commitment
  String? _declarationText;
  ConstraintType? _constraintChosen;
  CheckinResponse? _checkinResponse;
  String? _checkinBlockerText;

  bool _saving = false;

  bool get loading => _loading;
  String? get error => _error;
  String? get sessionId => _sessionId;
  bool get saving => _saving;

  String? get completionStatement => _completionStatement;
  PrepDuration? get prepDuration => _prepDuration;
  bool get integrityCheckTriggered => _integrityCheckTriggered;

  List<String> get flaggedBeliefs => List.unmodifiable(_flaggedBeliefs);
  List<int?> get beliefAuthorshipAge => List.unmodifiable(_beliefAuthorshipAge);
  List<String?> get beliefAuthorshipSource =>
      List.unmodifiable(_beliefAuthorshipSource);
  List<BeliefVerdict?> get crossExamVerdict =>
      List.unmodifiable(_crossExamVerdict);

  String? get bodyLocationTapped => _bodyLocationTapped;
  List<String> get sensationWords => List.unmodifiable(_sensationWords);
  Stage4Response? get stage4Response => _stage4Response;

  String? get declarationText => _declarationText;
  ConstraintType? get constraintChosen => _constraintChosen;
  CheckinResponse? get checkinResponse => _checkinResponse;
  String? get checkinBlockerText => _checkinBlockerText;

  bool get isCompletionStageComplete =>
      (_completionStatement?.trim().isNotEmpty ?? false) &&
      _prepDuration != null;

  bool get isBeliefAuditStageComplete =>
      _flaggedBeliefs.isNotEmpty &&
      _beliefAuthorshipAge.every((v) => v != null) &&
      _beliefAuthorshipSource.every((v) => v != null && v.trim().isNotEmpty) &&
      _crossExamVerdict.every((v) => v != null);

  bool get isEmbodimentSessionStageComplete =>
      (_bodyLocationTapped?.trim().isNotEmpty ?? false) &&
      _sensationWords.isNotEmpty &&
      _stage4Response != null;

  bool get isDeclarationStageComplete =>
      (_declarationText?.trim().isNotEmpty ?? false) &&
      _constraintChosen != null;

  bool get isCheckinStageComplete =>
      _checkinResponse != null &&
      (_checkinResponse == CheckinResponse.yes ||
          (_checkinBlockerText?.trim().isNotEmpty ?? false));

  /// Starts a new session, or resumes the loop's already-open one for
  /// [track] — never both. Hydrates every field the resumed row already
  /// has, so re-entering mid-flow shows prior answers.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final existing =
          await _dataSource.fetchOpenSession(loopId: loopId, track: track);
      if (existing != null) {
        _sessionId = existing['id'] as String;
        _hydrate(existing);
      } else {
        _sessionId =
            await _dataSource.insertSession(loopId: loopId, track: track);
      }
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _hydrate(Map<String, dynamic> row) {
    _completionStatement = row['completion_statement'] as String?;
    final prepToken = row['preparation_duration'] as String?;
    _prepDuration = prepToken == null ? null : PrepDuration.fromToken(prepToken);
    _integrityCheckTriggered = row['integrity_check_triggered'] as bool? ?? false;

    final beliefs = (row['flagged_beliefs'] as List?)?.cast<String>() ?? [];
    final ages = (row['belief_authorship_age'] as List?)?.cast<int?>() ?? [];
    final sources =
        (row['belief_authorship_source'] as List?)?.cast<String?>() ?? [];
    final verdictTokens =
        (row['cross_exam_verdict'] as List?)?.cast<String?>() ?? [];
    _flaggedBeliefs
      ..clear()
      ..addAll(beliefs);
    _beliefAuthorshipAge
      ..clear()
      ..addAll(List<int?>.generate(
          beliefs.length, (i) => i < ages.length ? ages[i] : null));
    _beliefAuthorshipSource
      ..clear()
      ..addAll(List<String?>.generate(
          beliefs.length, (i) => i < sources.length ? sources[i] : null));
    _crossExamVerdict
      ..clear()
      ..addAll(List<BeliefVerdict?>.generate(beliefs.length, (i) {
        if (i >= verdictTokens.length) return null;
        final token = verdictTokens[i];
        return token == null ? null : BeliefVerdict.fromToken(token);
      }));

    _bodyLocationTapped = row['body_location_tapped'] as String?;
    _sensationWords = (row['sensation_words'] as List?)?.cast<String>() ?? [];
    final stage4Token = row['stage4_response'] as String?;
    _stage4Response =
        stage4Token == null ? null : Stage4Response.fromToken(stage4Token);

    _declarationText = row['declaration_text'] as String?;
    final constraintToken = row['constraint_chosen'] as String?;
    _constraintChosen =
        constraintToken == null ? null : ConstraintType.fromToken(constraintToken);
    final checkinToken = row['checkin_response'] as String?;
    _checkinResponse =
        checkinToken == null ? null : CheckinResponse.fromToken(checkinToken);
    _checkinBlockerText = row['checkin_blocker_text'] as String?;
  }

  // --- completion setters ---

  void setCompletionStatement(String value) {
    _completionStatement = value;
    notifyListeners();
  }

  /// Also recomputes [integrityCheckTriggered] via the deterministic rule —
  /// never set directly (ACTION-FOR-NOAH.md, approved 2026-07-16).
  void selectPrepDuration(PrepDuration value) {
    _prepDuration = value;
    _integrityCheckTriggered = completionIntegrityCheckTriggered(value);
    notifyListeners();
  }

  // --- belief_audit setters ---

  /// Appends a newly flagged belief and grows the other three aligned
  /// lists in lockstep, so every list always shares one length and index i
  /// always refers to the same belief.
  void addFlaggedBelief(String belief) {
    _flaggedBeliefs.add(belief);
    _beliefAuthorshipAge.add(null);
    _beliefAuthorshipSource.add(null);
    _crossExamVerdict.add(null);
    notifyListeners();
  }

  void setBeliefAuthorship(int index, {required int age, required String source}) {
    _checkBeliefIndex(index);
    _beliefAuthorshipAge[index] = age;
    _beliefAuthorshipSource[index] = source;
    notifyListeners();
  }

  void setCrossExamVerdict(int index, BeliefVerdict verdict) {
    _checkBeliefIndex(index);
    _crossExamVerdict[index] = verdict;
    notifyListeners();
  }

  void _checkBeliefIndex(int index) {
    if (index < 0 || index >= _flaggedBeliefs.length) {
      throw RangeError.index(index, _flaggedBeliefs, 'index');
    }
  }

  // --- embodiment session setters ---

  void setBodyLocationTapped(String value) {
    _bodyLocationTapped = value;
    notifyListeners();
  }

  void setSensationWords(List<String> words) {
    _sensationWords = List.of(words);
    notifyListeners();
  }

  void selectStage4Response(Stage4Response value) {
    _stage4Response = value;
    notifyListeners();
  }

  // --- commitment setters ---

  void setDeclarationText(String value) {
    _declarationText = value;
    notifyListeners();
  }

  void selectConstraintType(ConstraintType value) {
    _constraintChosen = value;
    notifyListeners();
  }

  void selectCheckinResponse(CheckinResponse value) {
    _checkinResponse = value;
    notifyListeners();
  }

  void setCheckinBlockerText(String value) {
    _checkinBlockerText = value;
    notifyListeners();
  }

  Future<void> _save(Map<String, dynamic> patch) async {
    if (_sessionId == null) {
      throw StateError('No active session — call load() first.');
    }
    _saving = true;
    notifyListeners();
    try {
      await _dataSource.updateSession(sessionId: _sessionId!, patch: patch);
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// completion track's one stage: statement + duration.
  Future<void> saveCompletionStage() async {
    if (!isCompletionStageComplete) {
      throw StateError(
        'completion_statement and prep_duration are both required.',
      );
    }
    await _save({
      'completion_statement': _completionStatement!.trim(),
      'preparation_duration': _prepDuration!.token,
      'integrity_check_triggered': _integrityCheckTriggered,
    });
  }

  /// belief_audit's one stage: all four index-aligned arrays together.
  Future<void> saveBeliefAuditStage() async {
    if (!isBeliefAuditStageComplete) {
      throw StateError(
        'Every flagged belief needs authorship age, authorship source, and '
        'a cross-exam verdict before saving.',
      );
    }
    await _save({
      'flagged_beliefs': _flaggedBeliefs,
      'belief_authorship_age': _beliefAuthorshipAge,
      'belief_authorship_source': _beliefAuthorshipSource,
      'cross_exam_verdict': _crossExamVerdict.map((v) => v!.token).toList(),
    });
  }

  /// embodiment's session-screen stage (see class doc for scope).
  Future<void> saveEmbodimentSessionStage() async {
    if (!isEmbodimentSessionStageComplete) {
      throw StateError(
        'body_location_tapped, sensation_words, and stage4_response are all '
        'required.',
      );
    }
    await _save({
      'body_location_tapped': _bodyLocationTapped!.trim(),
      'sensation_words': _sensationWords,
      'stage4_response': _stage4Response!.token,
    });
  }

  /// commitment's first stage: declaration + constraint, and schedules the
  /// check-in 72 hours out.
  Future<void> saveDeclarationStage() async {
    if (!isDeclarationStageComplete) {
      throw StateError(
        'declaration_text and constraint_chosen are both required.',
      );
    }
    await _save({
      'declaration_text': _declarationText!.trim(),
      'constraint_chosen': _constraintChosen!.token,
      'checkin_scheduled_at':
          DateTime.now().toUtc().add(const Duration(hours: 72)).toIso8601String(),
    });
  }

  /// commitment's second stage, days later: the check-in itself.
  Future<void> saveCheckinStage() async {
    if (!isCheckinStageComplete) {
      throw StateError(
        'checkin_response is required, and checkin_blocker_text is required '
        'unless the answer is yes.',
      );
    }
    await _save({
      'checkin_response': _checkinResponse!.token,
      'checkin_blocker_text': _checkinBlockerText?.trim(),
    });
  }

  /// Low-level primitive: marks the session done with an explicit
  /// `success` value. Prefer the per-track `finishX` methods below, which
  /// compute `success` via the approved pure rules instead of leaving it to
  /// the caller.
  Future<void> finish({required bool success}) => _save({
        'completed_at': DateTime.now().toUtc().toIso8601String(),
        'success_state_reached': success,
      });

  /// completion track: reaching the end of the flow is success — the
  /// integrity-check moment is reflective, not a fail state.
  Future<void> finishCompletion() => finish(success: true);

  /// belief_audit track: reaching the end of the flow is success.
  Future<void> finishBeliefAudit() => finish(success: true);

  /// commitment track: success iff the check-in answer is a full "yes".
  /// Requires [saveCheckinStage] to have been called first.
  Future<void> finishCommitmentCheckin() async {
    if (_checkinResponse == null) {
      throw StateError('Cannot finish before the check-in is recorded.');
    }
    await finish(success: commitmentCheckedInSuccessfully(_checkinResponse!));
  }
}
