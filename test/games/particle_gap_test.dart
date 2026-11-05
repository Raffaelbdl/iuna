import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/games/sentence_feed.dart';
import 'package:iuna/games/sentence_tiles.dart';
import 'package:iuna/games/sentences.dart';

import 'game_cards.dart';
import 'sentence_words.dart';

SentencePuzzle _puzzle(String sentence) => SentencePuzzle(
  card: gameCard(1, '猫', 'ねこ'),
  example: ExampleRow(id: 1, sentence: sentence, generated: false),
  tiles: tileSentence(sentence, sentenceLexicon())!,
);

void main() {
  test('fitsGap wants a particle to blank', () {
    expect(fitsGap(_puzzle('猫は魚を食べた。').tiles), isTrue);
    const none = SentenceTiles(
      tiles: ['食べた', 'ね'],
      closes: [false, false],
      end: '。',
      words: [],
      particles: [null, null],
    );
    expect(fitsGap(none), isFalse);
  });

  test('blanks a particle, offers it among choices never also right', () {
    final puzzle = _puzzle('猫は魚を食べた。');
    for (var seed = 0; seed < 40; seed++) {
      final gap = ParticleBoard(puzzle, Random(seed));
      expect(['は', 'を'], contains(gap.answer));
      expect(gap.choices, hasLength(kGapChoices));
      expect(gap.choices.toSet(), hasLength(kGapChoices));
      expect(gap.choices, contains(gap.answer));
      // Each answer's look-alikes, right in its place too.
      final alike = gap.answer == 'は' ? ['が', 'も', 'を'] : ['が', 'も', 'から', 'は'];
      for (final p in alike) {
        expect(gap.choices, isNot(contains(p)), reason: gap.answer);
      }
      expect(gap.around, gap.answer == 'は' ? ('猫', '魚を食べた。') : ('猫は魚', '食べた。'));
    }
  });

  test('the first pick stands', () {
    final gap = ParticleBoard(_puzzle('猫は魚を食べた。'), Random(1));
    expect(gap.right, isNull);
    final wrong = gap.choices.firstWhere((c) => c != gap.answer);
    gap.pick(wrong);
    gap.pick(gap.answer);
    expect(gap.picked, wrong);
    expect(gap.right, isFalse);
  });
}
