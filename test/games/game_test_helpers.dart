import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';

/// Adds a card and owns it, met already unless [isNew]; returns its id.
Future<int> ownCard(
  AppDatabase db,
  String kanji,
  String kana,
  String meaning, {
  double ease = 2.0,
  bool isNew = false,
  bool suspended = false,
}) async {
  final now = DateTime(2026, 11, 5);
  final id = await db
      .into(db.cards)
      .insert(
        CardsCompanion.insert(kanji: kanji, kana: kana, meaning: meaning),
      );
  await db
      .into(db.userCards)
      .insert(
        UserCardsCompanion.insert(
          cardId: Value(id),
          ease: Value(ease),
          isNew: Value(isNew),
          suspended: Value(suspended),
          nextDue: now,
          obtainedAt: now,
        ),
      );
  return id;
}

/// A Pairs tile: [side] is `left` or `right`.
Finder pairTile(String side, int id) => find.byKey(ValueKey('pair-$side-$id'));

/// Taps a left tile, then a right one.
Future<void> playPair(WidgetTester tester, int left, int right) async {
  await tester.tap(pairTile('left', left));
  await tester.tap(pairTile('right', right));
  await tester.pump();
}

/// Those of [ids] the round on screen dealt.
List<int> dealtPairs(Iterable<int> ids) => [
  for (final id in ids)
    if (pairTile('left', id).evaluate().isNotEmpty) id,
];

/// Matches every pair the round on screen dealt from [ids].
Future<void> clearRound(WidgetTester tester, Iterable<int> ids) async {
  for (final id in dealtPairs(ids)) {
    await playPair(tester, id, id);
  }
}

/// How many tiles the Sentences puzzle on screen has.
int bankTileCount() => find
    .byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('bank-'),
    )
    .evaluate()
    .length;

/// Places the Sentences tiles in [order] (indices into the sentence's
/// tiles).
Future<void> placeTiles(WidgetTester tester, Iterable<int> order) async {
  for (final i in order) {
    await tester.tap(find.byKey(ValueKey('bank-$i')));
    await tester.pump();
  }
}
