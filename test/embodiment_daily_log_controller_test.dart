import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/track/embodiment_daily_log_controller.dart';
import 'package:levels_native/features/track/embodiment_gate.dart';
import 'package:levels_native/features/track/track_content.dart';
import 'package:levels_native/features/track/track_tokens.dart';

/// Records inserted rows without touching Supabase, so
/// [EmbodimentDailyLogController]'s gate + save behavior can be pinned by
/// a fake client. Mirrors test/track_session_controller_test.dart's fake
/// pattern.
class _FakeEmbodimentDailyLogDataSource implements EmbodimentDailyLogDataSource {
  final List<String> calls = [];
  final List<Map<String, dynamic>> existingLogs = [];
  final List<Map<String, dynamic>> inserted = [];

  @override
  Future<List<Map<String, dynamic>>> fetchLogs(String sessionId) async {
    calls.add('fetchLogs');
    return existingLogs;
  }

  @override
  Future<void> insertLog(Map<String, dynamic> row) async {
    calls.add('insertLog');
    inserted.add(row);
  }
}

void main() {
  final start = DateTime(2026, 7, 1, 9);

  group('EmbodimentDailyLogController.load', () {
    test('computes the gate from existing logs', () async {
      final fake = _FakeEmbodimentDailyLogDataSource()
        ..existingLogs.add({'day_number': 1, 'completed_at': '2026-07-01T10:00:00Z'});
      final controller = EmbodimentDailyLogController(
        sessionId: 'session-1',
        startedAt: start,
        dataSource: fake,
        now: () => DateTime(2026, 7, 2, 8),
      );

      await controller.load();

      expect(fake.calls, ['fetchLogs']);
      expect(controller.gate!.status, EmbodimentDayStatus.open);
      expect(controller.gate!.dayNumber, 2);
      expect(controller.error, isNull);
    });

    test('exposes the correct static identity statement for the open day',
        () async {
      final fake = _FakeEmbodimentDailyLogDataSource();
      final controller = EmbodimentDailyLogController(
        sessionId: 'session-1',
        startedAt: start,
        dataSource: fake,
        now: () => DateTime(2026, 7, 3, 8), // day 3
      );

      await controller.load();

      expect(
        controller.todaysIdentityStatement,
        embodimentDailyIdentityStatements[2],
      );
    });
  });

  group('EmbodimentDailyLogController.saveDayLog — base fields', () {
    test('writes day_number, identity statement, body_response, and '
        'completed_at', () async {
      final fake = _FakeEmbodimentDailyLogDataSource();
      final controller = EmbodimentDailyLogController(
        sessionId: 'session-1',
        startedAt: start,
        dataSource: fake,
        now: () => start,
      );
      await controller.load();
      controller.selectBodyResponse(BodyResponse.trueOpen);

      await controller.saveDayLog();

      expect(fake.inserted, hasLength(1));
      final row = fake.inserted.single;
      expect(row['session_id'], 'session-1');
      expect(row['day_number'], 1);
      expect(row['identity_statement_shown'], embodimentDailyIdentityStatements[0]);
      expect(row['body_response'], 'true_open');
      expect(row['completed_at'], isNotNull);
      expect(row.containsKey('day6_delta_reported'), isFalse);
      expect(row.containsKey('day7_action_committed'), isFalse);
    });

    test('throws and never inserts when body_response is missing', () async {
      final fake = _FakeEmbodimentDailyLogDataSource();
      final controller = EmbodimentDailyLogController(
        sessionId: 'session-1',
        startedAt: start,
        dataSource: fake,
        now: () => start,
      );
      await controller.load();

      await expectLater(controller.saveDayLog(), throwsStateError);
      expect(fake.inserted, isEmpty);
    });

    test('throws when the day is already logged (gate not open)', () async {
      final fake = _FakeEmbodimentDailyLogDataSource()
        ..existingLogs.add({'day_number': 1, 'completed_at': '2026-07-01T10:00:00Z'});
      final controller = EmbodimentDailyLogController(
        sessionId: 'session-1',
        startedAt: start,
        dataSource: fake,
        now: () => start,
      );
      await controller.load();
      controller.selectBodyResponse(BodyResponse.trueOpen);

      expect(controller.gate!.status, EmbodimentDayStatus.alreadyLoggedToday);
      await expectLater(controller.saveDayLog(), throwsStateError);
      expect(fake.inserted, isEmpty);
    });

    test('throws when the 7-day window has elapsed', () async {
      final fake = _FakeEmbodimentDailyLogDataSource();
      final controller = EmbodimentDailyLogController(
        sessionId: 'session-1',
        startedAt: start,
        dataSource: fake,
        now: () => DateTime(2026, 7, 9),
      );
      await controller.load();
      controller.selectBodyResponse(BodyResponse.trueOpen);

      expect(controller.gate!.status, EmbodimentDayStatus.windowElapsed);
      await expectLater(controller.saveDayLog(), throwsStateError);
      expect(fake.inserted, isEmpty);
    });
  });

  group('EmbodimentDailyLogController.saveDayLog — day 6', () {
    test('requires and writes day6_delta_reported', () async {
      final fake = _FakeEmbodimentDailyLogDataSource();
      final controller = EmbodimentDailyLogController(
        sessionId: 'session-1',
        startedAt: start,
        dataSource: fake,
        now: () => DateTime(2026, 7, 6, 8), // day 6
      );
      await controller.load();
      expect(controller.gate!.dayNumber, 6);
      controller.selectBodyResponse(BodyResponse.strangeForeign);

      await expectLater(controller.saveDayLog(), throwsStateError);
      expect(fake.inserted, isEmpty);

      controller.selectDay6Delta(EmbodimentDelta.slightly);
      await controller.saveDayLog();

      final row = fake.inserted.single;
      expect(row['day6_delta_reported'], 'slightly');
      expect(row.containsKey('day7_action_committed'), isFalse);
    });
  });

  group('EmbodimentDailyLogController.saveDayLog — day 7', () {
    test('requires and writes day7_action_committed/day7_action_confirmed',
        () async {
      final fake = _FakeEmbodimentDailyLogDataSource();
      final controller = EmbodimentDailyLogController(
        sessionId: 'session-1',
        startedAt: start,
        dataSource: fake,
        now: () => DateTime(2026, 7, 7, 8), // day 7
      );
      await controller.load();
      expect(controller.gate!.dayNumber, 7);
      controller.selectBodyResponse(BodyResponse.falseLying);

      await expectLater(controller.saveDayLog(), throwsStateError);

      controller.setDay7ActionCommitted('Send the email I keep drafting.');
      await expectLater(controller.saveDayLog(), throwsStateError);

      controller.setDay7ActionConfirmed(true);
      await controller.saveDayLog();

      final row = fake.inserted.single;
      expect(row['day7_action_committed'], 'Send the email I keep drafting.');
      expect(row['day7_action_confirmed'], isTrue);
      expect(row.containsKey('day6_delta_reported'), isFalse);
    });

    test('day7_action_confirmed can be false and still saves', () async {
      final fake = _FakeEmbodimentDailyLogDataSource();
      final controller = EmbodimentDailyLogController(
        sessionId: 'session-1',
        startedAt: start,
        dataSource: fake,
        now: () => DateTime(2026, 7, 7, 8),
      );
      await controller.load();
      controller
        ..selectBodyResponse(BodyResponse.trueOpen)
        ..setDay7ActionCommitted('Something small.')
        ..setDay7ActionConfirmed(false);

      await controller.saveDayLog();

      expect(fake.inserted.single['day7_action_confirmed'], isFalse);
    });
  });
}
