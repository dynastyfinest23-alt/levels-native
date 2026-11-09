// Purpose: pins the shared Likert/answer card extracted from the Phase 1
// assessment screen (block-map plan Task 1): label, tap callback, and the
// selected left-accent border (2px neutralAccent vs 1px glassStroke).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/core/design_tokens.dart';
import 'package:levels_native/core/widgets/answer_card.dart';

BorderSide _leftBorder(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byType(AnswerCard), matching: find.byType(Container)),
  );
  final decoration = container.decoration! as BoxDecoration;
  return (decoration.border! as Border).left;
}

Future<void> _pump(WidgetTester tester,
    {required bool selected, VoidCallback? onTap}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: AnswerCard(
        label: 'Often like me',
        selected: selected,
        onTap: onTap ?? () {},
      ),
    ),
  ));
}

void main() {
  testWidgets('answer card shows label and calls onTap', (tester) async {
    var taps = 0;
    await _pump(tester, selected: true, onTap: () => taps++);
    expect(find.text('Often like me'), findsOneWidget);
    await tester.tap(find.text('Often like me'));
    expect(taps, 1);
  });

  testWidgets('selected card has a 2px neutralAccent left border',
      (tester) async {
    await _pump(tester, selected: true);
    final side = _leftBorder(tester);
    expect(side.width, 2);
    expect(side.color, LevelsColors.neutralAccent);
  });

  testWidgets('unselected card has a 1px glassStroke left border',
      (tester) async {
    await _pump(tester, selected: false);
    final side = _leftBorder(tester);
    expect(side.width, 1);
    expect(side.color, LevelsColors.glassStroke);
  });
}
