import '../db/jmdict_lookup.dart';
import '../db/repository.dart';
import 'deck.dart';

/// The tutor's bookmarks go on the deck's wishlist, which the booster
/// draw favours. A word the deck lacks comes in from the dictionary
/// sidecar, as Add card does it.
class DeckBookmarks implements WordBookmarks {
  DeckBookmarks(this.repo);

  final IunaRepository repo;

  @override
  Future<BookmarkOutcome> bookmark(String word, String reading) async {
    final found = await repo.lookupByHeadword(word, reading);
    switch (found.status) {
      case CardLookupStatus.owned:
        return BookmarkOutcome.owned;
      case CardLookupStatus.wishlisted:
        return BookmarkOutcome.alreadyBookmarked;
      case CardLookupStatus.available:
        await repo.addToWishlist(found.cardId!);
        return BookmarkOutcome.bookmarked;
      case CardLookupStatus.notFound:
        final dictionary = JmdictLookup.instance;
        final hit = await dictionary.exact(word, reading);
        if (hit == null) {
          return dictionary.isOpen ? BookmarkOutcome.notFound : BookmarkOutcome.noDictionary;
        }
        await repo.promoteFromJmdict(hit);
        return BookmarkOutcome.bookmarked;
    }
  }

  @override
  Future<CardLookupStatus> status(String word, String reading) async =>
      (await repo.lookupByHeadword(word, reading)).status;

  @override
  Future<CardLookupStatus> wishlist(JmdictHit entry) async {
    final found = await repo.lookupByHeadword(entry.kanji, entry.kana);
    switch (found.status) {
      case CardLookupStatus.owned || CardLookupStatus.wishlisted:
        return found.status;
      case CardLookupStatus.available:
        await repo.addToWishlist(found.cardId!);
      case CardLookupStatus.notFound:
        await repo.promoteFromJmdict(entry);
    }
    return CardLookupStatus.wishlisted;
  }
}
