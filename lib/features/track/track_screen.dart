import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design_tokens.dart';
import '../../core/widgets/breathing_dot.dart';
import '../drill/drill_tokens.dart' show AscensionTrack;
import 'commitment_screen.dart';
import 'completion_screen.dart';
import 'track_widgets.dart';

/// Entry point for `/track/:loopId`: reads the loop's `assigned_track`
/// (set by `process_phase3_drill`, PRD M3.3) and renders the matching
/// track flow. Only `completion` and `commitment` are built (PRD M4.3);
/// `belief_audit`/`embodiment` show a coming-soon placeholder pending
/// M4.4/M4.5, matching `router.dart`'s existing placeholder convention.
class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key, required this.loopId});

  final String loopId;

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  bool _loading = true;
  String? _error;
  AscensionTrack? _track;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final row = await Supabase.instance.client
          .from('ascension_loops')
          .select('assigned_track')
          .eq('id', widget.loopId)
          .single();
      final token = row['assigned_track'] as String?;
      if (token == null) {
        throw StateError('This loop has no assigned track yet.');
      }
      if (!mounted) return;
      setState(() => _track = AscensionTrack.fromToken(token));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: BreathingDot()));
    }
    if (_error != null) {
      return Scaffold(
        body: TrackErrorView(
          message: 'Could not load your track.',
          error: _error!,
          onRetry: _load,
        ),
      );
    }
    return switch (_track!) {
      AscensionTrack.completion => CompletionScreen(loopId: widget.loopId),
      AscensionTrack.commitment => CommitmentScreen(loopId: widget.loopId),
      AscensionTrack.beliefAudit ||
      AscensionTrack.embodiment =>
        _TrackComingSoon(loopId: widget.loopId),
    };
  }
}

/// Placeholder for the two tracks not yet built (M4.4, M4.5). Matches
/// `router.dart`'s `_ComingSoonScreen`: displayTitle + one body line + text
/// button home (MASTER.md §6) — placeholders stay humble.
class _TrackComingSoon extends StatelessWidget {
  const _TrackComingSoon({required this.loopId});

  final String loopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Track', style: LevelsType.displayTitle),
            const SizedBox(height: 8),
            Text(
              'This track is coming soon.',
              style: LevelsType.body.copyWith(color: LevelsColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }
}
