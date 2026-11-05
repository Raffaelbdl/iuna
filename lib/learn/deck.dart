import '../db/database.dart';
import '../db/jmdict_lookup.dart';
import '../db/repository.dart';

/// What bookmarking one word did.
enum BookmarkOutcome {
  bookmarked('bookmarked'),
  alreadyBookmarked('already bookmarked'),
  owned('already in their collection — left alone'),
  notFound('not found — check the written form and the reading'),
  noDictionary(
    'not in the built-in deck, and the full dictionary is not '
    'downloaded (Settings → Dictionary)',
  );

  const BookmarkOutcome(this.wire);

  /// How the bookmark tool reports it to the model.
  final String wire;
}

/// The learner's card deck, as far as the tutor and its word sheet may
/// touch it: they wishlist, and only the booster reveal makes a card
/// owned.
abstract interface class WordBookmarks {
  /// Bookmarks `(word, reading)` unless the learner already owns it.
  Future<BookmarkOutcome> bookmark(String word, String reading);

  Future<CardLookupStatus> status(String word, String reading);

  /// Wishlists the entry the learner is looking at, bringing it into
  /// the deck if needed; returns where it stands afterwards.
  Future<CardLookupStatus> wishlist(JmdictHit entry);
}

/// The card a question was asked from, as the tutor's prompt shows it.
class FocusCard {
  const FocusCard({
    required this.kanji,
    required this.kana,
    required this.senses,
    this.jlptLevel,
    this.wished = false,
    this.level,
    this.failCount = 0,
  });

  /// Senses as prompt lines, part of speech first when there is one.
  factory FocusCard.fromDeck(
    CardRow card,
    List<CardSenseRow> senses, {
    UserCardRow? userCard,
    bool wished = false,
  }) =>
      FocusCard(
        kanji: card.kanji,
        kana: card.kana,
        senses: senses.isEmpty
            ? [card.meaning]
            : [for (final s in senses) s.pos.isEmpty ? s.gloss : '(${s.pos}) ${s.gloss}'],
        jlptLevel: card.jlptLevel,
        wished: wished,
        level: userCard?.level,
        failCount: userCard?.failCount ?? 0,
      );

  final String kanji;
  final String kana;

  /// One line per sense, part of speech first when there is one.
  final List<String> senses;
  final int? jlptLevel;
  final bool wished;

  /// The review level while the learner owns it; null when they don't.
  final int? level;
  final int failCount;

  bool get owned => level != null;

  String get headword => kanji == kana ? kana : '$kanji（$kana）';

  String get jlptLabel => jlptLevel == null ? 'unlisted' : 'N$jlptLevel';

  String numberedSenses({String indent = ''}) => numbered(senses, indent: indent);
}

/// `1. …` per line, as the tutor's briefs list things.
String numbered(List<String> lines, {String indent = ''}) =>
    [for (final (i, line) in lines.indexed) '$indent${i + 1}. $line'].join('\n');
