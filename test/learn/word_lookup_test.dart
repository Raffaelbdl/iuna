import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/jmdict_lookup.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/learn/deck.dart';
import 'package:iuna/learn/widgets/tutor_markdown.dart';
import 'package:iuna/learn/widgets/word_sheet.dart';
import 'package:iuna/learn/words/tutor_words.dart';

import 'fake_words.dart';

/// A deck that knows a few words' standing and records wishlisting.
class _FakeDeck implements WordBookmarks {
  _FakeDeck(this.statuses);

  final Map<String, CardLookupStatus> statuses;
  final wished = <String>[];

  @override
  Future<CardLookupStatus> status(String word, String reading) async =>
      statuses[word] ?? CardLookupStatus.notFound;

  @override
  Future<CardLookupStatus> wishlist(JmdictHit entry) async {
    wished.add('${entry.kanji}/${entry.kana}');
    return statuses[entry.kanji] = CardLookupStatus.wishlisted;
  }

  @override
  Future<BookmarkOutcome> bookmark(String word, String reading) => throw UnimplementedError();
}

void main() {
  tearDown(() => TutorWords.instance = TutorWords());

  Future<void> pumpMarkdown(
    WidgetTester tester,
    String text, {
    bool selectable = true,
    bool lookUp = true,
    Widget Function(Widget markdown)? around,
    WordBookmarks? bookmarks,
  }) async {
    final markdown = TutorMarkdown(
      text,
      selectable: selectable,
      lookUp: lookUp,
      bookmarks: bookmarks,
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: around?.call(markdown) ?? markdown)));
    // Reads go one per frame: a frame to wait on, then one to show it.
    await tester.pump();
    await tester.pump();
  }

  for (final selectable in [true, false]) {
    testWidgets('tapping a word shows its reading and meaning (selectable: $selectable)', (
      tester,
    ) async {
      TutorWords.instance = fakeTutorWords();
      await pumpMarkdown(tester, '今日は**会議**があります。', selectable: selectable);

      await tapWord(tester, '会議');
      await tester.pumpAndSettle();
      expect(find.byType(WordSheet), findsOneWidget);
      expect(find.text('かいぎ'), findsOneWidget);
      expect(find.text('meeting, conference'), findsOneWidget);
      expect(find.text('JLPT N3'), findsOneWidget);
    });
  }

  testWidgets('an inflected word names its dictionary form and offers other readings', (
    tester,
  ) async {
    TutorWords.instance = fakeTutorWords();
    await pumpMarkdown(tester, '今日、食べました。');

    await tapWord(tester, '食べました');
    await tester.pumpAndSettle();
    expect(find.text('食べる'), findsOneWidget);
    expect(find.text('食べました · polite · past'), findsOneWidget);
    Navigator.of(tester.element(find.byType(WordSheet))).pop();
    await tester.pumpAndSettle();

    await tapWord(tester, '今日');
    await tester.pumpAndSettle();
    expect(find.text('きょう'), findsOneWidget);
    expect(find.text('Could also be'), findsOneWidget);
    await tester.tap(find.textContaining('こんにち', findRichText: true));
    await tester.pumpAndSettle();
    expect(find.text('these days, nowadays'), findsOneWidget);
  });

  testWidgets('words stay plain where lookups are off or there is no dictionary', (tester) async {
    TutorWords.instance = fakeTutorWords();
    await pumpMarkdown(tester, '会議', lookUp: false);
    await tapWord(tester, '会議');
    await tester.pumpAndSettle();
    expect(find.byType(WordSheet), findsNothing);

    TutorWords.instance = TutorWords(lexicon: () async => null);
    await pumpMarkdown(tester, '会議です');
    await tapWord(tester, '会議');
    await tester.pumpAndSettle();
    expect(find.byType(WordSheet), findsNothing);
    expect(await TutorWords.instance.available(), isFalse);
  });

  testWidgets('a dictionary that fails to open leaves the text readable', (tester) async {
    TutorWords.instance = TutorWords(lexicon: () async => throw StateError('corrupt sidecar'));
    await pumpMarkdown(tester, '会議です');
    expect(find.textContaining('会議です', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pressed word lights up like a link until its sheet closes', (tester) async {
    TutorWords.instance = fakeTutorWords();
    await pumpMarkdown(tester, '今日は会議があります。');
    expect(litRects(tester), isEmpty);

    final press = await tester.startGesture(wordCenter(tester, '会議'));
    // A press lights up once it outlasts a tap's grace period, so a
    // scroll starting on a word doesn't flash it.
    await tester.pump(kPressTimeout);
    expect(isLit(tester, '会議'), isTrue, reason: 'feedback while the finger is down');
    expect(isLit(tester, '今日'), isFalse, reason: 'only that word');

    await press.up();
    await tester.pumpAndSettle();
    expect(find.byType(WordSheet), findsOneWidget);
    expect(isLit(tester, '会議'), isTrue, reason: 'marks what opened');

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(WordSheet), findsNothing);
    expect(litRects(tester), isEmpty);
  });

  testWidgets('a word that repeats lights only where it was pressed', (tester) async {
    TutorWords.instance = fakeTutorWords();
    await pumpMarkdown(tester, '会議\n\n会議');
    final second = tester.getCenter(find.byType(TutorMarkdown)).dy + 1;
    final press = await tester.startGesture(Offset(wordCenter(tester, '会議').dx, second + 10));
    await tester.pump(kPressTimeout);
    final lit = litRects(tester);
    expect(lit, hasLength(1));
    expect(lit.single.top, greaterThan(second - 20), reason: 'the second paragraph, not the first');
    await press.cancel();
  });

  testWidgets('a press that turns into a scroll leaves the word unlit', (tester) async {
    TutorWords.instance = fakeTutorWords();
    await pumpMarkdown(tester, '今日は会議があります。', around: (markdown) => ListView(children: [markdown]));
    final press = await tester.startGesture(wordCenter(tester, '会議'));
    await tester.pump(kPressTimeout);
    await press.moveBy(const Offset(0, 80));
    await press.up();
    await tester.pumpAndSettle();
    expect(find.byType(WordSheet), findsNothing);
    expect(litRects(tester), isEmpty);
  });

  testWidgets('holding a word selects it instead of opening it', (tester) async {
    TutorWords.instance = fakeTutorWords();
    await pumpMarkdown(tester, '今日は会議があります。');
    final press = await tester.startGesture(wordCenter(tester, '会議'));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await press.up();
    await tester.pumpAndSettle();
    expect(find.byType(WordSheet), findsNothing);
    expect(litRects(tester), isEmpty);
    final editable = tester.allRenderObjects.whereType<RenderEditable>().single;
    expect(editable.selection?.isCollapsed, isFalse, reason: 'the long press still selects');
  });

  testWidgets('closing the sheet leaves the message box closed', (tester) async {
    TutorWords.instance = fakeTutorWords();
    await pumpMarkdown(
      tester,
      '今日は会議があります。',
      around: (markdown) => Column(
        children: [
          markdown,
          const TextField(key: Key('composer')),
        ],
      ),
    );
    // Focused, as after typing and hiding the keyboard with Back.
    await tester.tap(find.byKey(const Key('composer')));
    await tester.pump();

    await tapWord(tester, '会議');
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    final composer = tester.widget<EditableText>(find.byType(EditableText).last);
    expect(composer.focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });

  group('bookmarking from the sheet', () {
    Future<void> open(WidgetTester tester, _FakeDeck? deck, String word) async {
      TutorWords.instance = fakeTutorWords();
      await pumpMarkdown(tester, '今日は会議があります。', bookmarks: deck);
      await tapWord(tester, word);
      await tester.pumpAndSettle();
    }

    testWidgets('a word not yet collected can be bookmarked', (tester) async {
      final deck = _FakeDeck({});
      await open(tester, deck, '会議');
      await tester.tap(find.text('Add to wishlist'));
      await tester.pumpAndSettle();
      expect(deck.wished, ['会議/かいぎ']);
      expect(find.text('Add to wishlist'), findsNothing);
      expect(find.text('On your wishlist'), findsOneWidget);
    });

    testWidgets('an owned or bookmarked word offers no button', (tester) async {
      await open(tester, _FakeDeck({'会議': CardLookupStatus.owned}), '会議');
      expect(find.text('In your collection'), findsOneWidget);
      expect(find.text('Add to wishlist'), findsNothing);
      Navigator.of(tester.element(find.byType(WordSheet))).pop();
      await tester.pumpAndSettle();

      await tapWord(tester, '今日');
      await tester.pumpAndSettle();
      expect(find.text('Add to wishlist'), findsOneWidget, reason: 'each headword has its own standing');
    });

    testWidgets('without a deck the sheet only reads the word', (tester) async {
      await open(tester, null, '会議');
      expect(find.byType(WordSheet), findsOneWidget);
      expect(find.text('Add to wishlist'), findsNothing);
      expect(find.text('In your collection'), findsNothing);
    });
  });
}
