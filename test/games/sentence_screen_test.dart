import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/games/game_draw.dart';
import 'package:iuna/games/sentence_screen.dart';

import '../helpers/fake_path_provider.dart';
import 'game_test_helpers.dart';
import 'sentence_deck.dart';

/// Lets the database and the feed settle, then draws.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
  }
}

void main() {
  testWidgets('right, wrong and skipped, then the round summed up', (
    tester,
  ) async {
    final (db, _) = await sentenceDeck();
    addTearDown(db.close);
    final said = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: SentenceScreen(
          db: db,
          seed: 2,
          tiler: syncTiler(),
          speak: said.add,
        ),
      ),
    );
    await _settle(tester);

    // Right: the tiles in the sentence's own order. Until they are all
    // placed, Check says why it waits.
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('Place every tile to check'), findsOneWidget);
    var n = bankTileCount();
    await placeTiles(tester, [for (var i = 0; i < n; i++) i]);
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.text('正解 · Right.'), findsOneWidget);
    await tester.tap(find.byTooltip('Listen'));
    expect(said, hasLength(1));
    await tester.tap(find.text('Next'));
    await _settle(tester);

    // A placed tile goes back when tapped; then wrong: the verb first.
    n = bankTileCount();
    await placeTiles(tester, [0]);
    await tester.tap(find.byKey(const ValueKey('placed-0')));
    await tester.pump();
    expect(find.text('Tap the tiles in order'), findsOneWidget);
    await placeTiles(tester, [n - 1, for (var i = 0; i < n - 1; i++) i]);
    await tester.tap(find.text('Check'));
    await tester.pump();
    expect(find.text('Not quite.'), findsOneWidget);
    expect(find.byTooltip('Skip sentence'), findsNothing);
    await tester.tap(find.text('Next'));
    await _settle(tester);

    // Skipped: not counted.
    await tester.tap(find.byTooltip('Skip sentence'));
    await _settle(tester);

    n = bankTileCount();
    await placeTiles(tester, [for (var i = 0; i < n; i++) i]);
    await tester.tap(find.text('Check'));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await _settle(tester);

    // Four cards with a sentence: the round ends early, three played.
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('WORTH ANOTHER LOOK'), findsOneWidget);
    // A missed word opens its card.
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    final raw = await tester.runAsync(() => IunaRepository(db).getGameMemory());
    final memory = GameMemory.parse(raw);
    final missed = [
      for (final id in [1, 2, 3, 4, 5])
        if (memory.sighting(id)?.missed ?? false) id,
    ];
    expect(missed, hasLength(1));
    final seen = [
      for (final id in [1, 2, 3, 4, 5])
        if (memory.sighting(id) != null) id,
    ];
    expect(seen, hasLength(3), reason: 'the skipped card rests not');

    await tester.tap(find.text('Next round'));
    await _settle(tester);
    expect(find.textContaining('No more sentences'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without the dictionary, the download right there', (
    tester,
  ) async {
    useTempDocumentsDir('iuna_sentences_');
    final (db, _) = await sentenceDeck();
    addTearDown(db.close);
    await tester.pumpWidget(MaterialApp(home: SentenceScreen(db: db)));
    await _settle(tester);
    expect(find.textContaining('offline dictionary'), findsOneWidget);
    await tester.tap(find.text('Get the dictionary'));
    await _settle(tester);
    expect(find.text('Download the dictionary'), findsOneWidget);
    expect(find.text('Download'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
