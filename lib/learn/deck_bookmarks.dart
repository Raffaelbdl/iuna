import '../db/jmdict_lookup.dart';
import '../db/repository.dart';
import 'agent/bookmark_tool.dart';

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
}
