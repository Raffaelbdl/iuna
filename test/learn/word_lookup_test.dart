import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/learn/widgets/tutor_markdown.dart';
import 'package:iuna/learn/widgets/word_sheet.dart';
import 'package:iuna/learn/words/tutor_words.dart';

import 'fake_words.dart';

void main() {
  tearDown(() => TutorWords.instance = TutorWords());

  Future<void> pumpMarkdown(
    WidgetTester tester,
    String text, {
    bool selectable = true,
    bool lookUp = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TutorMarkdown(text, selectable: selectable, lookUp: lookUp),
        ),
      ),
    );
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
}
