import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dashboard_copy.dart';

/// DB columns written as each panel opens, in reveal order. `bridge_question`
/// has no tracking column of its own — it was already persisted as
/// `bridge_question_shown` at generation time — so the last slot is null.
const List<String?> _revealColumns = [
  'reality_tunnel_read',
  'hidden_benefit_opened',
  'illusion_opened',
  null,
];

/// Fetches (or triggers generation of) the Phase 2 four-part reveal copy for
/// a loop, and records which panels the user has opened. The copy itself is
/// presentation only — CoG and zone are never read from here, only from the
/// authoritative `phase1_assessments` row already held by the caller.
class DashboardController extends ChangeNotifier {
  DashboardController({required this.loopId, SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final String loopId;
  final SupabaseClient _client;

  bool _loading = true;
  String? _error;
  DashboardCopy? _copy;
  String? _viewId;

  /// How many of the 4 panels (reality_tunnel, hidden_benefit, illusion,
  /// bridge_question) have been revealed, in order. Panel [i] is tappable
  /// only when `revealedCount == i`; panels are never revealed out of order.
  int _revealedCount = 0;

  bool get loading => _loading;
  String? get error => _error;
  DashboardCopy? get copy => _copy;
  int get revealedCount => _revealedCount;
  static const int panelCount = 4;

  /// Calls the Edge Function to fetch the cached view or generate one.
  /// Errors surface via [error] — never swallowed, never rendered as blanks.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final response = await _client.functions.invoke(
        'generate-dashboard-copy',
        body: {'loopId': loopId},
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw FormatException(
          'Unexpected response shape from generate-dashboard-copy',
          data,
        );
      }
      final view = data['view'];
      if (view is! Map<String, dynamic>) {
        throw FormatException('Response missing "view" object', data);
      }
      final generatedCopy = view['generated_copy'];
      if (generatedCopy is! Map<String, dynamic>) {
        throw FormatException('view missing "generated_copy" object', view);
      }
      _copy = DashboardCopy.fromJson(generatedCopy);
      _viewId = view['id'] as String?;
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
      await _client
          .from('phase2_dashboard_views')
          .update({column: true}).eq('id', viewId);
    } catch (err) {
      debugPrint('Failed to record $column for view $viewId: $err');
    }
  }
}
