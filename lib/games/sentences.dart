import 'dart:math';

import 'sentence_feed.dart';
import 'sentence_tiles.dart';

/// Sentences per round, whichever the game.
const kSentencesPerRound = 5;

/// The games played on tiled example sentences: they share the feed,
/// the rounds and the screen, and differ in what a puzzle asks.
enum SentenceGame {
  order('Sentences', 'Put it in order', fitsOrder),
  particles('Particles', 'Fill the gap', fitsGap);

  const SentenceGame(this.title, this.prompt, this.shape);
  final String title;
  final String prompt;

  /// Whether a tiled sentence makes a puzzle of this game.
  final bool Function(SentenceTiles) shape;
}

/// A puzzle on screen, answered or not.
sealed class SentenceTask {
  SentencePuzzle get puzzle;

  /// Null until answered.
  bool? get right;
}

/// One puzzle on screen: the tiles in the bank and the ones placed.
class SentenceBoard implements SentenceTask {
  SentenceBoard(this.puzzle, Random random)
    : bank = _shuffled(puzzle.tiles, random);

  @override
  final SentencePuzzle puzzle;

  /// Tile indices in the order the bank shows them.
  final List<int> bank;

  /// Tile indices in the order the learner placed them.
  final List<int> placed = [];

  @override
  bool? right;

  SentenceTiles get tiles => puzzle.tiles;
  bool get complete => placed.length == tiles.tiles.length;
  bool get checked => right != null;

  /// Places a bank tile last, or sends a placed one back.
  void tap(int tile) {
    if (checked) return;
    if (!placed.remove(tile)) placed.add(tile);
  }

  bool check() => right = tiles.accepts(placed);

  /// Whether the tile placed at [at] reads as the sentence has it there.
  bool placedRight(int at) =>
      right == true || tiles.tiles[placed[at]] == tiles.tiles[at];

  /// Whether the learner's accepted order differs from the original,
  /// so the original is worth showing.
  bool get reordered =>
      [for (final i in placed) tiles.tiles[i]].join() != tiles.tiles.join();

  /// A shuffle that isn't already an answer.
  static List<int> _shuffled(SentenceTiles tiles, Random random) {
    final order = [for (var i = 0; i < tiles.tiles.length; i++) i];
    for (var tries = 0; tries < 12; tries++) {
      order.shuffle(random);
      if (!tiles.accepts(order)) break;
    }
    return order;
  }
}

/// The particles Particle gap blanks.
const kGapParticles = ['は', 'が', 'を', 'に', 'で', 'へ', 'と', 'から', 'まで', 'の', 'も'];

/// Particles often right in each other's place, which the English alone
/// can't settle (猫は / 猫が, 本を読んだ / 本は読んだ, 学校に / 学校へ,
/// 友達と会う / 友達に会う, 家を出る / 家から出る, 私の書いた /
/// 私が書いた): never offered against each other.
const _alike = {
  'は': {'が', 'も', 'を'},
  'が': {'は', 'も', 'の', 'を'},
  'を': {'が', 'も', 'から', 'は'},
  'も': {'は', 'が', 'を'},
  'に': {'へ', 'と'},
  'へ': {'に'},
  'と': {'に'},
  'の': {'が'},
  'から': {'を'},
};

/// Choices offered per gap.
const kGapChoices = 4;

/// One of [gaps], は at a third the weight of the rest: it fills a
/// third of all gaps, and with が, も and を never offered against it
/// it is the easiest to guess.
int _weighted(List<int> gaps, SentenceTiles t, Random random) {
  double weight(int i) => t.particles[i] == 'は' ? 1 / 3 : 1;
  var roll = random.nextDouble() * gaps.map(weight).reduce((a, b) => a + b);
  for (final i in gaps) {
    roll -= weight(i);
    if (roll < 0) return i;
  }
  return gaps.last;
}

bool _gapAt(SentenceTiles t, int i) =>
    i < t.particles.length && kGapParticles.contains(t.particles[i]);

/// Whether [t] makes a Particle gap puzzle: a particle to blank, and not
/// so long the sentence stops fitting the screen.
bool fitsGap(SentenceTiles t) =>
    t.tiles.length >= 2 &&
    t.tiles.length <= 8 &&
    [for (var i = 0; i < t.tiles.length; i++) i].any((i) => _gapAt(t, i));

/// A sentence with one particle blanked, and the choices for it.
class ParticleBoard implements SentenceTask {
  ParticleBoard(this.puzzle, Random random) {
    final tiles = puzzle.tiles;
    final gaps = [
      for (var i = 0; i < tiles.tiles.length; i++)
        if (_gapAt(tiles, i)) i,
    ];
    gap = _weighted(gaps, tiles, random);
    answer = tiles.particles[gap]!;
    final others = [
      for (final p in kGapParticles)
        if (p != answer && !(_alike[answer]?.contains(p) ?? false)) p,
    ]..shuffle(random);
    choices = [answer, ...others.take(kGapChoices - 1)]..shuffle(random);
  }

  @override
  final SentencePuzzle puzzle;

  /// The tile whose particle is blanked.
  late final int gap;
  late final String answer;
  late final List<String> choices;

  /// The learner's choice, once made.
  String? picked;

  @override
  bool? get right => picked == null ? null : picked == answer;

  void pick(String particle) => picked ??= particle;

  /// The sentence around the blank: before it, then after it.
  (String, String) get around {
    final tiles = puzzle.tiles.tiles;
    final stem = tiles[gap].substring(0, tiles[gap].length - answer.length);
    return (
      tiles.take(gap).join() + stem,
      tiles.skip(gap + 1).join() + puzzle.tiles.end,
    );
  }
}
