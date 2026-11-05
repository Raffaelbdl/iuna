import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/games/sentence_screen.dart';
import 'package:iuna/games/sentences.dart';

import 'sentence_deck.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

/// The particle the gap on screen hides, read off the deck's sentences.
String _answer(WidgetTester tester) {
  final text = tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.toPlainText())
      .firstWhere((t) => t.contains('￼'));
  final [before, after] = text.split('￼');
  final sentence = [
    for (final examples in kSentenceDeck.values)
      for (final (s, _) in examples) s,
  ].firstWhere((s) => s.startsWith(before) && s.endsWith(after));
  return sentence.substring(before.length, sentence.length - after.length);
}

void main() {
  testWidgets('a particle picked right, one picked wrong, the round summed', (
    tester,
  ) async {
    final (db, _) = await sentenceDeck();
    addTearDown(db.close);
    await tester.pumpWidget(
      MaterialApp(
        home: SentenceScreen(
          db: db,
          game: SentenceGame.particles,
          seed: 4,
          tiler: syncTiler(),
          speak: (_) {},
        ),
      ),
    );
    await _settle(tester);
    expect(find.text('FILL THE GAP'), findsOneWidget);
    expect(find.text('Check'), findsNothing, reason: 'a pick answers');

    await tester.tap(find.byKey(ValueKey('choice-${_answer(tester)}')));
    await tester.pump();
    expect(find.text('正解 · Right.'), findsOneWidget);
    expect(find.byTooltip('Skip sentence'), findsNothing);
    await tester.tap(find.text('Next'));
    await _settle(tester);

    final answer = _answer(tester);
    final wrong = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('choice-') &&
          (w.key! as ValueKey<String>).value != 'choice-$answer',
    );
    await tester.tap(wrong.first);
    await tester.pump();
    expect(find.text('Not quite.'), findsOneWidget);
    expect(find.text('The sentence reads:'), findsOneWidget);

    // Play out the deck's other sentences, then the summary.
    while (find.text('Next').evaluate().isNotEmpty) {
      await tester.tap(find.text('Next'));
      await _settle(tester);
      if (find.text('FILL THE GAP').evaluate().isEmpty) break;
      await tester.tap(find.byKey(ValueKey('choice-${_answer(tester)}')));
      await tester.pump();
    }
    expect(find.text('WORTH ANOTHER LOOK'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
