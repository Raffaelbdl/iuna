import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/learn/agent/example_writer.dart';
import 'package:iuna/learn/deck.dart';

void main() {
  test('the brief shows the word, its level and senses; kana words once', () {
    expect(
      exampleBrief(const FocusCard(
        kanji: '行く',
        kana: 'いく',
        senses: ['(v5k-s) to go', '(aux-v) to keep -ing'],
        jlptLevel: 5,
      )),
      'Word: 行く（いく）\nJLPT: N5\nSenses:\n1. (v5k-s) to go\n2. (aux-v) to keep -ing',
    );
    expect(
      exampleBrief(const FocusCard(kanji: 'ここ', kana: 'ここ', senses: [])),
      'Word: ここ\nJLPT: unlisted',
    );
  });

  test('a reply parses through a fence or chatter, skipping broken items', () {
    final examples = parseWrittenExamples(
      'Here you go!\n```json\n[{"ja": " 駅に行く。 ", "en": "I go to the station."},'
      ' {"en": "no Japanese"}, "nonsense", {"ja": "行こう。"}]\n```',
    );
    expect(examples, [
      (sentence: '駅に行く。', translation: 'I go to the station.'),
      (sentence: '行こう。', translation: ''),
    ]);
  });

  test('the translate brief lists the sentences under the card', () {
    expect(
      translateBrief(const FocusCard(kanji: 'おごる', kana: 'おごる', senses: ['to treat']), ['一杯おごる。', 'OKだ。']),
      'Word: おごる\nJLPT: unlisted\nSenses:\n1. to treat\n\nSentences:\n1. 一杯おごる。\n2. OKだ。',
    );
  });

  test('at most five examples are kept', () {
    final reply = '[${List.filled(8, '{"ja": "行く。", "en": "Go."}').join(',')}]';
    expect(parseWrittenExamples(reply), hasLength(kMaxWrittenExamples));
  });

  test('translations come back by sentence number; strays are dropped', () {
    expect(
      parseNumberedEnglish(
        '```json\n[{"n": 2, "en": " Second. "}, {"n": 1, "en": "First."}, {"n": 3, "en": "Not asked."},'
        ' {"n": 1}, {"en": "No number."}]\n```',
        2,
      ),
      {1: 'Second.', 0: 'First.'},
    );
    expect(() => parseNumberedEnglish('[{"n": 4, "en": "Out of range."}]', 2),
        throwsA(isA<ExampleWriterError>()));
  });

  test('a reply without usable examples is an error', () {
    for (final reply in ['Sorry, I cannot.', '[]', '[{"en": "only English"}]', '[{"ja": ']) {
      expect(() => parseWrittenExamples(reply), throwsA(isA<ExampleWriterError>()), reason: reply);
    }
  });
}
