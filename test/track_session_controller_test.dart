import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/drill/drill_tokens.dart';
import 'package:levels_native/features/track/track_session_controller.dart';
import 'package:levels_native/features/track/track_tokens.dart';

/// Records call order and simulates a single-table store, so
/// [TrackSessionController]'s start/resume and per-stage save behavior can
/// be pinned by a fake client (PRD M4.2 done-when). Mirrors
/// test/drill_controller_test.dart's `_FakeDrillDataSource` pattern.
class _FakeTrackSessionDataSource implements TrackSessionDataSource {
  final List<String> calls = [];
  final Map<String, Map<String, dynamic>> sessions = {};
  int insertCount = 0;
  int _nextId = 1;

  @override
  Future<Map<String, dynamic>?> fetchOpenSession({
    required String loopId,
    required AscensionTrack track,
  }) async {
    calls.add('fetchOpenSession');
    for (final row in sessions.values) {
      if (row['loop_id'] == loopId &&
          row['track_type'] == track.token &&
          row['completed_at'] == null) {
        return Map<String, dynamic>.from(row);
      }
    }
    return null;
  }

  @override
  Future<String> insertSession({
    required String loopId,
    required AscensionTrack track,
  }) async {
    calls.add('insertSession');
    insertCount++;
    final id = 'session-${_nextId++}';
    sessions[id] = {
      'id': id,
      'loop_id': loopId,
      'track_type': track.token,
      'completed_at': null,
    };
    return id;
  }

  @override
  Future<void> updateSession({
    required String sessionId,
    required Map<String, dynamic> patch,
  }) async {
    calls.add('updateSession');
    sessions[sessionId] = {...sessions[sessionId]!, ...patch};
  }
}

void main() {
  group('TrackSessionController.load — start/resume', () {
    test('inserts a new session when none is open', () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.completion,
        dataSource: fake,
      );

      await controller.load();

      expect(fake.calls, ['fetchOpenSession', 'insertSession']);
      expect(fake.insertCount, 1);
      expect(controller.sessionId, isNotNull);
      expect(controller.error, isNull);
    });

    test('resumes the open session instead of inserting a second one',
        () async {
      final fake = _FakeTrackSessionDataSource();
      final first = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.completion,
        dataSource: fake,
      );
      await first.load();
      first
        ..setCompletionStatement('Finish the deck')
        ..selectPrepDuration(PrepDuration.years1to3);
      await first.saveCompletionStage();

      final second = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.completion,
        dataSource: fake,
      );
      await second.load();

      expect(fake.insertCount, 1, reason: 'never two open sessions per loop');
      expect(second.sessionId, first.sessionId);
      expect(second.completionStatement, 'Finish the deck');
      expect(second.prepDuration, PrepDuration.years1to3);
    });

    test('a completed session does not block starting a new one for the '
        'next loop', () async {
      final fake = _FakeTrackSessionDataSource();
      final done = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.completion,
        dataSource: fake,
      );
      await done.load();
      done
        ..setCompletionStatement('Finish the deck')
        ..selectPrepDuration(PrepDuration.under3mo);
      await done.saveCompletionStage();
      await done.finish(success: true);

      final next = TrackSessionController(
        loopId: 'loop-2',
        track: AscensionTrack.completion,
        dataSource: fake,
      );
      await next.load();

      expect(fake.insertCount, 2);
      expect(next.sessionId, isNot(done.sessionId));
    });
  });

  group('TrackSessionController — completion column mapping', () {
    test('saveCompletionStage writes statement + duration', () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.completion,
        dataSource: fake,
      );
      await controller.load();
      controller
        ..setCompletionStatement('Finish the deck')
        ..selectPrepDuration(PrepDuration.over3yr);

      await controller.saveCompletionStage();

      final row = fake.sessions[controller.sessionId]!;
      expect(row['completion_statement'], 'Finish the deck');
      expect(row['preparation_duration'], 'over_3yr');
    });

    test('throws when incomplete and never calls updateSession', () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.completion,
        dataSource: fake,
      );
      await controller.load();

      await expectLater(controller.saveCompletionStage(), throwsStateError);
      expect(fake.calls, isNot(contains('updateSession')));
    });
  });

  group('TrackSessionController — belief_audit column mapping', () {
    test('addFlaggedBelief keeps all four arrays index-aligned', () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.beliefAudit,
        dataSource: fake,
      );
      await controller.load();

      controller
        ..addFlaggedBelief('I am not enough')
        ..addFlaggedBelief('I will be abandoned')
        ..addFlaggedBelief('I have to earn rest');

      expect(controller.flaggedBeliefs.length, 3);
      expect(controller.beliefAuthorshipAge.length, 3);
      expect(controller.beliefAuthorshipSource.length, 3);
      expect(controller.crossExamVerdict.length, 3);

      controller
        ..setBeliefAuthorship(0, age: 8, source: 'a teacher')
        ..setBeliefAuthorship(1, age: 12, source: 'a breakup')
        ..setBeliefAuthorship(2, age: 20, source: 'a parent')
        ..setCrossExamVerdict(0, BeliefVerdict.conclusion)
        ..setCrossExamVerdict(1, BeliefVerdict.fact)
        ..setCrossExamVerdict(2, BeliefVerdict.conclusion);

      expect(controller.isBeliefAuditStageComplete, isTrue);

      await controller.saveBeliefAuditStage();

      final row = fake.sessions[controller.sessionId]!;
      expect(row['flagged_beliefs'], [
        'I am not enough',
        'I will be abandoned',
        'I have to earn rest',
      ]);
      expect(row['belief_authorship_age'], [8, 12, 20]);
      expect(row['belief_authorship_source'],
          ['a teacher', 'a breakup', 'a parent']);
      expect(row['cross_exam_verdict'], ['conclusion', 'fact', 'conclusion']);
    });

    test('is incomplete while any belief still has a null field', () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.beliefAudit,
        dataSource: fake,
      );
      await controller.load();

      controller
        ..addFlaggedBelief('I am not enough')
        ..addFlaggedBelief('I will be abandoned')
        ..setBeliefAuthorship(0, age: 8, source: 'a teacher')
        ..setCrossExamVerdict(0, BeliefVerdict.conclusion);

      expect(controller.isBeliefAuditStageComplete, isFalse);
      await expectLater(controller.saveBeliefAuditStage(), throwsStateError);
    });

    test('setBeliefAuthorship rejects an out-of-range index', () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.beliefAudit,
        dataSource: fake,
      );
      await controller.load();
      controller.addFlaggedBelief('I am not enough');

      expect(
        () => controller.setBeliefAuthorship(1, age: 10, source: 'x'),
        throwsRangeError,
      );
    });
  });

  group('TrackSessionController — embodiment session column mapping', () {
    test('saveEmbodimentSessionStage writes location/sensations/response',
        () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.embodiment,
        dataSource: fake,
      );
      await controller.load();
      controller
        ..setBodyLocationTapped('chest')
        ..setSensationWords(['tight', 'hot'])
        ..selectStage4Response(Stage4Response.shifted);

      await controller.saveEmbodimentSessionStage();

      final row = fake.sessions[controller.sessionId]!;
      expect(row['body_location_tapped'], 'chest');
      expect(row['sensation_words'], ['tight', 'hot']);
      expect(row['stage4_response'], 'shifted');
    });
  });

  group('TrackSessionController — commitment column mapping', () {
    test('saveDeclarationStage writes declaration + constraint + schedules '
        'checkin 72h out', () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.commitment,
        dataSource: fake,
      );
      await controller.load();
      final before = DateTime.now().toUtc();
      controller
        ..setDeclarationText('Send the email by Friday')
        ..selectConstraintType(ConstraintType.audience);

      await controller.saveDeclarationStage();

      final row = fake.sessions[controller.sessionId]!;
      expect(row['declaration_text'], 'Send the email by Friday');
      expect(row['constraint_chosen'], 'audience');
      final scheduled = DateTime.parse(row['checkin_scheduled_at'] as String);
      final delta = scheduled.difference(before);
      expect(delta.inHours, greaterThanOrEqualTo(71));
      expect(delta.inHours, lessThanOrEqualTo(73));
    });

    test('saveCheckinStage requires blocker text unless the answer is yes',
        () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.commitment,
        dataSource: fake,
      );
      await controller.load();
      controller.selectCheckinResponse(CheckinResponse.partially);

      expect(controller.isCheckinStageComplete, isFalse);
      await expectLater(controller.saveCheckinStage(), throwsStateError);

      controller.setCheckinBlockerText('Ran out of time');
      expect(controller.isCheckinStageComplete, isTrue);
      await controller.saveCheckinStage();

      final row = fake.sessions[controller.sessionId]!;
      expect(row['checkin_response'], 'partially');
      expect(row['checkin_blocker_text'], 'Ran out of time');
    });

    test('saveCheckinStage allows a bare yes with no blocker text', () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.commitment,
        dataSource: fake,
      );
      await controller.load();
      controller.selectCheckinResponse(CheckinResponse.yes);

      expect(controller.isCheckinStageComplete, isTrue);
      await controller.saveCheckinStage();

      final row = fake.sessions[controller.sessionId]!;
      expect(row['checkin_response'], 'yes');
    });
  });

  group('TrackSessionController.finish', () {
    test('persists completed_at and the caller-supplied success value',
        () async {
      final fake = _FakeTrackSessionDataSource();
      final controller = TrackSessionController(
        loopId: 'loop-1',
        track: AscensionTrack.completion,
        dataSource: fake,
      );
      await controller.load();

      await controller.finish(success: false);

      final row = fake.sessions[controller.sessionId]!;
      expect(row['completed_at'], isNotNull);
      expect(row['success_state_reached'], isFalse);
    });
  });
}
