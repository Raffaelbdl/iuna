import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/games/sentence_tiles.dart';

import 'sentence_words.dart';

SentenceTiles? tile(String s) => tileSentence(s, sentenceLexicon());

void main() {
  test('glues particles on and keeps the final mark off', () {
    final t = tile('猫は魚を食べた。')!;
    expect(t.tiles, ['猫は', '魚を', '食べた']);
    expect(t.end, '。');
    expect(t.text, '猫は魚を食べた。');
    expect(t.words.map((w) => w.kanji), ['猫', '魚', '食べる']);
  });

  test('glues a pre-noun word ahead, する and helpers behind', () {
    expect(tile('私は昨日この本を読んだ。')!.tiles, ['私は', '昨日', 'この本を', '読んだ']);
    expect(tile('私は毎日勉強した。')!.tiles, ['私は', '毎日', '勉強した']);
    expect(tile('私は毎日勉強できる。')!.tiles, ['私は', '毎日', '勉強できる']);
    expect(tile('猫が魚を食べてしまった。')!.tiles, ['猫が', '魚を', '食べてしまった']);
  });

  test('records the particle each tile ends in', () {
    expect(tile('猫は魚を食べた。')!.particles, ['は', 'を', null]);
    expect(tile('私は毎日勉強した。')!.particles, ['は', null, null]);
    expect(tile('私は昨日この本を読んだ。')!.particles, ['は', null, 'を', null]);
  });

  test('takes が or を after a case particle for a misread', () {
    expect(tile('猫をが食べた。'), isNull);
    expect(tile('私には本がある。')!.tiles, ['私には', '本が', 'ある']);
  });

  test('rejects what no tile set could hold', () {
    expect(tile('猫はCatです。'), isNull, reason: 'Latin');
    expect(tile('猫は１０匹です。'), isNull, reason: 'digits');
    expect(tile('「猫」です。'), isNull, reason: 'quotes');
    expect(tile('猫はぬぬぬ。'), isNull, reason: 'not in the dictionary');
  });

  group('accepts', () {
    test('phrases trade places, the verb stays last', () {
      final t = tile('私は昨日この本を読んだ。')!;
      expect(t.closes, [true, true, true, false]);
      expect(t.accepts([0, 1, 2, 3]), isTrue);
      expect(t.accepts([1, 0, 2, 3]), isTrue);
      expect(t.accepts([2, 0, 1, 3]), isTrue);
      expect(t.accepts([0, 1, 3, 2]), isFalse);
      expect(t.accepts([0, 1, 2]), isFalse);
      expect(t.accepts([0, 0, 2, 3]), isFalse);
    });

    test('a modifier moves with the word it modifies', () {
      final t = tile('私は面白い本を読んだ。')!;
      expect(t.tiles, ['私は', '面白い', '本を', '読んだ']);
      expect(t.closes, [true, false, true, false]);
      expect(t.accepts([1, 2, 0, 3]), isTrue, reason: '面白い本を私は');
      expect(t.accepts([2, 1, 0, 3]), isFalse);
      expect(t.accepts([1, 0, 2, 3]), isFalse);
    });

    test('a の phrase moves with its head', () {
      // 法の前にすべての人は平等です: as right as the example.
      const t = SentenceTiles(
        tiles: ['すべての人は', '法の', '前に', '平等です'],
        closes: [true, false, true, false],
        end: '。',
        words: [],
      );
      expect(t.accepts([1, 2, 0, 3]), isTrue);
      expect(t.accepts([2, 1, 0, 3]), isFalse);
      expect(t.accepts([1, 0, 2, 3]), isFalse);
    });

    test('two tiles alike may sit in either place', () {
      const t = SentenceTiles(
        tiles: ['猫が', '猫が', '来た'],
        closes: [false, false, false],
        end: '。',
        words: [],
      );
      expect(t.accepts([1, 0, 2]), isTrue);
    });
  });
}
