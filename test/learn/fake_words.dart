import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/core/deck_rules.dart';
import 'package:iuna/db/jmdict_lookup.dart';
import 'package:iuna/learn/widgets/tutor_markdown.dart';
import 'package:iuna/learn/words/segmenter.dart';
import 'package:iuna/learn/words/tutor_words.dart';

JmdictHit word(
  String kanji,
  String kana,
  String gloss, {
  String pos = 'n',
  String def = '',
  Rarity rarity = Rarity.common,
  int? jlpt,
}) => JmdictHit(
  kanji: kanji,
  kana: kana,
  senses: [JmdictSense(pos: pos, gloss: gloss, def: def)],
  rarity: rarity,
  jlptLevel: jlpt,
);

/// A dictionary of a few dozen headwords, enough for the sentences the
/// tests and goldens use.
final kTestWords = [
  word('今日', 'きょう', 'today, this day', pos: 'n,adv', jlpt: 5),
  word('今日', 'こんにち', 'these days, nowadays', pos: 'n,adv', rarity: Rarity.rare),
  word('今日は', 'こんにちは', 'hello, good day', pos: 'int', def: 'usually written in kana'),
  word('は', 'は', 'indicates sentence topic', pos: 'prt', rarity: Rarity.superRare),
  word('が', 'が', 'indicates the subject of a sentence', pos: 'prt', rarity: Rarity.superRare),
  word('を', 'を', 'indicates direct object of action', pos: 'prt', rarity: Rarity.superRare),
  word('に', 'に', 'at (place, time), in, on', pos: 'prt', rarity: Rarity.superRare),
  word('ね', 'ね', "right?, isn't it?", pos: 'prt', rarity: Rarity.superRare),
  word('です', 'です', 'be, is', pos: 'cop,aux-v', def: 'polite', rarity: Rarity.superRare),
  word('会議', 'かいぎ', 'meeting, conference', pos: 'n,vs', jlpt: 3),
  word(
    '有る',
    'ある',
    'to be, to exist (of inanimate objects)',
    pos: 'v5r-i',
    def: 'usually written in kana',
  ),
  word('食べる', 'たべる', 'to eat', pos: 'v1,vt', jlpt: 5),
  word('行く', 'いく', 'to go, to move', pos: 'v5k-s,vi', jlpt: 5),
  word('読む', 'よむ', 'to read', pos: 'v5m,vt', jlpt: 5),
  word('為る', 'する', 'to do, to carry out', pos: 'vs-i', def: 'usually written in kana'),
  word('勉強', 'べんきょう', 'study', pos: 'n,vs', jlpt: 5),
  word('来る', 'くる', 'to come', pos: 'vk,vi', jlpt: 5),
  word('面白い', 'おもしろい', 'interesting, amusing', pos: 'adj-i', jlpt: 5),
  word('これ', 'これ', 'this, this one', pos: 'pn'),
  word('いい', 'いい', 'good, excellent, fine', pos: 'adj-ix'),
  word('はい', 'はい', 'yes, that is correct', pos: 'int', rarity: Rarity.superRare),
  word('いで', 'いで', 'oh no, well', pos: 'int', def: 'archaic', rarity: Rarity.ur),
  word('脛', 'すね', 'shin, lower leg', def: 'usually written in kana'),
  word('廃位', 'はいい', 'dethronement', rarity: Rarity.ur),
  word('私', 'わたし', 'I, me', pos: 'pn', jlpt: 5),
  word('学生', 'がくせい', 'student', jlpt: 5),
  word(
    '御座います',
    'ございます',
    'to be, to exist',
    pos: 'exp',
    def: 'polite · usually written in kana',
    rarity: Rarity.superRare,
  ),
  word('茣蓙', 'ござ', 'rush mat', def: 'usually written in kana'),
  word(
    '居る',
    'いる',
    'to be (of animate objects), to exist',
    pos: 'v1,vi',
    def: 'usually written in kana',
  ),
  word('有難う', 'ありがとう', 'thank you', pos: 'int', def: 'usually written in kana'),
];

/// What the sidecar's `byForms` would return over [kTestWords].
WordLexicon fakeLexicon() =>
    (forms) => [
      for (final w in kTestWords)
        if (forms.contains(w.kanji) || forms.contains(w.kana)) w,
    ];

TutorWords fakeTutorWords() => TutorWords(lexicon: () async => fakeLexicon());

/// The middle of the first [word] on screen, in plain or selectable
/// text.
Offset wordCenter(WidgetTester tester, String word) {
  for (final r in tester.allRenderObjects) {
    final (String? text, boxes) = switch (r) {
      RenderParagraph() => (r.text.toPlainText(), r.getBoxesForSelection),
      RenderEditable() => (r.plainText, r.getBoxesForSelection),
      _ => (null, null),
    };
    final start = text?.indexOf(word) ?? -1;
    if (boxes == null || start < 0) continue;
    final box = boxes(TextSelection(baseOffset: start, extentOffset: start + word.length));
    return (r as RenderBox).localToGlobal(box.first.toRect().center);
  }
  throw StateError('$word is not on screen');
}

/// Taps the middle of the first [word] in plain or selectable text.
Future<void> tapWord(WidgetTester tester, String word) => tester.tapAt(wordCenter(tester, word));

/// Where the pressed word is marked, in global coordinates.
List<Rect> litRects(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter is WordHighlight),
  );
  final host = tester.renderObject<RenderBox>(find.byWidget(paint));
  return [
    for (final r in (paint.foregroundPainter! as WordHighlight).lit.value)
      r.shift(host.localToGlobal(Offset.zero)),
  ];
}

/// Whether [word] is the one marked as pressed.
bool isLit(WidgetTester tester, String word) {
  final center = wordCenter(tester, word);
  return litRects(tester).any((r) => r.contains(center));
}
