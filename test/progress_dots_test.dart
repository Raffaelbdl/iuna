import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/widgets/progress_dots.dart';

void main() {
  Future<void> pumpDots(
    WidgetTester tester, {
    required int count,
    required int index,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ProgressDots(count: count, index: index),
            ),
          ),
        ),
      ),
    );
  }

  Size fillSize(WidgetTester tester) {
    final fill = find.descendant(
      of: find.byType(AnimatedFractionallySizedBox),
      matching: find.byType(DecoratedBox),
    );
    return tester.getSize(fill);
  }

  testWidgets('long sessions fall back to a bar whose fill is visible', (
    tester,
  ) async {
    await pumpDots(tester, count: 60, index: 29);
    await tester.pumpAndSettle();

    expect(fillSize(tester), const Size(150, 6));
  });

  testWidgets('the bar fill grows as the session advances', (tester) async {
    await pumpDots(tester, count: 60, index: 0);
    await tester.pumpAndSettle();
    expect(fillSize(tester).width, closeTo(5, 0.01));

    await pumpDots(tester, count: 60, index: 59);
    await tester.pumpAndSettle();
    expect(fillSize(tester), const Size(300, 6));
  });
}
