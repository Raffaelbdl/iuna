import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/widgets/progress_dots.dart';

void main() {
  /// 60 cards overflow the 300px row, so this renders the fallback bar.
  Future<Size> fillSizeAt(WidgetTester tester, int index) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ProgressDots(count: 60, index: index),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(
      find.descendant(
        of: find.byType(AnimatedFractionallySizedBox),
        matching: find.byType(DecoratedBox),
      ),
    );
  }

  testWidgets('the long-session bar fills as the session advances', (
    tester,
  ) async {
    expect(await fillSizeAt(tester, 0), const Size(5, 6));
    expect(await fillSizeAt(tester, 29), const Size(150, 6));
    expect(await fillSizeAt(tester, 59), const Size(300, 6));
  });
}
