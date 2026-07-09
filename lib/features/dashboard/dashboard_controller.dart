import 'dart:async';

import 'package:flutter/foundation.dart';

import '../assessment/assessment_controller.dart';
import 'dashboard_copy.dart';
import 'dashboard_repository.dart';

/// DB columns written as each panel opens, in reveal order. `bridge_question`
/// has no tracking column of its own — it was already persisted as
/// `bridge_question_shown` at generation time — so the last slot is null.
const List<String?> _revealColumns = [
  'reality_tunnel_read',
  'hidden_benefit_opened',
  'illusion_opened',
  null,
];

/// Thin UI-state wrapper over [DashboardRepository]: loading/error state,
/// which panel is currently revealed, and view-id bookkeeping. No network
/// shape or parsing logic lives here — that's the repository's job.
class DashboardController extends ChangeNotifier {
  DashboardController({
    required this.loopId,
    DashboardRepository? repository,
  }) : _repository = repository ?? DashboardRepository();

  final String loopId;
  final DashboardRepository _repository;

  bool _loading = true;
  String? _error;
  AssessmentResult? _assessmentResult;
  DashboardCopy? _copy;
  String? _viewId;
  final DateTime _openedAt = DateTime.now();

  bool get loading => _loading;
  String? get error => _error;
  AssessmentResult? get assessmentResult => _assessmentResult;
  DashboardCopy? get copy => _copy;

  /// How many of the 4 panels (reality_tunnel, hidden_benefit, illusion,
  /// bridge_question) have been revealed, in order. Panel [i] is tappable
  /// only when `revealedCount == i`; panels are never revealed out of order.
  int _revealedCount = 0;
  int get revealedCount => _revealedCount;
  static const int panelCount = 4;

  /// Fetches the authoritative score/zone and the reveal copy. Errors
  /// surface via [error] — never swallowed, never rendered as blanks.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.fetchScoredAssessment(loopId),
        _repository.fetchOrGenerateCopy(loopId),
      ]);
      _assessmentResult = results[0] as AssessmentResult;
      final view = results[1] as DashboardView;
      _copy = view.copy;
      _viewId = view.id;
    } catch (err) {
      _error = err.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Reveals panel [index] (must equal the current [revealedCount]) and
  /// persists that it was opened. The DB write is telemetry, not the reveal
  /// itself — a failure is logged, never blocks the user's progress.
  Future<void> revealPanel(int index) async {
    if (index != _revealedCount || index >= panelCount) return;
    _revealedCount++;
    notifyListeners();

    final column = _revealColumns[index];
    final viewId = _viewId;
    if (column == null || viewId == null) return;
    try {
      await _repository.markPanelOpened(viewId, column);
    } catch (err) {
      debugPrint('Failed to record $column for view $viewId: $err');
    }
  }

  /// Records dwell time on the reveal screen. Fire-and-forget — called from
  /// dispose, so callers must not await it.
  void recordTimeOnScreen() {
    final viewId = _viewId;
    if (viewId == null) return;
    final seconds = DateTime.now().difference(_openedAt).inSeconds;
    unawaited(
      _repository.recordTimeOnScreen(viewId, seconds).catchError((err) {
        debugPrint('Failed to record time_on_screen_secs for $viewId: $err');
      }),
    );
  }
}
