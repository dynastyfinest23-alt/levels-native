import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/features/reassessment/reassessment_controller.dart';
import 'package:levels_native/features/reassessment/reassessment_screen.dart';
import 'package:levels_native/features/reassessment/reassessment_tokens.dart';

/// Widget-level pin for PRD M5.3's done-when: the rediag pages mount ONLY
/// when the read-back classification is `false_positive`. Uses a fake data
/// source so no Supabase client is involved.
class _FakeDataSource implements ReassessmentDataSource {
  _FakeDataSource({required this.classification});

  final Phase5Classification classification;
  final List<String> calls = [];

  @override
  Future<String> insertReassessment({
    required String loopId,
    required ReassessmentWindow window,
    required String q1Answer,
    required String q2Answer,
    required String q3Flag,
  }) async {
    calls.add('insertReassessment');
    return 'reassessment-1';
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
  }

  @override
  Future<ReassessmentResult> fetchResult(String reassessmentId) async {
    calls.add('fetchResult');
    return ReassessmentResult(
      reassessmentId: reassessmentId,
      classification: classification,
      routingOutcome: RoutingOutcome.retestScheduled,
      rediagClassification:
          classification == Phase5Classification.falsePositive
              ? 'some_rediag_token'
              : null,
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
  }

  @override
  Future<void> markLoopComplete(String loopId) async {
    calls.add('markLoopComplete');
  }
}

const _rediagQ1Prompt = "If change hasn't held, where does it show up?";

Future<ReassessmentController> _pumpFlow(
  WidgetTester tester,
  _FakeDataSource fake,
) async {
  final controller = ReassessmentController(
    loopId: 'loop-1',
    window: ReassessmentWindow.window2,
    dataSource: fake,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: ReassessmentFlow(
        loopId: 'loop-1',
        window: ReassessmentWindow.window2,
        controller: controller,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _tapOption(WidgetTester tester, String label) async {
  // The bundled Fraunces/Inter assets don't load in flutter_test, so the
  // fallback font renders the prompt several lines taller than production
  // and later options start out scrolled under the bottom button bar.
  final target = find.text(label);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FilledButton, label));
  await tester.pumpAndSettle();
}

/// Answers the three main questions and submits. Taps the first option on
/// each page — the test viewport is short, and the ListView only builds the
/// options currently visible.
Future<void> _submitMainFlow(WidgetTester tester) async {
  await _tapOption(tester, 'My own defects. I have sabotaged everything good');
  await _tapButton(tester, 'Continue');
  await _tapOption(tester, 'Heaviness, like moving through wet sand');
  await _tapButton(tester, 'Continue');
  await _tapOption(tester, 'I reacted the same old way, maybe even stronger');
  await _tapButton(tester, 'Finish');
}

void main() {
  testWidgets(
    'rediag pages mount when the read-back row says false_positive',
    (tester) async {
      final fake =
          _FakeDataSource(classification: Phase5Classification.falsePositive);
      await _pumpFlow(tester, fake);
      expect(find.text(_rediagQ1Prompt), findsNothing);

      await _submitMainFlow(tester);

      // The flow continued straight into rediag Q1 — no classification
      // result view in between.
      expect(find.text(_rediagQ1Prompt), findsOneWidget);
      expect(find.text('The change held'), findsNothing);

      // Complete the rediag path: three selects, optional free text, Finish.
      await _tapOption(
        tester,
        'One particular situation or person, not everywhere',
      );
      await _tapButton(tester, 'Continue');
      await _tapOption(tester, 'Relief, like something let go');
      await _tapButton(tester, 'Continue');
      await _tapOption(
        tester,
        'Noticeably different. I caught myself doing something new',
      );
      await _tapButton(tester, 'Continue');
      expect(
        find.text(
          "Anything about the last few days these questions didn't capture?",
        ),
        findsOneWidget,
      );
      await _tapButton(tester, 'Finish');

      expect(fake.calls, contains('routeFalsePositive'));
      expect(find.text('Thank you'), findsOneWidget);
    },
  );

  testWidgets(
    'rediag pages never mount on true_ascension — the classification '
    'result renders directly',
    (tester) async {
      final fake =
          _FakeDataSource(classification: Phase5Classification.trueAscension);
      await _pumpFlow(tester, fake);

      await _submitMainFlow(tester);

      expect(find.text('The change held'), findsOneWidget);
      expect(find.text(_rediagQ1Prompt), findsNothing);
      expect(fake.calls, isNot(contains('routeFalsePositive')));
    },
  );
}
