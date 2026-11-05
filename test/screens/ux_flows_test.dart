import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/screens/booster_reveal_screen.dart';
import 'package:iuna/screens/collection_screen.dart';
import 'package:iuna/screens/stats_screen.dart';
import 'package:iuna/theme/iuna_theme.dart';

import '../helpers/fake_path_provider.dart';

/// The hex background never settles, so frames are pumped by hand.
Future<void> _frames(WidgetTester tester, [int ms = 800]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<List<int>> _seedCards(AppDatabase db, int n) async => [
  for (var i = 0; i < n; i++)
    await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(kanji: 'k$i', kana: 'kana$i', meaning: 'w$i'),
        ),
];

/// Pushes the reveal from a host page and hands back what it popped.
Future<List<List<int>?>> _openReveal(
  WidgetTester tester,
  AppDatabase db,
) async {
  final popped = <List<int>?>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildIunaTheme(),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => popped.add(
            await Navigator.of(context).push<List<int>>(
              MaterialPageRoute(builder: (_) => BoosterRevealScreen(db: db)),
            ),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await _frames(tester);
  return popped;
}

String _shownKanji(WidgetTester tester) {
  for (var i = 0; i < 20; i++) {
    if (find.text('k$i').evaluate().isNotEmpty) return 'k$i';
  }
  throw StateError('no card shown');
}

void main() {
  late AppDatabase db;

  setUp(() {
    useTempDocumentsDir('iuna_ux_');
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  testWidgets('suspending in the reveal says where the card went, and Undo '
      'brings it back', (tester) async {
    await _seedCards(db, 12);
    await _openReveal(tester, db);
    final first = _shownKanji(tester);
    final ownedBefore = (await db.select(db.userCards).get()).length;

    await tester.tap(find.text('Suspend'));
    await _frames(tester);
    expect(
      find.text('Suspended — find it in Collection › Suspended.'),
      findsOneWidget,
    );
    expect(find.text(first), findsNothing, reason: 'swapped out');

    await tester.tap(find.text('Undo'));
    await _frames(tester);
    expect(find.text(first), findsOneWidget);
    final rows = await db.select(db.userCards).get();
    expect(rows.length, ownedBefore, reason: 'the replacement left again');
    expect(rows.where((r) => r.suspended), isEmpty);
  });

  testWidgets('system Back in the reveal goes on like Skip', (tester) async {
    await _seedCards(db, 12);
    final popped = await _openReveal(tester, db);

    await tester.binding.handlePopRoute();
    await _frames(tester);
    expect(popped, hasLength(1));
    expect(popped.single, isNotEmpty, reason: 'finalised, not dropped');
  });

  Future<void> openCollection(
    WidgetTester tester, {
    bool wished = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: CollectionScreen(db: db, initialWishedOnly: wished),
      ),
    );
    await _frames(tester);
  }

  testWidgets('Collection says when nothing is suspended', (tester) async {
    final ids = await _seedCards(db, 2);
    await db
        .into(db.userCards)
        .insert(
          UserCardsCompanion.insert(
            cardId: Value(ids.first),
            nextDue: DateTime(2026),
            obtainedAt: DateTime(2026),
          ),
        );
    await openCollection(tester);
    expect(find.byTooltip('Back'), findsNothing, reason: 'a tab root');

    await tester.tap(find.text('Suspended'));
    await _frames(tester);
    expect(find.text('No suspended cards.'), findsOneWidget);
  });

  testWidgets('Collection can open on the wishlist', (tester) async {
    await _seedCards(db, 2);
    await openCollection(tester, wished: true);
    expect(find.textContaining('Your wishlist is empty'), findsOneWidget);
  });

  testWidgets('Stats folds the detailed charts under More stats', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 2, 4000 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: StatsScreen(db: db, now: DateTime(2026, 4, 26, 12)),
      ),
    );
    await _frames(tester);
    expect(find.text('Leeches'), findsOneWidget);
    expect(find.text('Retention curve'), findsNothing);

    await tester.tap(find.text('More stats'));
    await _frames(tester, 300);
    expect(find.text('Retention curve'), findsOneWidget);
  });
}
