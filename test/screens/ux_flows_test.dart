import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/screens/add_card_screen.dart';
import 'package:iuna/screens/card_detail_screen.dart';
import 'package:iuna/screens/home_screen.dart';
import 'package:iuna/screens/booster_reveal_screen.dart';
import 'package:iuna/screens/collection_screen.dart';
import 'package:iuna/screens/pack_intro_screen.dart';
import 'package:iuna/screens/review_done_screen.dart';
import 'package:iuna/screens/review_screen.dart';
import 'package:iuna/screens/today_flow.dart';
import 'package:iuna/screens/stats_screen.dart';
import 'package:iuna/theme/iuna_theme.dart';
import 'package:iuna/widgets/iuna_bottom_nav.dart';

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

/// Midday, far from the 4am rollover, so a missed card's short gap
/// still lands today.
final _now = DateTime(2026, 6, 10, 12);

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

    await tester.tap(find.text('Not for me'));
    await _frames(tester);
    expect(
      find.text(
        'Swapped. The old card is set aside in Collection › Suspended.',
      ),
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

  testWidgets('system Back in the reveal goes home; the cards stay '
      'collected', (tester) async {
    await _seedCards(db, 12);
    final popped = await _openReveal(tester, db);

    await tester.binding.handlePopRoute();
    await _frames(tester);
    expect(popped, hasLength(1));
    expect(popped.single, isNull, reason: 'no review follows');
    expect(await db.select(db.userCards).get(), isNotEmpty);
  });

  testWidgets('the reveal can be left for later from its close button', (
    tester,
  ) async {
    await _seedCards(db, 12);
    final popped = await _openReveal(tester, db);

    await tester.tap(find.byTooltip('Review later'));
    await _frames(tester);
    expect(popped, hasLength(1));
    expect(popped.single, isNull, reason: 'home, not the review');
    expect(await db.select(db.userCards).get(), isNotEmpty);
  });

  testWidgets('Skip to review leaves the reveal for the review', (
    tester,
  ) async {
    await _seedCards(db, 12);
    final popped = await _openReveal(tester, db);

    await tester.tap(find.text('Skip to review'));
    await _frames(tester);
    expect(popped, hasLength(1));
    expect(popped.single, isNotEmpty);
  });

  testWidgets("the pack intro doesn't call the pack opened before it "
      'has counted', (tester) async {
    await _seedCards(db, 12);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: PackIntroScreen(db: db, kumaSeed: 0),
      ),
    );
    expect(find.text('Pack already opened'), findsNothing);
    await _frames(tester);
    expect(find.text('10 new cards await'), findsOneWidget);
  });

  testWidgets('a screen whose data fails to load offers Retry', (
    tester,
  ) async {
    await db.customStatement('DROP TABLE user_cards');
    await tester.pumpWidget(
      MaterialApp(theme: buildIunaTheme(), home: CollectionScreen(db: db)),
    );
    await _frames(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text("Couldn't load this screen."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  Future<void> openCollection(
    WidgetTester tester, {
    bool wished = false,
  }) async {
    tester.view.physicalSize = const Size(360 * 2, 780 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: CollectionScreen(db: db, initialWishedOnly: wished),
      ),
    );
    await _frames(tester);
  }

  Future<void> ownAll(List<int> ids, {DateTime? due}) async {
    for (final id in ids) {
      await db
          .into(db.userCards)
          .insert(
            UserCardsCompanion.insert(
              cardId: Value(id),
              nextDue: due ?? DateTime(2026),
              obtainedAt: DateTime(2026),
              isNew: const Value(false),
            ),
          );
    }
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

  testWidgets('Collection keeps the tier counts one tap away', (
    tester,
  ) async {
    await ownAll(await _seedCards(db, 3));
    await openCollection(tester);
    expect(find.text('3 / 3 collected'), findsNothing);
    expect(find.textContaining('collected'), findsOneWidget);
    expect(find.text('Common'), findsNothing);

    await tester.tap(find.textContaining('collected'));
    await _frames(tester, 300);
    expect(find.text('Common'), findsOneWidget);
  });

  testWidgets('a word not yet collected is wished for from its card, and '
      'an owned one is not', (tester) async {
    final ids = await _seedCards(db, 2);
    await ownAll([ids.first]);
    Future<void> open(int id) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildIunaTheme(),
          home: CardDetailScreen(
            key: ValueKey(id),
            db: db,
            cardId: id,
            now: _now,
          ),
        ),
      );
      await _frames(tester);
    }

    await open(ids.last);
    expect(find.text('Not in your collection yet'), findsOneWidget);
    await tester.tap(find.text('Add to wishlist'));
    await _frames(tester);
    expect(find.text('On your wishlist'), findsOneWidget);
    expect(find.text('Add to wishlist'), findsNothing);
    expect(find.byTooltip('Remove from wishlist'), findsOneWidget);

    await open(ids.first);
    expect(find.text('Add to wishlist'), findsNothing);
    expect(find.byTooltip('Add to wishlist'), findsNothing);
    expect(find.byTooltip('Remove from wishlist'), findsNothing);
  });

  testWidgets('Add card says the dictionary reads Japanese', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: AddCardScreen(db: db, initialQuery: 'dog'),
      ),
    );
    await _frames(tester);
    expect(find.textContaining('Type the word in kanji or kana'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('out of cards under a draw filter, Home names it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await IunaRepository(db).setJlptOnly(true);
    await _seedCards(db, 2); // none tagged with a JLPT level
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: HomeScreen(db: db, kumaSeed: 0),
      ),
    );
    await _frames(tester);
    expect(find.text('No new cards left'), findsOneWidget);
    expect(find.textContaining('Every JLPT card is collected'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  });

  testWidgets('Today from a card opened on the recap goes back to that '
      'recap', (tester) async {
    tester.view.physicalSize = const Size(360 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await ownAll(await _seedCards(db, 1), due: DateTime(2020));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => openTodayFlow(context, db),
            child: const Text('today'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('today'));
    await _frames(tester, 1500);
    await tester.tap(find.text('k0'));
    await _frames(tester, 400);
    await tester.tap(find.text('Got it'));
    await _frames(tester, 1200);
    expect(find.byType(ReviewDoneScreen), findsOneWidget);

    await tester.tap(find.text('k0'));
    await _frames(tester, 1200);
    expect(find.byType(CardDetailScreen), findsOneWidget);
    await tester.tap(find.text('Today').last);
    await _frames(tester, 1200);
    expect(find.byType(CardDetailScreen), findsNothing);
    expect(find.byType(ReviewDoneScreen), findsOneWidget);
    expect(find.text('k0'), findsOneWidget,
        reason: "the session's recap, not a fresh one on top");
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
    expect(find.text('Tricky cards'), findsOneWidget);
    expect(find.text('How long you remember'), findsNothing);

    await tester.tap(find.text('More stats'));
    await _frames(tester, 300);
    expect(find.text('How long you remember'), findsOneWidget);
  });

  testWidgets('Collection: a search with no match can be cleared', (
    tester,
  ) async {
    await ownAll(await _seedCards(db, 3));
    await openCollection(tester);
    expect(find.text('k0'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nothing like this');
    await _frames(tester, 400);
    expect(find.text('None in your collection.'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear search'));
    await _frames(tester, 300);
    await tester.tap(find.text('Clear search'));
    await _frames(tester, 400);
    expect(find.text('None in your collection.'), findsNothing);
    expect(find.text('k0'), findsOneWidget);
    expect(find.text('nothing like this'), findsNothing);
  });

  testWidgets('Collection: a word not collected yet is one tap from the '
      'missing cards', (tester) async {
    final ids = await _seedCards(db, 3);
    await ownAll(ids.take(2).toList());
    await openCollection(tester);

    await tester.enterText(find.byType(TextField), 'k2');
    await _frames(tester, 400);
    expect(find.text('None in your collection.'), findsOneWidget);
    expect(
      find.text('Search the dictionary'),
      findsNothing,
      reason: 'no dictionary downloaded',
    );

    await tester.ensureVisible(find.text('Show missing').last);
    await _frames(tester, 300);
    await tester.tap(find.text('Show missing').last);
    await _frames(tester, 400);
    expect(find.text('None in your collection.'), findsNothing);
    expect(find.text('k2'), findsNWidgets(2), reason: 'the query and its card');
  });

  testWidgets('Collection: a rarity filter with no match offers Clear '
      'filters', (tester) async {
    await ownAll(await _seedCards(db, 3));
    await openCollection(tester);

    await tester.tap(find.text('UR').first);
    await _frames(tester, 400);
    expect(find.text('No matching cards.'), findsOneWidget);
    await tester.tap(find.text('Clear filters'));
    await _frames(tester, 400);
    expect(find.text('k0'), findsOneWidget);
  });

  testWidgets('Collection: + offers the dictionary until it is downloaded', (
    tester,
  ) async {
    await openCollection(tester);
    await tester.tap(find.byTooltip('Add to wishlist'));
    await _frames(tester, 400);
    expect(find.text('Add any word to your wishlist'), findsOneWidget);
    expect(find.text('Download dictionary'), findsOneWidget);
  });

  testWidgets('Collection: shuffle is a toggle', (tester) async {
    await ownAll(await _seedCards(db, 3));
    await openCollection(tester);
    final handle = tester.ensureSemantics();
    final shuffle = find.bySemanticsLabel('Shuffle');
    expect(tester.getSemantics(shuffle), isSemantics(isSelected: false));

    await tester.tap(shuffle);
    await _frames(tester, 300);
    expect(tester.getSemantics(shuffle), isSemantics(isSelected: true));
    expect(find.byIcon(Icons.shuffle_on_rounded), findsOneWidget);

    await tester.tap(shuffle);
    await _frames(tester, 300);
    expect(tester.getSemantics(shuffle), isSemantics(isSelected: false));
    handle.dispose();
  });

  testWidgets("Collection: a missing card doesn't read out its word", (
    tester,
  ) async {
    await _seedCards(db, 1);
    await openCollection(tester);
    final handle = tester.ensureSemantics();
    await tester.tap(find.text('Show missing'));
    await _frames(tester, 300);
    expect(find.bySemanticsLabel('Missing Common card'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('k0')), findsNothing);
    handle.dispose();
  });

  testWidgets('Review: the last card can be taken back from the recap', (
    tester,
  ) async {
    final ids = await _seedCards(db, 1);
    await ownAll(ids, due: _now.subtract(const Duration(hours: 1)));
    final before = (await db.select(db.userCards).getSingle());

    await tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: ReviewScreen(db: db, now: _now),
      ),
    );
    await _frames(tester);
    await tester.tap(find.text('k0'));
    await _frames(tester, 400);
    await tester.tap(find.text('Got it'));
    await _frames(tester, 1200);
    expect(find.byType(ReviewDoneScreen), findsOneWidget);
    expect(await db.select(db.reviewLog).get(), hasLength(1));

    await tester.tap(find.byTooltip('Undo last card'));
    await _frames(tester, 1200);
    expect(find.byType(ReviewDoneScreen), findsNothing);
    expect(find.text('Got it'), findsOneWidget, reason: 'back on the card, flipped');
    expect(await db.select(db.reviewLog).get(), isEmpty);
    final after = await db.select(db.userCards).getSingle();
    expect(after.nextDue, before.nextDue);
    expect(after.level, before.level);
  });

  testWidgets('Review: a missed card can be reviewed again from the recap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await ownAll(
      await _seedCards(db, 1),
      due: _now.subtract(const Duration(hours: 1)),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: ReviewScreen(db: db, now: _now),
      ),
    );
    await _frames(tester);
    await tester.tap(find.text('k0'));
    await _frames(tester, 400);
    await tester.tap(find.text('Forgot'));
    await _frames(tester, 1200);
    expect(find.byType(ReviewDoneScreen), findsOneWidget);
    expect(find.textContaining("they'll come back tomorrow"), findsNothing);

    await tester.tap(find.text('Review again · 1 card'));
    await _frames(tester, 1200);
    expect(find.byType(ReviewDoneScreen), findsNothing);
    expect(find.text('k0'), findsOneWidget, reason: 'the missed card again');
  });

  testWidgets('the Today tab counts what waits behind it', (tester) async {
    final handle = tester.ensureSemantics();
    Future<void> nav(int count) => tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: Scaffold(
          body: IunaBottomNav(
            active: IunaNavTab.home,
            todayCount: count,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await nav(12);
    expect(find.text('12'), findsOneWidget);
    expect(find.bySemanticsLabel('Today, 12 waiting'), findsOneWidget);

    await nav(0);
    expect(find.text('0'), findsNothing, reason: 'no badge with nothing to do');
    expect(find.bySemanticsLabel('Today'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('Today with nothing to do shows when the next pack comes', (
    tester,
  ) async {
    await ownAll(await _seedCards(db, 1), due: DateTime(2099));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildIunaTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => openTodayFlow(context, db),
            child: const Text('today'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('today'));
    await _frames(tester, 1500);
    expect(find.text('Nothing to review yet.'), findsOneWidget);
    expect(find.text('Next pack'), findsOneWidget);
    expect(find.text('Next review'), findsOneWidget);
  });
}
