import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/games/game_draw.dart';

import 'game_cards.dart';

void main() {
  group('GameMemory', () {
    test('survives a round trip through meta', () {
      final memory = GameMemory()
        ..startSession()
        ..saw([1, 2])
        ..missed(2);
      final back = GameMemory.parse(memory.encode());
      expect(back.session, 1);
      expect(back.sighting(1), (session: 1, missed: false));
      expect(back.sighting(2), (session: 1, missed: true));
    });

    test('reads anything unreadable as empty', () {
      for (final raw in [null, '', 'not json', '{"session": "x"}', '[]']) {
        final memory = GameMemory.parse(raw);
        expect(memory.session, 0, reason: '$raw');
        expect(memory.cooldown(1), 1, reason: '$raw');
      }
    });

    test('rests the last sessions, a missed card less', () {
      final memory = GameMemory()
        ..startSession()
        ..saw([1, 2])
        ..missed(2);
      expect(memory.cooldown(1), 0.05, reason: 'played this visit');
      memory.startSession();
      expect(memory.cooldown(1), 0.1);
      expect(memory.cooldown(2), 0.5);
      memory.startSession();
      expect(memory.cooldown(1), 0.4);
      memory.startSession();
      expect(memory.cooldown(1), 0.7);
      memory.startSession();
      expect(memory.cooldown(1), 1);
      expect(memory.sighting(1), isNull, reason: 'forgotten after 3');
    });

    test('restore undoes a sighting, back to what came before', () {
      final memory = GameMemory()
        ..startSession()
        ..saw([1]);
      memory.startSession();
      final before = memory.saw([1, 2]);
      expect(before, {1: (session: 1, missed: false), 2: null});
      memory.restore(before);
      expect(memory.sighting(1), (session: 1, missed: false));
      expect(memory.sighting(2), isNull);
      expect(memory.cooldown(2), 1);
    });

    test('a later sighting in the same session keeps its miss', () {
      final memory = GameMemory()
        ..startSession()
        ..missed(1)
        ..saw([1]);
      expect(memory.sighting(1)!.missed, isTrue);
      memory
        ..startSession()
        ..saw([1]);
      expect(memory.sighting(1)!.missed, isFalse);
    });
  });

  test('struggleWeight rises as ease falls, fails break ties', () {
    double w(double ease, [int fails = 0]) =>
        struggleWeight(gameCard(1, '猫', 'ねこ', ease: ease, fails: fails));
    expect(w(3.0), 1);
    expect(w(1.3), 5);
    expect(w(1.3), greaterThan(w(2.0)));
    expect(w(2.0), greaterThan(w(2.5)));
    expect(w(2.0, 3), greaterThan(w(2.0)));
  });

  test('drawOrder keeps every card once', () {
    final cards = [for (var i = 0; i < 20; i++) gameCard(i, 'k$i', 'k$i')];
    final order = drawOrder(cards, GameMemory(), Random(1));
    expect(order.map((c) => c.card.id).toSet(), hasLength(20));
  });

  // The worry this guards: opening the games and finding the same weak
  // cards every time.
  test('struggling cards lead often, but not the same ones each session', () {
    final cards = [
      for (var i = 0; i < 40; i++)
        gameCard(i, 'k$i', 'k$i', ease: i < 8 ? 1.3 : 2.5),
    ];
    bool weak(int id) => id < 8;
    const sessions = 5, perSession = 6, trials = 200;
    var weakPicks = 0, repeats = 0, everySession = 0;
    for (var t = 0; t < trials; t++) {
      final random = Random(t);
      final memory = GameMemory();
      final counts = <int, int>{};
      Set<int>? last;
      for (var s = 0; s < sessions; s++) {
        memory.startSession();
        final picked = {
          for (final c in drawOrder(cards, memory, random).take(perSession))
            c.card.id,
        };
        memory.saw(picked);
        weakPicks += picked.where(weak).length;
        if (last != null) repeats += picked.intersection(last).length;
        last = picked;
        for (final id in picked) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }
      everySession += counts.values.where((n) => n == sessions).length;
    }
    final picks = trials * sessions * perSession;
    // 8 of 40 cards: a fifth of the picks if the draw were blind.
    expect(weakPicks / picks, greaterThan(0.35));
    // Barely any card carries over from the session before.
    expect(repeats / (trials * (sessions - 1) * perSession), lessThan(0.1));
    expect(everySession, 0);
  });
}
