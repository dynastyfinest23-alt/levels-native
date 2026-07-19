import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/assessment/scoring.dart';
import 'package:levels_native/features/reassessment/reassessment_controller.dart';
import 'package:levels_native/features/reassessment/reassessment_questions.dart';
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
    );
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
