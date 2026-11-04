import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/learn/words/deinflect.dart';
import 'package:iuna/learn/words/segmenter.dart';

import 'fake_words.dart';

/// The run split into `surface=headword` pairs, the best reading of each.
List<String> split(String run) {
  final words = readText(run, fakeLexicon())[run] ?? const [];
  return [
    for (final w in words) '${run.substring(w.start, w.end)}=${w.readings.first.entry.kanji}',
  ];
}

void main() {
  group('deinflect', () {
    Map<String, List<String>> forms(String surface) => {
      for (final d in deinflect(surface)) d.form: d.reasons,
    };

    test('undoes verb chains, innermost inflection first', () {
      expect(forms('食べていました')['食べる'], ['ongoing', 'polite', 'past']);
      expect(forms('食べたくなかった')['食べる'], ['want to', 'negative', 'past']);
      expect(forms('読まれたくない')['読む'], ['passive', 'want to', 'negative']);
      expect(forms('読んで')['読む'], ['te-form']);
      expect(forms('行った')['行く'], ['past'], reason: '行く breaks its row');
      expect(forms('来なかった')['来る'], ['negative', 'past']);
      expect(forms('しています')['する'], ['ongoing', 'polite']);
      expect(forms('面白かった')['面白い'], ['past']);
      expect(forms('ございます')['ござる'], ['polite'], reason: 'the -aru honorifics');
    });

    test('the surface comes first and matches any headword; rules say what they make', () {
      final all = deinflect('食べませんでした');
      expect(all.first.form, '食べませんでした');
      expect(all.first.type, isNull);
      final polite = all.firstWhere((d) => d.form == '食べます');
      expect(polite.type, WordType.polite, reason: 'no headword is a bare ます form');
      final base = all.firstWhere((d) => d.form == '食べる');
      expect(base.type, WordType.v1);
      expect(base.reasons, ['polite', 'negative past']);
    });

    test('maps JMdict parts of speech to what they conjugate as', () {
      expect(wordTypesOf('v5k-s,vi'), {WordType.v5});
      expect(wordTypesOf('v1,vt'), {WordType.v1});
      expect(wordTypesOf('adj-ix'), {WordType.adjI});
      expect(wordTypesOf('n,vs'), isEmpty, reason: 'the noun of a suru-verb does not inflect');
    });
  });

  group('segmenting', () {
    test('splits a sentence into its words, conjugations whole', () {
      expect(split('今日は会議があります'), ['今日=今日', 'は=は', '会議=会議', 'が=が', 'あります=有る']);
      expect(split('私は勉強しています'), ['私=私', 'は=は', '勉強=勉強', 'しています=為る']);
    });

    test('a set phrase loses to the word before its particle', () {
      expect(split('今日は'), ['今日=今日', 'は=は'], reason: 'not こんにちは');
      expect(split('こんにちは'), ['こんにちは=今日は'], reason: 'in kana it is the greeting');
    });

    test('short common words beat a longer, rarer reading', () {
      expect(split('これはいいですね'), ['これ=これ', 'は=は', 'いい=いい', 'です=です', 'ね=ね']);
      expect(split('ありがとうございます'), ['ありがとう=有難う', 'ございます=御座います']);
    });

    test('kana matches a kanji headword only when common or usually kana', () {
      expect(split('がくせい'), ['がくせい=学生']);
      final rare = readText('はいい', fakeLexicon())['はいい']!;
      expect(rare.map((w) => w.readings.first.entry.kanji), isNot(contains('廃位')));
    });

    test('readings come best first, and what the text inflects is kept', () {
      final words = readText('今日、食べました', fakeLexicon());
      expect(words.keys, ['今日', '食べました'], reason: 'punctuation ends a run');
      expect([for (final r in words['今日']!.single.readings) r.entry.kana], ['きょう', 'こんにち']);
      final ate = words['食べました']!.single.readings.single;
      expect(ate.entry.kanji, '食べる');
      expect(ate.inflections, ['polite', 'past']);
    });

    test('text the dictionary lacks is skipped, not mangled', () {
      final words = readText('会議ぽぽ会議', fakeLexicon())['会議ぽぽ会議']!;
      expect([for (final w in words) (w.start, w.end)], [(0, 2), (4, 6)]);
      expect(readText('no Japanese here', fakeLexicon()), isEmpty);
    });
  });
}
