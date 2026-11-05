import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/games/game_draw.dart';
import 'package:iuna/games/sentence_feed.dart';
import 'package:iuna/games/sentence_tiles.dart';

import 'sentence_deck.dart';

Future<SentenceFeed> _feed(
  IunaRepository repo, {
  GameMemory? memory,
  SentenceTiler? tile,
  int seed = 1,
}) async => SentenceFeed(
  repo: repo,
  cards: await repo.gameCards(),
  memory: (memory ?? GameMemory())..startSession(),
  random: Random(seed),
  tile: tile ?? syncTiler(),
);

Future<List<SentencePuzzle>> _drain(SentenceFeed feed) async {
  final out = <SentencePuzzle>[];
  for (var p = await feed.next(); p != null; p = await feed.next()) {
    out.add(p);
  }
  return out;
}

void main() {
  test('asks each card once, only sentences it can clue and solve', () async {
    final (db, ids) = await sentenceDeck();
    addTearDown(db.close);
    final repo = IunaRepository(db);
    final puzzles = await _drain(await _feed(repo));

    expect(puzzles.map((p) => p.card.card.id).toSet(), {
      ids['猫'],
      ids['本'],
      ids['魚'],
      ids['勉強'],
    });
    expect(puzzles, hasLength(4), reason: 'one sentence per card');
    final sentences = puzzles.map((p) => p.example.sentence);
    expect(sentences, isNot(contains('私は鰻を食べた。')));
    expect(sentences, isNot(contains('私は昨日勉強した。')));
    for (final p in puzzles) {
      expect(p.tiles.tiles.length, inInclusiveRange(kMinTiles, kMaxTiles));
    }
  });

  test('the first batch is small, so the first puzzle comes at once', () async {
    final (db, _) = await sentenceDeck();
    addTearDown(db.close);
    final batches = <List<String>>[];
    final feed = await _feed(IunaRepository(db), tile: syncTiler(batches));
    await feed.next();
    expect(
      batches.first.length,
      lessThanOrEqualTo(SentenceFeed.firstBatch * SentenceFeed.examplesPerCard),
    );
  });

  test("takes the example the memory saw least recently", () async {
    final (db, ids) = await sentenceDeck();
    addTearDown(db.close);
    final repo = IunaRepository(db);
    final cat = (await repo.gameExamples([ids['猫']!]))[ids['猫']]!;
    final seenFirst = cat.firstWhere((e) => e.sentence == '猫は魚を食べた。');
    for (var seed = 0; seed < 5; seed++) {
      final memory = GameMemory()
        ..startSession()
        ..sawExample(seenFirst.id);
      final puzzles = await _drain(
        await _feed(repo, memory: memory, seed: seed),
      );
      final asked = puzzles.firstWhere((p) => p.card.card.id == ids['猫']);
      expect(asked.example.sentence, '猫が魚を食べてしまった。');
    }
  });

  test('a batch landing after dispose is dropped', () async {
    final (db, _) = await sentenceDeck();
    addTearDown(db.close);
    final gate = Completer<void>();
    final inner = syncTiler();
    final feed = await _feed(
      IunaRepository(db),
      tile: (s) async {
        await gate.future;
        return inner(s);
      },
    );
    final first = feed.next();
    await Future<void>.delayed(Duration.zero);
    feed.dispose();
    gate.complete();
    expect(await first, isNull);
  });

  test('a tiler that throws ends the feed, not the app', () async {
    final (db, _) = await sentenceDeck();
    addTearDown(db.close);
    final feed = await _feed(
      IunaRepository(db),
      tile: (_) async => throw StateError('no dictionary'),
    );
    expect(await feed.next(), isNull);
  });
}
