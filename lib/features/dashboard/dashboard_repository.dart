import 'package:supabase_flutter/supabase_flutter.dart';

import '../assessment/assessment_controller.dart';
import '../assessment/scoring.dart';
import 'dashboard_copy.dart';

/// Result of fetching (or triggering generation of) a loop's Phase 2 reveal.
class DashboardView {
  const DashboardView({required this.id, required this.copy});

  /// The `phase2_dashboard_views.id` row — needed to record reveal progress.
  final String id;
  final DashboardCopy copy;
}

/// Parses the raw `generate-dashboard-copy` response body (the `{cached,
/// view}` shape both the cache-hit and cache-miss paths return) into a
/// [DashboardView]. Pure — no network — so it's testable against a captured
/// fixture without a Supabase client. Throws [FormatException] on any
/// missing/malformed field; errors must surface, never render a blank
/// reveal panel.
DashboardView parseDashboardViewResponse(dynamic data) {
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
  final id = view['id'];
  if (id is! String) {
    throw FormatException('view missing "id" string', view);
  }
  return DashboardView(id: id, copy: DashboardCopy.fromJson(generatedCopy));
}

/// Pure data access for Phase 2. No UI state (loading/error/reveal
/// progress) lives here — that's [DashboardController]'s job. Every method
/// throws on failure; callers surface the error, never swallow it.
class DashboardRepository {
  DashboardRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Reads the authoritative score/zone straight from `phase1_assessments`
  /// by `loop_id` — independent of whatever handed navigation to this
  /// screen, so a refresh or deep link to `/dashboard/:loopId` still shows
  /// the real result instead of dead-ending.
  Future<AssessmentResult> fetchScoredAssessment(String loopId) async {
    final row = await _client
        .from('phase1_assessments')
        .select('center_of_gravity, dominant_zone, consistency_flag')
        .eq('loop_id', loopId)
        .single();
    final centerOfGravity = row['center_of_gravity'] as num?;
    final dominantZone = row['dominant_zone'] as String?;
    if (centerOfGravity == null || dominantZone == null) {
      throw StateError('Assessment for loop $loopId has not been scored yet.');
    }
    return AssessmentResult(
      loopId: loopId,
      centerOfGravity: centerOfGravity.toDouble(),
      dominantZone: EnergyZone.fromToken(dominantZone),
      consistencyFlag: row['consistency_flag'] as String,
    );
  }

  /// Calls the Edge Function to fetch the cached view or generate one.
  Future<DashboardView> fetchOrGenerateCopy(String loopId) async {
    final response = await _client.functions.invoke(
      'generate-dashboard-copy',
      body: {'loopId': loopId},
    );
    return parseDashboardViewResponse(response.data);
  }

  /// Marks one reveal-tracking boolean column true on the user's own row.
  /// Telemetry, not the reveal itself — callers should log-and-continue on
  /// failure rather than block the user's progress.
  Future<void> markPanelOpened(String viewId, String column) {
    return _client
        .from('phase2_dashboard_views')
        .update({column: true}).eq('id', viewId);
  }

  /// Records how long the user spent on the reveal screen.
  Future<void> recordTimeOnScreen(String viewId, int seconds) {
    return _client
        .from('phase2_dashboard_views')
        .update({'time_on_screen_secs': seconds}).eq('id', viewId);
  }
}
