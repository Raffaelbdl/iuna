import 'dart:convert';
import 'dart:math';

import '../db/repository.dart';
import '../services/scheduler.dart';

/// How many past sessions [GameMemory] remembers cards for.
const kGameMemorySessions = 3;

/// And sentences: a card's few examples rotate over more visits.
const kExampleMemorySessions = 12;

/// One card's last appearance in a game.
typedef GameSighting = ({int session, bool missed});

/// The cards recent game sessions showed. A session is one visit to a
/// game screen, however many rounds it holds.
///
/// Sessions are counted rather than timed: the games are played now
/// and then, and a cooldown measured in days would have run out by the
/// next visit, showing the same weak cards again.
class GameMemory {
  GameMemory({
    this.session = 0,
    Map<int, GameSighting>? cards,
    Map<int, int>? examples,
  }) : _cards = cards ?? {},
       _examples = examples ?? {};

  /// The current session, or the last one before [startSession].
  int session;
  final Map<int, GameSighting> _cards;

  /// Example sentence id → the session that last showed it.
  final Map<int, int> _examples;

  /// Reads what [encode] wrote. Anything unreadable is an empty memory:
  /// losing it only costs a few repeats.
  factory GameMemory.parse(String? raw) {
    if (raw == null || raw.isEmpty) return GameMemory();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final cards = json['cards'] as Map<String, dynamic>;
      final examples = json['examples'] as Map<String, dynamic>? ?? {};
      return GameMemory(
        session: json['session'] as int,
        cards: {
          for (final MapEntry(:key, :value) in cards.entries)
            int.parse(key): (
              session: (value as List)[0] as int,
              missed: value[1] as bool,
            ),
        },
        examples: {
          for (final MapEntry(:key, :value) in examples.entries)
            int.parse(key): value as int,
        },
      );
    } catch (_) {
      return GameMemory();
    }
  }

  String encode() => jsonEncode({
    'session': session,
    'cards': {
      for (final MapEntry(:key, :value) in _cards.entries)
        '$key': [value.session, value.missed],
    },
    'examples': {
      for (final MapEntry(:key, :value) in _examples.entries) '$key': value,
    },
  });

  /// Opens a new session and forgets cards older than the last
  /// [kGameMemorySessions].
  void startSession() {
    session++;
    _cards.removeWhere((_, s) => session - s.session > kGameMemorySessions);
    _examples.removeWhere((_, s) => session - s > kExampleMemorySessions);
  }

  /// The session that last showed example [exampleId], if remembered.
  int? exampleSeen(int exampleId) => _examples[exampleId];

  void sawExample(int exampleId) => _examples[exampleId] = session;

  GameSighting? sighting(int cardId) => _cards[cardId];

  /// Marks [cardIds] as shown this session; a miss earlier in the same
  /// session stands. Returns what each card had before, for [restore].
  Map<int, GameSighting?> saw(Iterable<int> cardIds) {
    final before = <int, GameSighting?>{};
    for (final id in cardIds) {
      final prior = before[id] = _cards[id];
      _cards[id] = (
        session: session,
        missed: prior?.session == session && prior!.missed,
      );
    }
    return before;
  }

  /// Puts back what [saw] returned, for cards shown but never played.
  void restore(Map<int, GameSighting?> before) {
    for (final MapEntry(:key, :value) in before.entries) {
      if (value == null) {
        _cards.remove(key);
      } else {
        _cards[key] = value;
      }
    }
  }

  void missed(int cardId) => _cards[cardId] = (session: session, missed: true);

  /// What [cardId]'s draw weight is multiplied by. A missed card rests
  /// less, so it comes back sooner.
  double cooldown(int cardId) {
    final s = _cards[cardId];
    if (s == null) return 1;
    return switch (session - s.session) {
      // Already played this visit: only when nothing else is left.
      0 => 0.05,
      1 => s.missed ? 0.5 : 0.1,
      2 => s.missed ? 0.8 : 0.4,
      3 => s.missed ? 1.0 : 0.7,
      _ => 1,
    };
  }
}

/// How much a card is worth drawing from its reviews alone, from 1 for
/// a card at full ease to about 5 at the floor. Ease is the live signal
/// (each miss costs 0.2, each hit gives back 0.1); the lifetime fail
/// count only breaks ties.
double struggleWeight(DailyDeckEntry entry) {
  final u = entry.userCard;
  final s = ((maxEase - u.ease) / (maxEase - minEase)).clamp(0.0, 1.0);
  return 1 + 4 * s * s + 0.1 * min(u.failCount, 10);
}

/// Every card in [cards], in the order a game should take them: a
/// weighted shuffle (Efraimidis–Spirakis), so struggling cards lead
/// more often without leading every time, and the ones [memory] saw
/// recently sink.
///
/// Games walk the order and skip what doesn't fit (a homophone, a
/// kana-only word where a reading is asked), so a full order rather
/// than a fixed count.
List<DailyDeckEntry> drawOrder(
  List<DailyDeckEntry> cards,
  GameMemory memory,
  Random random,
) {
  final keyed = [
    for (final c in cards)
      (
        card: c,
        key: pow(
          random.nextDouble(),
          1 / (struggleWeight(c) * memory.cooldown(c.card.id)),
        ),
      ),
  ]..sort((a, b) => b.key.compareTo(a.key));
  return [for (final k in keyed) k.card];
}
