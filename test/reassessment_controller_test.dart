import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/assessment/scoring.dart';
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
  String? readBackRediagClassification;

  final Map<String, dynamic> rediag = {};
  int _nextId = 1;

  @override
  Future<String> insertReassessment({
    required String loopId,
    required ReassessmentWindow window,
    required String q1Answer,
    required String q2Answer,
    required String q3Flag,
  }) async {
    calls.add('insertReassessment');
    inserted.addAll({
      'loop_id': loopId,
      'window_number': window.token,
      'q1_answer': q1Answer,
      'q2_answer': q2Answer,
      'q3_block_flag': q3Flag,
    });
    return 'reassessment-${_nextId++}';
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

  final List<String> completedLoops = [];

  @override
  Future<void> markLoopComplete(String loopId) async {
    calls.add('markLoopComplete');
    completedLoops.add(loopId);
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

    test('inserts window_2 with the three answer tokens', () async {
      final fake = _FakeReassessmentDataSource();
      final controller = _answeredController(fake);

      await controller.submit();

      expect(fake.inserted, {
        'loop_id': 'loop-1',
        'window_number': 'window_2',
        'q1_answer': 'courage',
        'q2_answer': 'contentment',
        'q3_block_flag': 'movement',
      });
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
        ..readBackRediagClassification = 'some_rediag_token'
        ..readBackRouting = RoutingOutcome.trackReassignment;
      final controller = rediagReadyController(fake);

      final result = await controller.submitRediag('reassessment-1');

      expect(result.rediagClassification, 'some_rediag_token');
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

  group('ReassessmentController — new_loop marks the loop complete '
      '(PRD M5.4)', () {
    test('submit marks the loop complete after a new_loop read-back',
        () async {
      final fake = _FakeReassessmentDataSource()
        ..readBackClassification = Phase5Classification.trueAscension
        ..readBackRouting = RoutingOutcome.newLoop;
      final controller = _answeredController(fake);

      await controller.submit();

      expect(fake.calls, [
        'insertReassessment',
        'processReassessment',
        'fetchResult',
        'markLoopComplete',
      ]);
      expect(fake.completedLoops, ['loop-1']);
    });

    test('submit leaves the loop alone for every other outcome', () async {
      for (final outcome in RoutingOutcome.values) {
        if (outcome == RoutingOutcome.newLoop) continue;
        final fake = _FakeReassessmentDataSource()
          ..readBackClassification = Phase5Classification.residualCharge
          ..readBackRouting = outcome;
        final controller = _answeredController(fake);

        await controller.submit();

        expect(fake.completedLoops, isEmpty, reason: outcome.token);
      }
    });

    test('submitRediag also marks the loop complete on a new_loop outcome',
        () async {
      final fake = _FakeReassessmentDataSource()
        ..readBackClassification = Phase5Classification.falsePositive
        ..readBackRouting = RoutingOutcome.newLoop;
      final controller = _answeredController(fake)
        ..selectRediagResistance(RediagResistance.none)
        ..selectRediagFeeling(RediagFeeling.relief)
        ..selectRediagPattern(RediagPattern.handledDifferently);

      await controller.submitRediag('reassessment-1');

      expect(fake.completedLoops, ['loop-1']);
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
  });
}
