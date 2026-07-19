import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/assessment/scoring.dart';
import 'package:levels_native/features/journey/journey_repository.dart'
    show UserCalibration;
import 'package:levels_native/features/reassessment/reassessment_controller.dart';
import 'package:levels_native/features/reassessment/reassessment_questions.dart'
    show
        Q3BlockFlag,
        RediagFeeling,
        RediagPattern,
        RediagResistance;
import 'package:levels_native/features/reassessment/reassessment_tokens.dart';

/// Records call order and parameters so [ReassessmentController]'s
/// insert -> RPC -> read-back submit contract (PRD M5.2 done-when) can be
/// pinned without a real Supabase client. Mirrors
/// test/drill_controller_test.dart's `_FakeDrillDataSource` pattern.
class _FakeReassessmentDataSource implements ReassessmentDataSource {
  final List<String> calls = [];
  final Map<String, dynamic> inserted = {};
  final Map<String, dynamic> processed = {};

  /// What the fake "row" reads back. Deliberately independent of the
  /// submitted answers, so a result that matches anything client-derivable
  /// instead of the row would fail the read-back test.
  Phase5Classification? readBackClassification =
      Phase5Classification.falsePositive;
  RoutingOutcome? readBackRouting = RoutingOutcome.retestScheduled;
  RediagClassification? readBackRediagClassification;

  final Map<String, dynamic> rediag = {};

  /// One row per (loopId, window), mirroring production's
  /// `one_window_per_loop` UNIQUE constraint (verified 2026-07-19).
  final Map<String, String> rowIdsByKey = {};
  final List<String> resetRowIds = [];
  int _nextId = 1;

  @override
  Future<String> insertOrResetReassessment({
    required String loopId,
    required ReassessmentWindow window,
  }) async {
    final key = '$loopId/${window.token}';
    final existing = rowIdsByKey[key];
    if (existing != null) {
      calls.add('resetReassessment');
      resetRowIds.add(existing);
      return existing;
    }
    calls.add('insertReassessment');
    inserted.addAll({
      'loop_id': loopId,
      'window_number': window.token,
    });
    final id = 'reassessment-${_nextId++}';
    rowIdsByKey[key] = id;
    return id;
  }

  @override
  Future<void> processReassessment({
    required ReassessmentWindow window,
    required String reassessmentId,
    required String q1Answer,
    required String q2Answer,
    required String q3Flag,
  }) async {
    calls.add('processReassessment');
    processed.addAll({
      'window': window,
      'reassessment_id': reassessmentId,
      'q1_answer': q1Answer,
      'q2_answer': q2Answer,
      'q3_flag': q3Flag,
    });
  }

  @override
  Future<ReassessmentResult> fetchResult(String reassessmentId) async {
    calls.add('fetchResult');
    return ReassessmentResult(
      reassessmentId: reassessmentId,
      classification: readBackClassification,
      routingOutcome: readBackRouting,
      rediagClassification: readBackRediagClassification,
    );
  }

  @override
  Future<void> routeFalsePositive({
    required String reassessmentId,
    required String resistance,
    required String feeling,
    required String pattern,
    String? freeText,
  }) async {
    calls.add('routeFalsePositive');
    rediag.addAll({
      'reassessment_id': reassessmentId,
      'resistance': resistance,
      'feeling': feeling,
      'pattern': pattern,
      'free_text': freeText,
    });
  }

  /// What the fake `user_calibration` row reads back (Window 3).
  UserCalibration? calibration = const UserCalibration(
    calibratedLevel: 380.5,
    verifiedFloor: 320,
    consecutiveVerifiedLoops: 2,
    peakLevel: 400,
    flowResident: false,
  );

  @override
  Future<UserCalibration?> fetchCalibration() async {
    calls.add('fetchCalibration');
    return calibration;
  }
}

ReassessmentController _answeredController(
  _FakeReassessmentDataSource fake, {
  ReassessmentWindow window = ReassessmentWindow.window2,
}) {
  final controller = ReassessmentController(
    loopId: 'loop-1',
    window: window,
    dataSource: fake,
  );
  controller
    ..selectQ1(P1Answer.courage)
    ..selectQ2(P1Answer.contentment)
    ..selectQ3(Q3BlockFlag.movement);
  return controller;
}

void main() {
  group('ReassessmentController.submit — Window 2 (PRD M5.2)', () {
    test('runs insert -> process -> read-back, in that order', () async {
      final fake = _FakeReassessmentDataSource();
      final controller = _answeredController(fake);

      await controller.submit();

      expect(
        fake.calls,
        ['insertReassessment', 'processReassessment', 'fetchResult'],
      );
    });

    test('inserts a bare window_2 row — the answers travel via the RPC, '
        'which writes them to the row itself (verified against the deployed '
        'function body 2026-07-19)', () async {
      final fake = _FakeReassessmentDataSource();
      final controller = _answeredController(fake);

      await controller.submit();

      expect(fake.inserted, {
        'loop_id': 'loop-1',
        'window_number': 'window_2',
      });
    });

    test("a retest resets the loop's one window_2 row instead of inserting "
        'a second (one_window_per_loop, verified 2026-07-19)', () async {
      final fake = _FakeReassessmentDataSource();
      final first = _answeredController(fake);
      await first.submit();

      final retest = _answeredController(fake);
      await retest.submit();

      expect(fake.rowIdsByKey.length, 1);
      expect(fake.resetRowIds, ['reassessment-1']);
      expect(fake.processed['reassessment_id'], 'reassessment-1');
      expect(
        fake.calls.where((c) => c == 'insertReassessment').length,
        1,
      );
    });

    test('processes the inserted row with the same answers', () async {
      final fake = _FakeReassessmentDataSource();
      final controller = _answeredController(fake);

      await controller.submit();

      expect(fake.processed['reassessment_id'], 'reassessment-1');
      expect(fake.processed['window'], ReassessmentWindow.window2);
      expect(fake.processed['q1_answer'], 'courage');
      expect(fake.processed['q2_answer'], 'contentment');
      expect(fake.processed['q3_flag'], 'movement');
    });

    test('the result comes only from the read-back row, never client math',
        () async {
      final fake = _FakeReassessmentDataSource();
      final controller = _answeredController(fake);

      final result = await controller.submit();

      // The fake row says false_positive/retest_scheduled — values no
      // client-side computation of the submitted answers would produce.
      expect(result.reassessmentId, 'reassessment-1');
      expect(result.classification, Phase5Classification.falsePositive);
      expect(result.routingOutcome, RoutingOutcome.retestScheduled);
    });

    test('throws when the processed row reads back without a classification',
        () async {
      final fake = _FakeReassessmentDataSource()
        ..readBackClassification = null;
      final controller = _answeredController(fake);

      await expectLater(controller.submit(), throwsStateError);
    });

    test('throws when incomplete and never touches the data source', () async {
      final fake = _FakeReassessmentDataSource();
      final controller = ReassessmentController(
        loopId: 'loop-1',
        window: ReassessmentWindow.window2,
        dataSource: fake,
      );

      await expectLater(controller.submit(), throwsStateError);
      expect(fake.calls, isEmpty);
    });
  });

  group('ReassessmentController.submitRediag — rediag path (PRD M5.3)', () {
    ReassessmentController rediagReadyController(
      _FakeReassessmentDataSource fake,
    ) {
      final controller = _answeredController(fake);
      controller
        ..selectRediagResistance(RediagResistance.specific)
        ..selectRediagFeeling(RediagFeeling.flatness)
        ..selectRediagPattern(RediagPattern.same);
      return controller;
    }

    test('calls routeFalsePositive then reads the row back, in order',
        () async {
      final fake = _FakeReassessmentDataSource();
      final controller = rediagReadyController(fake);

      await controller.submitRediag('reassessment-1');

      expect(fake.calls, ['routeFalsePositive', 'fetchResult']);
    });

    test('sends the three rediag tokens and omits empty free text', () async {
      final fake = _FakeReassessmentDataSource();
      final controller = rediagReadyController(fake);

      await controller.submitRediag('reassessment-1');

      expect(fake.rediag, {
        'reassessment_id': 'reassessment-1',
        'resistance': 'specific',
        'feeling': 'flatness',
        'pattern': 'same',
        'free_text': null,
      });
    });

    test('passes trimmed free text when provided', () async {
      final fake = _FakeReassessmentDataSource();
      final controller = rediagReadyController(fake)
        ..setRediagFreeText('  still tense at work  ');

      await controller.submitRediag('reassessment-1');

      expect(fake.rediag['free_text'], 'still tense at work');
    });

    test('renders rediag_classification and routing from the read-back row',
        () async {
      final fake = _FakeReassessmentDataSource()
        ..readBackRediagClassification =
            RediagClassification.reclassifyResidual
        ..readBackRouting = RoutingOutcome.trackReassignment;
      final controller = rediagReadyController(fake);

      final result = await controller.submitRediag('reassessment-1');

      expect(
        result.rediagClassification,
        RediagClassification.reclassifyResidual,
      );
      expect(result.routingOutcome, RoutingOutcome.trackReassignment);
    });

    test('throws when rediag is incomplete and never calls the RPC',
        () async {
      final fake = _FakeReassessmentDataSource();
      final controller = _answeredController(fake);

      await expectLater(
        controller.submitRediag('reassessment-1'),
        throwsStateError,
      );
      expect(fake.calls, isNot(contains('routeFalsePositive')));
    });
  });

  group('ReassessmentController.submit — Window 3 (PRD M5.5)', () {
    test('runs insert -> process_window3 -> read-back -> calibration, in '
        'order', () async {
      final fake = _FakeReassessmentDataSource();
      final controller =
          _answeredController(fake, window: ReassessmentWindow.window3);

      await controller.submit();

      expect(fake.calls, [
        'insertReassessment',
        'processReassessment',
        'fetchResult',
        'fetchCalibration',
      ]);
      expect(fake.processed['window'], ReassessmentWindow.window3);
    });

    test('inserts window_3 as the window_number', () async {
      final fake = _FakeReassessmentDataSource();
      final controller =
          _answeredController(fake, window: ReassessmentWindow.window3);

      await controller.submit();

      expect(fake.inserted['window_number'], 'window_3');
    });

    test('the result carries the calibration from the read-back row only',
        () async {
      final fake = _FakeReassessmentDataSource();
      final controller =
          _answeredController(fake, window: ReassessmentWindow.window3);

      final result = await controller.submit();

      expect(result.calibration, isNotNull);
      expect(result.calibration!.consecutiveVerifiedLoops, 2);
      expect(result.calibration!.verifiedFloor, 320);
      expect(result.calibration!.flowResident, isFalse);
    });

    test('throws when no calibration row reads back', () async {
      final fake = _FakeReassessmentDataSource()..calibration = null;
      final controller =
          _answeredController(fake, window: ReassessmentWindow.window3);

      await expectLater(controller.submit(), throwsStateError);
    });
  });

  group('new_loop loop completion (PRD M5.4)', () {
    test('the client performs NO loop write — the deployed RPC already '
        'marks the loop complete on true_ascension (verified against '
        'production 2026-07-19 via read-only schema dump)', () async {
      final fake = _FakeReassessmentDataSource()
        ..readBackClassification = Phase5Classification.trueAscension
        ..readBackRouting = RoutingOutcome.newLoop;
      final controller = _answeredController(fake);

      await controller.submit();

      // Exactly the three read/write steps and nothing else — a
      // markLoopComplete-style fourth call would fail this pin.
      expect(fake.calls, [
        'insertReassessment',
        'processReassessment',
        'fetchResult',
      ]);
    });
  });

  group('token mirrors (verified against production 2026-07-19)', () {
    test('ReassessmentWindow rejects window_1 — this build never writes it',
        () {
      expect(
        () => ReassessmentWindow.fromToken('window_1'),
        throwsArgumentError,
      );
      expect(ReassessmentWindow.tryFromToken('window_1'), isNull);
      expect(ReassessmentWindow.tryFromToken('window_2'),
          ReassessmentWindow.window2);
    });

    test('ClassificationCopy resolves all three classifications and would '
        'throw on an unknown one', () {
      for (final c in Phase5Classification.values) {
        expect(ClassificationCopy.of(c).headline, isNotEmpty);
        expect(ClassificationCopy.of(c).body, isNotEmpty);
      }
      // fromToken is the runtime guard for values outside the enum.
      expect(
        () => Phase5Classification.fromToken('made_up'),
        throwsArgumentError,
      );
    });

    test('RediagClassification mirrors the four deployed enum values', () {
      // Verified against production 2026-07-19 via read-only schema dump.
      expect(
        RediagClassification.values.map((v) => v.token),
        [
          'compliance_bypass',
          'surface_contact',
          'method_mismatch',
          'reclassify_residual',
        ],
      );
      expect(
        () => RediagClassification.fromToken('made_up'),
        throwsArgumentError,
      );
    });

    test('RediagCopy resolves all four classifications and never renders '
        'a raw token', () {
      for (final c in RediagClassification.values) {
        final copy = RediagCopy.of(c);
        expect(copy.headline, isNotEmpty);
        expect(copy.body, isNotEmpty);
        expect(copy.headline, isNot(contains(c.token)));
        expect(copy.body, isNot(contains(c.token)));
      }
    });
  });
}
