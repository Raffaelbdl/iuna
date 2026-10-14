part of 'repository.dart';

/// The unseen pool a booster draws from, loaded once and then consumed
/// pick by pick, so several packs claimed in a row share one load.
class _DrawPool {
  _DrawPool({required this.jlptOnly, required this.random});

  final bool jlptOnly;
  final Random random;

  /// Unowned card ids, grouped by rarity and split into JLPT vs
  /// non-JLPT subpools. The JLPT split lets the sampler bias toward
  /// JLPT vocabulary within a tier without changing the rarity curve.
  final Map<Rarity, ({_Bucket jlpt, _Bucket other})> tiers = {
    for (final r in Rarity.values) r: (jlpt: _Bucket(), other: _Bucket()),
  };

  /// Wishlisted ids still in the pool.
  final _Bucket wished = _Bucket();

  void add(int id, Rarity rarity, {required bool jlpt, required bool wished}) {
    final tier = tiers[rarity]!;
    (jlpt ? tier.jlpt : tier.other).add(id);
    if (wished) this.wished.add(id);
  }

  /// Draws up to [count] cards. Each slot is filled by either:
  /// (a) with probability [kWishlistDrawBias], a uniform pick from the
  ///     unseen ∩ wishlist set (if any), so wishlisted cards surface
  ///     fast — the user can mark a word seen in the wild and expect
  ///     it within a few packs. The [jlptOnly] filter does not apply
  ///     to this branch: bookmarked cards always remain reachable.
  /// (b) otherwise, a rarity drawn from [kBoosterRarityWeights]
  ///     (renormalised over non-empty tiers); within that tier a
  ///     [kJlptDrawBias]-weighted coin flip picks from the JLPT vs
  ///     non-JLPT subpool, then a uniform card from the chosen side.
  ///     Under [jlptOnly] the non-JLPT subpool is treated as empty.
  /// Picks leave the pool, so neither this pack nor a later one drawn
  /// from the same pool can repeat a card.
  List<int> draw(int count) {
    final picked = <int>[];
    for (var i = 0; i < count; i++) {
      final wantWishlisted =
          wished.isNotEmpty && random.nextDouble() < kWishlistDrawBias;
      final id = wantWishlisted ? _drawWishlisted() : _drawWeighted();
      if (id == null) break;
      picked.add(id);
    }
    return picked;
  }

  bool _tierIsEmpty(Rarity r) {
    final tier = tiers[r]!;
    if (jlptOnly) return tier.jlpt.isEmpty;
    return tier.jlpt.isEmpty && tier.other.isEmpty;
  }

  int _drawWishlisted() {
    final id = wished.takeAt(random.nextInt(wished.length));
    for (final tier in tiers.values) {
      if (tier.jlpt.remove(id) || tier.other.remove(id)) break;
    }
    return id;
  }

  int? _drawWeighted() {
    final candidates = [
      for (final r in Rarity.values)
        if (!_tierIsEmpty(r)) r,
    ];
    if (candidates.isEmpty) return null;
    final totalWeight = candidates
        .map((r) => kBoosterRarityWeights[r] ?? 0.0)
        .fold<double>(0, (a, b) => a + b);
    final roll = random.nextDouble() * totalWeight;
    var cumulative = 0.0;
    var chosen = candidates.last;
    for (final r in candidates) {
      cumulative += kBoosterRarityWeights[r] ?? 0.0;
      if (roll < cumulative) {
        chosen = r;
        break;
      }
    }
    final tier = tiers[chosen]!;
    final wantJlpt =
        jlptOnly ||
        (tier.jlpt.isNotEmpty &&
            (tier.other.isEmpty || random.nextDouble() < kJlptDrawBias));
    final bucket = wantJlpt ? tier.jlpt : tier.other;
    final id = bucket.takeAt(random.nextInt(bucket.length));
    wished.remove(id);
    return id;
  }
}

/// Card ids with O(1) add, remove-by-id and remove-at-index (the last
/// id fills the hole, so order isn't kept).
class _Bucket {
  final _ids = <int>[];
  final _indexOf = <int, int>{};

  int get length => _ids.length;
  bool get isEmpty => _ids.isEmpty;
  bool get isNotEmpty => _ids.isNotEmpty;

  void add(int id) {
    _indexOf[id] = _ids.length;
    _ids.add(id);
  }

  int takeAt(int index) {
    final id = _ids[index];
    remove(id);
    return id;
  }

  bool remove(int id) {
    final index = _indexOf.remove(id);
    if (index == null) return false;
    final last = _ids.removeLast();
    if (last != id) {
      _ids[index] = last;
      _indexOf[last] = index;
    }
    return true;
  }
}

/// Today's booster allowance, read in one go.
class _BoosterGate {
  _BoosterGate(this.day, {required this.perDay, required this.claimed});

  final _LogicalDay day;
  final int perDay;
  final int claimed;

  int get remaining => max(0, perDay - claimed);
}
