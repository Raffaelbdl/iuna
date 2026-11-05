import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/games/pairs.dart';

import 'game_cards.dart';

void main() {
  final animals = [
    gameCard(1, '猫', 'ねこ', meaning: 'cat'),
    gameCard(2, '犬', 'いぬ', meaning: 'dog'),
    gameCard(3, '熊', 'くま', meaning: 'bear'),
    gameCard(4, '鳥', 'とり', meaning: 'bird, fowl, poultry'),
  ];

  PairsRound deal(List<DailyDeckEntry> cards, PairsMode mode) =>
      PairsRound.deal([...cards], mode, Random(0))!;

  group('deal', () {
    test('asks no reading of a kana-only word', () {
      final round = deal([
        gameCard(9, 'すごい', 'すごい'),
        ...animals,
      ], PairsMode.reading);
      expect(round.cardIds, isNot(contains(9)));
      expect(round.right.map((t) => t.text), containsAll(['ねこ', 'いぬ']));
    });

    test('takes the first cards of the order, up to the size', () {
      final cards = [for (var i = 0; i < 10; i++) gameCard(i, '字$i', 'じ$i')];
      final round = PairsRound.deal(cards, PairsMode.reading, Random(0))!;
      expect(round.cardIds.toSet(), {0, 1, 2, 3, 4, 5});
    });

    test('never deals two faces alike', () {
      final sound = deal([
        gameCard(10, '橋', 'はし', meaning: 'bridge'),
        gameCard(11, '箸', 'はし', meaning: 'chopsticks'),
        ...animals,
      ], PairsMode.sound);
      expect(sound.cardIds, contains(10));
      expect(sound.cardIds, isNot(contains(11)), reason: 'sounds the same');

      final meaning = deal([
        gameCard(12, '行く', 'いく', meaning: 'to go, to move'),
        gameCard(13, '往く', 'ゆく', meaning: 'To go'),
        ...animals,
      ], PairsMode.meaning);
      expect(meaning.cardIds, isNot(contains(13)), reason: 'reads the same');
    });

    test('shows two glosses at most', () {
      final round = deal(animals, PairsMode.meaning);
      expect(round.right.map((t) => t.text), contains('bird, fowl'));
    });

    test('drops JMdict notes from a gloss, nested or holding commas', () {
      expect(
        shortGloss('dog (Canis (lupus) familiaris), canine'),
        'dog, canine',
      );
      expect(
        shortGloss('cat (esp. the domestic cat, Felis catus), feline'),
        'cat, feline',
      );
      expect(shortGloss('(something) else'), 'else');
      expect(shortGloss('(only a note)'), '(only a note)');
    });

    test('a sound tile says the reading and is matched to the writing', () {
      final round = deal(animals, PairsMode.sound);
      final cat = round.left.firstWhere((t) => t.cardId == 1);
      expect(cat.sound, isTrue);
      expect(cat.text, 'ねこ');
      expect(round.right.firstWhere((t) => t.cardId == 1).text, '猫');
    });

    test('is null with fewer than three pairs', () {
      expect(
        PairsRound.deal(animals.take(2).toList(), PairsMode.reading, Random(0)),
        isNull,
      );
    });
  });

  group('tap', () {
    late PairsRound round;
    PairTile left(int id) => round.left.firstWhere((t) => t.cardId == id);
    PairTile right(int id) => round.right.firstWhere((t) => t.cardId == id);

    setUp(() => round = deal(animals, PairsMode.reading));

    test('selects, lets go, and moves within a column', () {
      expect(round.tap(left(1)), PairsTap.selected);
      expect(round.tap(left(1)), PairsTap.deselected);
      expect(round.selected, isNull);
      round.tap(left(1));
      expect(round.tap(left(2)), PairsTap.selected);
      expect(round.selected, same(left(2)));
    });

    test('a wrong pair counts against the word picked first', () {
      round.tap(right(1));
      expect(round.tap(left(2)), PairsTap.miss);
      expect(round.misses, 1);
      expect(round.missedCards, {1});
      expect(round.selected, isNull);
    });

    test('matching every pair finishes, from either side', () {
      for (final id in [1, 2]) {
        round.tap(left(id));
        expect(round.tap(right(id)), PairsTap.match);
      }
      for (final id in [3, 4]) {
        round.tap(right(id));
        expect(round.tap(left(id)), PairsTap.match);
      }
      expect(round.finished, isTrue);
      expect(round.tap(left(1)), PairsTap.ignored);
    });
  });
}
