import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../db/database.dart';
import '../db/repository.dart';
import 'game_draw.dart';
import 'sentence_tiles.dart';

/// Tiles a batch of sentences; null for one that won't tile.
typedef SentenceTiler = Future<List<SentenceTiles?>> Function(List<String>);

/// Tiles against the dictionary at [path] in a short-lived isolate with
/// its own handle, so a batch never stalls a frame. Leaving the screen
/// mid-batch is harmless: the isolate finishes, closes its handle and
/// exits, and [SentenceFeed] drops what it returns.
SentenceTiler isolateTiler(String path) =>
    (sentences) => Isolate.run(() => tileSentencesWith(path, sentences));

/// One sentence to rebuild, drawn for [card].
class SentencePuzzle {
  const SentencePuzzle({
    required this.card,
    required this.example,
    required this.tiles,
  });

  final DailyDeckEntry card;
  final ExampleRow example;
  final SentenceTiles tiles;
}

/// Puzzles for one visit, a few ahead of the learner.
///
/// Cards come in [drawOrder], each card once a visit, with the example
/// the memory saw least recently that fits. A sentence fits if it
/// tiles, its tiles suit the game (`shape`: 3–5 for Sentence builder),
/// and every content word is owned or common, so the English and the
/// tiles are enough to solve it. The first batch is small so the first puzzle shows at once; the
/// rest refill in the background while the learner plays.
class SentenceFeed {
  SentenceFeed({
    required IunaRepository repo,
    required List<DailyDeckEntry> cards,
    required GameMemory memory,
    required Random random,
    required SentenceTiler tile,
    bool Function(SentenceTiles) shape = fitsOrder,
  }) : _repo = repo,
       _shape = shape,
       _cards = cards,
       _memory = memory,
       _random = random,
       _tile = tile,
       _owned = {for (final c in cards) (c.card.kanji, c.card.kana)};

  /// Cards per batch: few first, so the first puzzle shows at once.
  static const firstBatch = 3;
  static const batch = 10;

  /// A card's examples tried in a batch, least recently seen first:
  /// the first that fits is asked.
  static const examplesPerCard = 3;

  /// Refill below this many queued puzzles.
  static const lowWater = 3;

  final IunaRepository _repo;
  final List<DailyDeckEntry> _cards;
  final GameMemory _memory;
  final Random _random;
  final SentenceTiler _tile;
  final bool Function(SentenceTiles) _shape;
  final Set<(String, String)> _owned;

  final _queue = <SentencePuzzle>[];
  final _tried = <int>{};
  Future<void>? _filling;
  bool _exhausted = false;
  bool _disposed = false;

  /// The next puzzle, or null once this visit has no sentence left.
  Future<SentencePuzzle?> next() async {
    while (_queue.isEmpty && !_exhausted && !_disposed) {
      await _refill();
    }
    if (_queue.isEmpty) return null;
    final puzzle = _queue.removeAt(0);
    if (_queue.length < lowWater) unawaited(_refill());
    return puzzle;
  }

  /// Drops whatever a batch still running brings back.
  void dispose() => _disposed = true;

  Future<void> _refill() {
    if (_exhausted || _disposed) return Future.value();
    return _filling ??= _fill(
      _tried.isEmpty ? firstBatch : batch,
    ).whenComplete(() => _filling = null);
  }

  bool _knows(TileWord w) =>
      w.rarity == Rarity.common || _owned.contains((w.kanji, w.kana));

  Future<void> _fill(int want) async {
    // Many cards have no short sentence, so look at a few per pick.
    final candidates = [
      for (final c in drawOrder(_cards, _memory, _random))
        if (!_tried.contains(c.card.id)) c,
    ].take(want * 4).toList();
    final examples = await _repo.gameExamples([
      for (final c in candidates) c.card.id,
    ]);
    if (_disposed) return;
    final picks = <(DailyDeckEntry, List<ExampleRow>)>[];
    for (final c in candidates) {
      if (picks.length == want) break;
      _tried.add(c.card.id);
      final mine = examples[c.card.id];
      if (mine == null || mine.isEmpty) continue;
      picks.add((c, _leastRecentFirst(mine).take(examplesPerCard).toList()));
    }
    if (picks.isEmpty) {
      _exhausted = true;
      return;
    }
    final List<SentenceTiles?> tiled;
    try {
      tiled = await _tile([
        for (final (_, mine) in picks)
          for (final e in mine) e.sentence,
      ]);
    } catch (e) {
      // A dictionary that fails to open ends the game, not the app.
      if (kDebugMode) debugPrint('SentenceFeed: tiling failed: $e');
      _exhausted = true;
      return;
    }
    if (_disposed) return;
    var at = 0;
    for (final (card, mine) in picks) {
      SentencePuzzle? puzzle;
      for (final example in mine) {
        final t = tiled[at++];
        if (puzzle != null || !_fits(t)) continue;
        puzzle = SentencePuzzle(card: card, example: example, tiles: t!);
      }
      if (puzzle != null) _queue.add(puzzle);
    }
  }

  bool _fits(SentenceTiles? t) =>
      t != null && _shape(t) && t.words.every(_knows);

  /// Never shown first, then the one shown longest ago; ties by chance.
  List<ExampleRow> _leastRecentFirst(List<ExampleRow> examples) {
    final shuffled = [...examples]..shuffle(_random);
    return shuffled..sort(
      (a, b) => (_memory.exampleSeen(a.id) ?? -1).compareTo(
        _memory.exampleSeen(b.id) ?? -1,
      ),
    );
  }
}
