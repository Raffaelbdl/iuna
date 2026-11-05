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
