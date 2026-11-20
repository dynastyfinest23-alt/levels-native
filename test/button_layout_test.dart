// Purpose: pins fix 5 (design review 2026-11-09, issues 1 and 2): the app
// theme gives FilledButton a 48px minimum height, and the paged-flow bottom
// CTA stays inside the 560px content column on a wide window.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levels_native/core/design_tokens.dart';
import 'package:levels_native/core/widgets/column_cta.dart';
import 'package:levels_native/main.dart' show levelsTheme;

// shrinkWrap removes the default 48px tap-target padding, which would report
// 48px for any button and make these checks pass without the fix.
// compact density is what desktop web (Chrome on Windows) applies; the test
// platform defaults to standard, which hid the 8px loss until Chrome showed it.
final _measured = levelsTheme.copyWith(
  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  visualDensity: VisualDensity.compact,
);

void main() {
  testWidgets('FilledButton is at least 48px tall under the app theme',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: _measured,
      home: Scaffold(
        body: Center(child: FilledButton(onPressed: () {}, child: const Text('Go'))),
      ),
    ));
    expect(tester.getSize(find.byType(FilledButton)).height,
        greaterThanOrEqualTo(LevelsSpace.buttonMinHeight));
  });

  testWidgets('ColumnCta stays within the content column on a wide window',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: _measured,
      home: Scaffold(
        bottomNavigationBar: ColumnCta(label: 'Continue', onPressed: () {}),
      ),
    ));
    final size = tester.getSize(find.byType(FilledButton));
    expect(size.width,
        LevelsSpace.contentMaxWidth - 2 * LevelsSpace.screenGutter);
    expect(size.height, greaterThanOrEqualTo(LevelsSpace.buttonMinHeight));
  });
}
