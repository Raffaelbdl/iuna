import 'dart:math';

import '../core/japanese_text.dart';
import '../db/repository.dart';

/// What a Pairs round matches. The left column is the prompt, the right
/// the answer.
enum PairsMode {
  reading('Kanji ↔ reading'),
  meaning('Word ↔ meaning'),
  sound('Sound ↔ word');

  const PairsMode(this.label);
  final String label;
}

/// Pairs per round, and the fewest a round can be dealt with.
const kPairsPerRound = 6;
const kMinPairs = 3;

enum PairSide { left, right }

/// One tile: [text] is what it shows, or what it says aloud when
/// [sound] is set.
class PairTile {
  const PairTile({
    required this.cardId,
    required this.side,
    required this.text,
    this.sound = false,
  });

  final int cardId;
  final PairSide side;
  final String text;
  final bool sound;

  /// Japanese, rather than an English gloss.
  bool get japanese => japaneseRun.hasMatch(text);
}

enum PairsTap { ignored, selected, deselected, match, miss }

/// A card's headline meaning (glosses joined by `, `, a few by `; `)
/// cut to its first two glosses, without
/// JMdict's parenthesised notes ("dog (Canis (lupus) familiaris),
/// canine" → "dog, canine"), so a tile stays short. Notes can nest and
/// hold commas, so they go before the split.
String shortGloss(String meaning) {
  final plain = StringBuffer();
  var depth = 0;
  for (final ch in meaning.split('')) {
    if (ch == '(') {
      depth++;
    } else if (ch == ')' && depth > 0) {
      depth--;
    } else if (depth == 0) {
      plain.write(ch);
    }
  }
  final short = plain
      .toString()
      .split(RegExp('[,;]'))
      .map((g) => g.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((g) => g.isNotEmpty)
      .take(2)
      .join(', ');
  return short.isEmpty ? meaning.trim() : short;
}

/// The two faces of [card] in [mode], or null when the mode can't ask
/// it: a kana-only word has no reading to match.
(PairTile, PairTile)? _faces(DailyDeckEntry entry, PairsMode mode) {
  final c = entry.card;
  final id = c.id;
  return switch (mode) {
    PairsMode.reading when c.kanji == c.kana => null,
    PairsMode.reading => (
      PairTile(cardId: id, side: PairSide.left, text: c.kanji),
      PairTile(cardId: id, side: PairSide.right, text: c.kana),
    ),
    PairsMode.meaning => (
      PairTile(cardId: id, side: PairSide.left, text: c.kanji),
      PairTile(cardId: id, side: PairSide.right, text: shortGloss(c.meaning)),
    ),
    PairsMode.sound => (
      PairTile(cardId: id, side: PairSide.left, text: c.kana, sound: true),
      PairTile(cardId: id, side: PairSide.right, text: c.kanji),
    ),
  };
}

/// What makes two faces the same for the learner: a homophone sounds
/// like its twin, and "to go" reads like "to go, to move".
String _sameness(PairTile t) =>
    t.japanese || t.sound ? t.text : t.text.split(', ').first.toLowerCase();

/// One round: the tiles, what's matched, and what was missed.
class PairsRound {
  PairsRound._(this.mode, this.left, this.right);

  /// Takes cards from [order] (see `drawOrder`) until [size] fit [mode]
  /// with no two faces alike on either side, then shuffles each column.
  /// Null when fewer than [kMinPairs] fit.
  static PairsRound? deal(
    List<DailyDeckEntry> order,
    PairsMode mode,
    Random random, {
    int size = kPairsPerRound,
  }) {
    final left = <PairTile>[], right = <PairTile>[];
    final seenLeft = <String>{}, seenRight = <String>{};
    for (final entry in order) {
      if (left.length == size) break;
      final faces = _faces(entry, mode);
      if (faces == null) continue;
      final (l, r) = faces;
      final lk = _sameness(l), rk = _sameness(r);
      if (lk.isEmpty || rk.isEmpty) continue;
      if (seenLeft.contains(lk) || seenRight.contains(rk)) continue;
      seenLeft.add(lk);
      seenRight.add(rk);
      left.add(l);
      right.add(r);
    }
    if (left.length < kMinPairs) return null;
    return PairsRound._(mode, left..shuffle(random), right..shuffle(random));
  }

  final PairsMode mode;
  final List<PairTile> left;
  final List<PairTile> right;

  PairTile? selected;
  final Set<int> matched = {};

  /// Cards whose tile was picked first in a wrong pair: the word the
  /// learner was trying to place.
  final Set<int> missedCards = {};
  int misses = 0;

  Iterable<int> get cardIds => left.map((t) => t.cardId);
  int get size => left.length;
  bool get finished => matched.length == size;

  PairsTap tap(PairTile tile) {
    if (matched.contains(tile.cardId)) return PairsTap.ignored;
    final first = selected;
    if (identical(first, tile)) {
      selected = null;
      return PairsTap.deselected;
    }
    if (first == null || first.side == tile.side) {
      selected = tile;
      return PairsTap.selected;
    }
    selected = null;
    if (first.cardId == tile.cardId) {
      matched.add(tile.cardId);
      return PairsTap.match;
    }
    missedCards.add(first.cardId);
    misses++;
    return PairsTap.miss;
  }
}
