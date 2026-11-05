import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/games/game_draw.dart';
import 'package:iuna/games/pairs_screen.dart';

import 'game_test_helpers.dart';

const _words = [
  ('猫', 'ねこ', 'cat'),
  ('犬', 'いぬ', 'dog'),
  ('熊', 'くま', 'bear'),
  ('鳥', 'とり', 'bird'),
  ('魚', 'さかな', 'fish'),
  ('馬', 'うま', 'horse'),
];

/// Owns every word in [_words], plus one new and one suspended card the
/// games must leave alone.
Future<(AppDatabase, Map<String, int>)> _deck() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final ids = {
    for (final (kanji, kana, meaning) in _words)
      kanji: await ownCard(db, kanji, kana, meaning),
  };
  await ownCard(db, '蛇', 'へび', 'snake', isNew: true);
  await ownCard(db, '蛙', 'かえる', 'frog', suspended: true);
  return (db, ids);
}

Future<void> _open(WidgetTester tester, PairsScreen screen) async {
  await tester.pumpWidget(MaterialApp(home: screen));
  await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  await tester.pump();
}

void main() {
  test('gameCards leaves out new and suspended cards', () async {
    final (db, ids) = await _deck();
    addTearDown(db.close);
    final cards = await IunaRepository(db).gameCards();
    expect(cards.map((c) => c.card.id).toSet(), {
      for (final w in _words) ids[w.$1],
    });
  });

  testWidgets('a round played through, a miss remembered', (tester) async {
    final (db, ids) = await _deck();
    addTearDown(db.close);
    var t = DateTime(2026, 11, 5, 9);
    await _open(tester, PairsScreen(db: db, seed: 3, clock: () => t));

    // The first round asks readings, and has room for all six words.
    expect(find.text('KANJI ↔ READING'), findsOneWidget);
    await playPair(tester, ids['猫']!, ids['犬']!);
    // Both tiles of a miss carry a mark, not just a colour, beside the
    // top bar's Close.
    expect(find.byIcon(Icons.close_rounded), findsNWidgets(3));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    t = t.add(const Duration(seconds: 42));
    await clearRound(tester, ids.values);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('All pairs found.'), findsOneWidget);
    expect(find.text('0:42'), findsOneWidget);
    expect(find.text('miss'), findsOneWidget);
    expect(find.text('WORTH ANOTHER LOOK'), findsOneWidget);
    expect(find.text('cat'), findsOneWidget);

    final raw = await tester.runAsync(() => IunaRepository(db).getGameMemory());
    final memory = GameMemory.parse(raw);
    expect(memory.session, 1);
    expect(memory.sighting(ids['猫']!)!.missed, isTrue);
    expect(memory.sighting(ids['犬']!)!.missed, isFalse);

    // The next round takes the next mode.
    await tester.tap(find.text('Next round'));
    await tester.pump();
    expect(find.text('WORD ↔ MEANING'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('skip deals the next mode and keeps only real misses', (
    tester,
  ) async {
    final (db, ids) = await _deck();
    addTearDown(db.close);
    await _open(tester, PairsScreen(db: db, seed: 3));

    expect(find.text('KANJI ↔ READING'), findsOneWidget);
    await playPair(tester, ids['猫']!, ids['犬']!);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('Skip round'));
    await tester.pump();
    expect(find.text('WORD ↔ MEANING'), findsOneWidget);
    expect(find.text('0 of ${_words.length} matched'), findsOneWidget);

    final raw = await tester.runAsync(() => IunaRepository(db).getGameMemory());
    final memory = GameMemory.parse(raw);
    expect(memory.sighting(ids['猫']!)!.missed, isTrue);
    expect(memory.sighting(ids['犬']!)!.missed, isFalse);

    // Nothing left to skip once the round is cleared.
    await clearRound(tester, ids.values);
    expect(find.byTooltip('Skip round'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a sound tile speaks its reading, again when re-tapped', (
    tester,
  ) async {
    final (db, ids) = await _deck();
    addTearDown(db.close);
    // Modes take turns: sound is the third round.
    final said = <String>[];
    await _open(tester, PairsScreen(db: db, seed: 3, speak: said.add));
    for (var round = 0; round < 2; round++) {
      await clearRound(tester, ids.values);
      await tester.tap(find.text('Next round'));
      await tester.pump();
    }
    expect(find.text('SOUND ↔ WORD'), findsOneWidget);
    final cat = pairTile('left', ids['猫']!);
    await tester.tap(cat);
    await tester.tap(cat);
    await tester.pump();
    expect(said, ['ねこ', 'ねこ']);
    expect(find.byIcon(Icons.volume_up_rounded), findsNWidgets(_words.length));
    await tester.pumpWidget(const SizedBox());
  });
}
