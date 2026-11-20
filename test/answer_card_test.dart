// Purpose: pins the shared answer card (design review 2026-11-09, issues 3
// and 4, fix 5): label and tap, a uniform rounded border whose selected state
// is 2px neutralAccent vs 1px glassStroke on all four sides, full column
// width, and a selected semantics flag.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/core/design_tokens.dart';
import 'package:levels_native/core/widgets/answer_card.dart';

BorderSide _side(WidgetTester tester) {
  final material = tester.widget<Material>(
    find.descendant(of: find.byType(AnswerCard), matching: find.byType(Material)).first,
  );
  final shape = material.shape! as RoundedRectangleBorder;
  expect(shape.borderRadius, BorderRadius.circular(LevelsSpace.radiusPanel));
  return shape.side;
}

Future<void> _pump(WidgetTester tester,
    {required bool selected, VoidCallback? onTap}) {
  return tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnswerCard(
                label: 'Often like me',
                selected: selected,
                onTap: onTap ?? () {},
              ),
            ],
          ),
        ),
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

  testWidgets('selected card has a 2px neutralAccent border all round',
      (tester) async {
    await _pump(tester, selected: true);
    final side = _side(tester);
    expect(side.width, 2);
    expect(side.color, LevelsColors.neutralAccent);
  });

  testWidgets('unselected card has a 1px glassStroke border all round',
      (tester) async {
    await _pump(tester, selected: false);
    final side = _side(tester);
    expect(side.width, 1);
    expect(side.color, LevelsColors.glassStroke);
  });

  testWidgets('card fills the column width, not the text width',
      (tester) async {
    await _pump(tester, selected: false);
    expect(tester.getSize(find.byType(AnswerCard)).width, 400);
  });

  testWidgets('selected state is exposed to semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, selected: true);
    expect(
      tester.getSemantics(find.byType(AnswerCard)),
      matchesSemantics(
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
        label: 'Often like me',
      ),
    );
    handle.dispose();
  });
}
