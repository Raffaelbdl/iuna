import 'dart:math';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show protected;

import '../core/pack_format.dart';
import '../services/scheduler.dart';
import 'database.dart';
import 'jmdict_lookup.dart' show JmdictHit;
import 'meta_store.dart';

part 'booster_draw.dart';
part 'repository_stats.dart';

/// Keys stored in the `meta` table.
class MetaKeys {
  static const lastBoosterDate = 'last_booster_date';
  static const lastSeenTs = 'last_seen_ts';
  static const streakCount = 'streak_count';
  static const streakAnchorDate = 'streak_anchor_date';
  static const boostersPerDay = 'boosters_per_day';
  static const resetHour = 'reset_hour';
  static const boostersClaimedToday = 'boosters_claimed_today';
  static const reviewTimeCapSeconds = 'review_time_cap_seconds';
  static const lastDriveBackupTs = 'last_drive_backup_ts';
  static const jlptOnly = 'jlpt_only';
  /// Name of the themed pack booster draws are restricted to. Empty
  /// (or absent) means "draw from everything". Deliberately not a
  /// boolean — more packs will ship alongside `science`.
  static const boosterPackFilter = 'booster_pack_filter';
}

/// What applying a pack changed. [tagged] counts headwords the deck
/// already had — they keep everything and just join the pack.
class PackApplyResult {
  const PackApplyResult({required this.added, required this.tagged});

  final int added;
  final int tagged;

  int get total => added + tagged;
}

const int kDefaultBoostersPerDay = 1;
const int kMinBoostersPerDay = 1;
const int kMaxBoostersPerDay = 5;
const int kDefaultResetHour = 0;
const int kDefaultPackSize = 10;

class JmdictPromotionResult {
  const JmdictPromotionResult({required this.cardId, required this.wasNew});

  final int cardId;

  /// True when a new `cards` row was created. False when the card
  /// already existed (seed or user-added) and we just touched the
  /// wishlist.
  final bool wasNew;
}

/// Where a JMdict hit currently lives in the user's iuna database.
/// Used by the Add Card screen to label the action button + badge.
enum CardLookupStatus {
  /// `(kanji, kana)` has no row in `cards` yet. Promotion will mint
  /// a new card (source=user) and wishlist it.
  notFound,

  /// Card exists in `cards` (seed or user-added) but the user does
  /// not own it and hasn't wishlisted it. Promotion will wishlist.
  available,

  /// Card exists and is on the wishlist already, but unowned.
  /// Promotion is a no-op; the booster sampler is already biased
  /// toward this card.
  wishlisted,

  /// Card is in `user_cards` — already in the user's collection.
  /// Promotion would no-op; the UI should offer "Open card" instead.
  owned,
}

class CardLookup {
  const CardLookup({required this.status, this.cardId});
  final CardLookupStatus status;
  final int? cardId;
}
const int kDefaultReviewTimeCapSeconds = 10;
const int kMinReviewTimeCapSeconds = 5;
const int kMaxReviewTimeCapSeconds = 60;

/// Per-pull rarity weights for [IunaRepository.claimAllAvailableBoosters].
/// Each draw within a pack first picks a rarity according to these weights
/// (Common 49% / Rare 30% / SR 15% / SSR 5% / UR 1%), then samples a
/// random unseen card *of that rarity*. If the chosen tier has no
/// unseen cards left, the draw falls back to the next non-empty tier
/// (weighted-renormalised) so the pack never short-changes the player.
///
/// Curve is gacha-shaped on purpose — the seed's rarity distribution is
/// derived from real-world frequency / JLPT signals, so a uniform
/// sample reads upside-down (UR ~14%, Rare ~7.5%). These weights make
/// pulls feel earned without changing the seed.
const Map<Rarity, double> kBoosterRarityWeights = {
  Rarity.common: 0.49,
  Rarity.rare: 0.30,
  Rarity.superRare: 0.15,
  Rarity.ssr: 0.05,
  Rarity.ur: 0.01,
};

/// Per-draw probability that a slot is filled from the unseen wishlist
/// instead of the regular rarity-weighted pool. Tuned so a small
/// wishlist (≤ 10 cards) clears within ~a week at 1 pack/day:
/// expected pulls to land a specific wishlisted card is `K / 0.3` where
/// K is the wishlist size, so K=10 → ~33 draws ≈ 3.3 days.
const double kWishlistDrawBias = 0.3;

/// Within the chosen rarity tier, probability of picking from the
/// JLPT-tagged subpool (cards with a non-null `jlpt_level`) rather than
/// the non-JLPT one. Applies after the rarity has been chosen, so the
/// overall rarity curve from [kBoosterRarityWeights] is preserved —
/// only the within-tier mix shifts toward JLPT vocabulary, nudging the
/// player toward N5..N1 completion. Falls back to the non-empty side
/// if a tier has only JLPT or only non-JLPT cards left.
const double kJlptDrawBias = 0.7;

class DailyDeckEntry {
  DailyDeckEntry({required this.card, required this.userCard});

  final CardRow card;
  final UserCardRow userCard;

  bool get isNew => userCard.isNew;
}

/// One row in the collection grid: a card plus the player's review
/// state. [userCard] is null when the entry comes from a "show missing"
/// query (i.e. unowned cards rendered as silhouettes).
class CollectionEntry {
  CollectionEntry({required this.card, this.userCard});

  final CardRow card;
  final UserCardRow? userCard;

  bool get isOwned => userCard != null;
}

/// Aggregate "owned vs in existence" counts, broken out by rarity for
/// the per-tier progress bar in the collection header.
class CollectionStats {
  CollectionStats({
    required this.ownedByRarity,
    required this.totalByRarity,
  });

  final Map<Rarity, int> ownedByRarity;
  final Map<Rarity, int> totalByRarity;

  int get owned =>
      ownedByRarity.values.fold(0, (sum, value) => sum + value);
  int get total =>
      totalByRarity.values.fold(0, (sum, value) => sum + value);
}

class BoosterClaim {
  BoosterClaim({required this.cards});

  final List<CardRow> cards;
}

/// Reversible bundle captured by [IunaRepository.applyReview]. Pass it
/// back to [IunaRepository.undoReview] to roll a single review back: it
/// restores the prior `user_cards` row, deletes the appended
/// `review_log` entry, and decrements the matching `daily_stats`
/// counters.
class ReviewSnapshot {
  ReviewSnapshot({
    required this.priorUserCard,
    required this.reviewLogId,
    required this.dayKey,
    required this.rarity,
    required this.correct,
    required this.isFirstReview,
  });

  final UserCardRow priorUserCard;
  final int reviewLogId;
  final String dayKey;
  final Rarity rarity;
  final bool correct;
  final bool isFirstReview;
}

/// A clamped integer setting in the `meta` table.
class _IntSetting {
  const _IntSetting(this.key, this.fallback, this.min, this.max);

  final String key;
  final int fallback;
  final int min;
  final int max;

  int parse(String? raw) =>
      (int.tryParse(raw ?? '') ?? fallback).clamp(min, max);

  String format(int value) => '${value.clamp(min, max)}';
}

const _boostersPerDay = _IntSetting(
  MetaKeys.boostersPerDay,
  kDefaultBoostersPerDay,
  kMinBoostersPerDay,
  kMaxBoostersPerDay,
);
const _resetHour = _IntSetting(MetaKeys.resetHour, kDefaultResetHour, 0, 23);
const _reviewTimeCap = _IntSetting(
  MetaKeys.reviewTimeCapSeconds,
  kDefaultReviewTimeCapSeconds,
  kMinReviewTimeCapSeconds,
  kMaxReviewTimeCapSeconds,
);

/// The logical day containing [now] — the day rolls over at
/// [resetHour], not at midnight.
class _LogicalDay {
  _LogicalDay(this.now, this.resetHour)
      : key = logicalDayKey(now, resetHour),
        start = logicalDayStart(now, resetHour);

  final DateTime now;
  final int resetHour;
  final String key;
  final DateTime start;

  DateTime get end => start.add(const Duration(days: 1));

  String keyOf(DateTime t) => logicalDayKey(t, resetHour);

  /// Keys of the [count] logical days ending with this one, oldest
  /// first.
  List<String> lastKeys(int count) => [
        for (var i = count - 1; i >= 0; i--) shiftDayKey(key, -i),
      ];
}

class IunaRepository with MetaTimestamps {
  IunaRepository(this.db, {Random? random}) : _random = random ?? Random();

  final AppDatabase db;
  final Random _random;

  // ---------- meta helpers ----------

  @override
  @protected
  Future<String?> readMeta(String key) async {
    final row = await (db.select(db.meta)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  @override
  @protected
  Future<void> writeMeta(String key, String value) async {
    await db.into(db.meta).insertOnConflictUpdate(
          MetaCompanion.insert(key: key, value: value),
        );
  }

  /// Several meta values in one read; absent keys are absent.
  Future<Map<String, String>> _readMetas(List<String> keys) async {
    final rows =
        await (db.select(db.meta)..where((m) => m.key.isIn(keys))).get();
    return {for (final r in rows) r.key: r.value};
  }

  Future<_LogicalDay> _day(DateTime? now) async => _LogicalDay(
        now ?? DateTime.now(),
        _resetHour.parse(await readMeta(_resetHour.key)),
      );

  /// How many booster packs the user can claim per logical day.
  /// Clamped to [kMinBoostersPerDay]..[kMaxBoostersPerDay].
  Future<int> getBoostersPerDay() async =>
      _boostersPerDay.parse(await readMeta(_boostersPerDay.key));

  Future<void> setBoostersPerDay(int value) =>
      writeMeta(_boostersPerDay.key, _boostersPerDay.format(value));

  /// Local-clock hour at which the booster + streak day rolls over.
  /// `0` means midnight (the natural calendar boundary). Returning to
  /// the app at e.g. 03:00 local with `resetHour = 4` still counts as
  /// the previous day.
  Future<int> getResetHour() async =>
      _resetHour.parse(await readMeta(_resetHour.key));

  Future<void> setResetHour(int value) =>
      writeMeta(_resetHour.key, _resetHour.format(value));

  /// Maximum recorded review duration, in seconds. A review that takes
  /// longer than this is *still counted* as a review — only the
  /// `duration_ms` value is clamped, so the response-time stats aren't
  /// dominated by the times you put the phone down. Range
  /// [kMinReviewTimeCapSeconds]..[kMaxReviewTimeCapSeconds]; default
  /// [kDefaultReviewTimeCapSeconds].
  Future<int> getReviewTimeCapSeconds() async =>
      _reviewTimeCap.parse(await readMeta(_reviewTimeCap.key));

  Future<void> setReviewTimeCapSeconds(int value) =>
      writeMeta(_reviewTimeCap.key, _reviewTimeCap.format(value));

  Future<DateTime?> getLastDriveBackup() =>
      readTimestamp(MetaKeys.lastDriveBackupTs);

  Future<void> setLastDriveBackup(DateTime ts) =>
      writeTimestamp(MetaKeys.lastDriveBackupTs, ts);

  /// When true, every booster draw (and every suspend-and-replace) is
  /// restricted to cards with a non-null `jlpt_level`. The wishlist
  /// branch ignores this filter — explicitly bookmarked cards still
  /// surface even without a JLPT tag, since the user asked for them by
  /// name. Defaults to false.
  Future<bool> getJlptOnly() async {
    final raw = await readMeta(MetaKeys.jlptOnly);
    return raw == '1';
  }

  Future<void> setJlptOnly(bool value) async {
    await writeMeta(MetaKeys.jlptOnly, value ? '1' : '0');
    if (value) await writeMeta(MetaKeys.boosterPackFilter, '');
  }

  /// Themed pack booster draws are restricted to, or null for the whole
  /// dictionary. Same wishlist exemption as [getJlptOnly]: a bookmarked
  /// card surfaces whatever pack it belongs to.
  Future<String?> getBoosterPackFilter() async {
    final raw = await readMeta(MetaKeys.boosterPackFilter);
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  /// The two draw filters would intersect to almost nothing — pack
  /// cards are specialist vocabulary that JLPT doesn't rank — so
  /// turning one on clears the other rather than silently emptying the
  /// pool.
  Future<void> setBoosterPackFilter(String? pack) async {
    await writeMeta(MetaKeys.boosterPackFilter, pack ?? '');
    if (pack != null) await writeMeta(MetaKeys.jlptOnly, '0');
  }

  /// Installed packs, newest first. The row carries the label and the
  /// upstream attribution, so nothing here needs the network.
  Future<List<PackRow>> installedPacks() {
    return (db.select(db.packs)
          ..orderBy([(p) => OrderingTerm.desc(p.installedAt)]))
        .get();
  }

  /// Distinct `cards.pack` values actually present on cards, sorted.
  /// Read from `cards` rather than `packs` so a deck restored from a
  /// backup taken before the packs table existed still filters.
  Future<List<String>> availablePacks() async {
    final query = db.selectOnly(db.cards, distinct: true)
      ..addColumns([db.cards.pack])
      ..where(db.cards.pack.isNotNull());
    final rows = await query.get();
    final out = rows.map((r) => r.read(db.cards.pack)!).toList()..sort();
    return out;
  }

  /// Applies a downloaded pack payload. See [kPackFormatVersion] for
  /// why the document shape is decoupled from the schema.
  ///
  /// Additive by construction: a headword the deck already carries
  /// (seed row or user-added) keeps its id, its senses and — crucially
  /// — any `user_cards` scheduling state, and only gains the pack tag.
  /// Only genuinely new headwords are inserted, so re-applying a pack
  /// can neither duplicate a card nor reset progress. That makes
  /// re-downloading an updated pack safe: it tops up what's missing.
  ///
  /// Throws [PackFormatException] if the payload is unreadable.
  Future<PackApplyResult> applyPack(
    Map<String, dynamic> payload, {
    required String version,
    DateTime? now,
  }) async {
    final pack = PackDocument.parse(payload);
    var added = 0;
    var tagged = 0;

    await db.transaction(() async {
      final existing = <String, int>{};
      for (final row
          in await db.customSelect('SELECT id, kanji, kana FROM cards').get()) {
        existing[_headwordKey(
          row.read<String>('kanji'),
          row.read<String>('kana'),
        )] = row.read<int>('id');
      }

      final toTag = <int>{};
      final freshKeys = <String>{};
      final fresh = <PackCard>[];
      for (final card in pack.cards) {
        final key = _headwordKey(card.kanji, card.kana);
        final known = existing[key];
        if (known != null) {
          toTag.add(known);
        } else if (freshKeys.add(key)) {
          fresh.add(card);
        }
      }

      // Tag it and leave everything else alone — the dictionary's own
      // senses are richer than a pack's single gloss. A card already
      // claimed by *another* pack keeps that one: the tag is
      // single-valued and the first pack to reach a headword wins, so
      // overlapping packs can't fight over it.
      if (toTag.isNotEmpty) {
        tagged = await (db.update(db.cards)
              ..where((c) => c.id.isIn(toTag) & c.pack.isNull()))
            .write(CardsCompanion(pack: Value(pack.name)));
      }

      await db.batch((b) {
        b.insertAll(db.cards, [
          for (final card in fresh)
            CardsCompanion.insert(
              kanji: card.kanji,
              kana: card.kana,
              furigana: Value(card.furigana),
              meaning: card.meaning,
              rarity: Value(Rarity.values[card.rarity]),
              jlptLevel: Value(card.jlpt),
              source: const Value(CardSource.user),
              pack: Value(pack.name),
            ),
        ]);
      });
      added = fresh.length;

      final ids = <String, int>{
        for (final row in await (db.select(db.cards)
              ..where((c) => c.pack.equals(pack.name)))
            .get())
          _headwordKey(row.kanji, row.kana): row.id,
      };
      await db.batch((b) {
        b.insertAll(db.cardSenses, [
          for (final card in fresh)
            for (final sense in card.senses)
              CardSensesCompanion.insert(
                cardId: ids[_headwordKey(card.kanji, card.kana)]!,
                ordinal: sense.ordinal,
                pos: Value(sense.pos),
                gloss: sense.gloss,
                definition: Value(sense.definition),
              ),
        ]);
        b.insertAllOnConflictUpdate(db.packs, [
          PacksCompanion.insert(
            name: pack.name,
            label: pack.label,
            description: Value(pack.description),
            sourceTitle: Value(pack.sourceTitle),
            sourceUrl: Value(pack.sourceUrl),
            sourceAuthor: Value(pack.sourceAuthor),
            license: Value(pack.license),
            version: version,
            cardCount: Value(pack.cards.length),
            installedAt: now ?? DateTime.now(),
          ),
        ]);
      });
    });

    return PackApplyResult(added: added, tagged: tagged);
  }

  /// Separator is an escaped NUL, not a space: pack headwords can carry
  /// latin text with spaces (`20馬力のエンジン`), and joining on a space would let
  /// `("20 hp", "x")` and `("20", "hp x")` collide -- silently skipping
  /// one of them as already-present.
  String _headwordKey(String kanji, String kana) =>
      '$kanji\u0000$kana';

  // ---------- wishlist ----------

  /// Toggles a card's wishlist state. Returns the new value (`true`
  /// for wishlisted, `false` for not). Idempotent.
  Future<bool> toggleWishlist(int cardId, {DateTime? now}) async {
    final wished = await isWished(cardId);
    if (wished) {
      await (db.delete(db.wishlist)
            ..where((w) => w.cardId.equals(cardId)))
          .go();
      return false;
    }
    await db.into(db.wishlist).insert(
          WishlistCompanion.insert(
            cardId: Value(cardId),
            addedAt: now ?? DateTime.now(),
          ),
        );
    return true;
  }

  /// Wishlists [cardId]; a card already on the wishlist keeps its date.
  Future<void> addToWishlist(int cardId, {DateTime? now}) async {
    await db.into(db.wishlist).insert(
          WishlistCompanion.insert(
            cardId: Value(cardId),
            addedAt: now ?? DateTime.now(),
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  Future<bool> isWished(int cardId) async {
    final row = await (db.select(db.wishlist)
          ..where((w) => w.cardId.equals(cardId)))
        .getSingleOrNull();
    return row != null;
  }

  /// Card ids the user has wishlisted, in insertion order.
  Future<List<int>> wishedCardIds() async {
    final rows = await (db.select(db.wishlist)
          ..orderBy([(w) => OrderingTerm.asc(w.addedAt)]))
        .get();
    return rows.map((r) => r.cardId).toList();
  }

  // ---------- promotion from JMdict sidecar ----------

  /// Resolves where `(kanji, kana)` currently lives in the user's iuna
  /// database. Used by the Add Card preview sheet to label its action
  /// (Add / Bookmark / Already wishlisted / Open card) so the user
  /// isn't told they "bookmarked" an already-owned card.
  Future<CardLookup> lookupByHeadword(String kanji, String kana) async {
    final card = await (db.select(db.cards)
          ..where((c) => c.kanji.equals(kanji) & c.kana.equals(kana)))
        .getSingleOrNull();
    if (card == null) {
      return const CardLookup(status: CardLookupStatus.notFound);
    }
    final owned = await (db.select(db.userCards)
          ..where((u) => u.cardId.equals(card.id)))
        .getSingleOrNull();
    if (owned != null) {
      return CardLookup(status: CardLookupStatus.owned, cardId: card.id);
    }
    final wished = await (db.select(db.wishlist)
          ..where((w) => w.cardId.equals(card.id)))
        .getSingleOrNull();
    if (wished != null) {
      return CardLookup(status: CardLookupStatus.wishlisted, cardId: card.id);
    }
    return CardLookup(status: CardLookupStatus.available, cardId: card.id);
  }


  /// Promotes a JMdict sidecar [hit] into the user's deck:
  /// - If a card with the same `(kanji, kana)` already exists (seed or
  ///   previously user-added), returns its id with `wasNew = false`.
  ///   No senses are rewritten.
  /// - Otherwise inserts a new `cards` row (`source = user`) + senses
  ///   and returns the new id with `wasNew = true`.
  ///
  /// In both cases the card is added to the wishlist (idempotent), so
  /// the booster sampler surfaces it within a handful of packs at the
  /// existing `kWishlistDrawBias`. We don't pre-claim into `user_cards`
  /// — the SRS reveal loop is the only path that mints owned cards.
  Future<JmdictPromotionResult> promoteFromJmdict(
    JmdictHit hit, {
    DateTime? now,
  }) async {
    return db.transaction(() async {
      final existing = await (db.select(db.cards)
            ..where(
                (c) => c.kanji.equals(hit.kanji) & c.kana.equals(hit.kana)))
          .getSingleOrNull();

      var cardId = existing?.id;
      var wasNew = false;
      if (cardId == null) {
        cardId = await db.into(db.cards).insert(
              CardsCompanion.insert(
                kanji: hit.kanji,
                kana: hit.kana,
                meaning: hit.senses.isEmpty ? '' : hit.senses.first.gloss,
                rarity: Value(hit.rarity),
                jlptLevel: Value(hit.jlptLevel),
                source: const Value(CardSource.user),
              ),
            );
        var ordinal = 1;
        for (final s in hit.senses) {
          await db.into(db.cardSenses).insert(
                CardSensesCompanion.insert(
                  cardId: cardId,
                  ordinal: ordinal++,
                  pos: Value(s.pos),
                  gloss: s.gloss,
                  definition: Value(s.def),
                ),
              );
        }
        wasNew = true;
      }

      await addToWishlist(cardId, now: now);

      return JmdictPromotionResult(cardId: cardId, wasNew: wasNew);
    });
  }

  /// Daily-active streak. Returns the current count and bumps it when
  /// the user opens the app on a new calendar day. Idempotent within a
  /// day: calling repeatedly the same day returns the same number.
  ///
  /// Rules:
  /// * No anchor stored (first ever open) → start a streak of 1.
  /// * Anchor == today → no change.
  /// * Anchor was yesterday → +1.
  /// * Anchor was older than yesterday → reset to 1.
  Future<int> recordStreak({DateTime? now}) async {
    final today = (await _day(now)).key;
    final meta = await _readMetas(
      [MetaKeys.streakAnchorDate, MetaKeys.streakCount],
    );
    final anchorRaw = meta[MetaKeys.streakAnchorDate];
    final stored = int.tryParse(meta[MetaKeys.streakCount] ?? '') ?? 0;

    if (anchorRaw == today && stored >= 1) return stored;
    final continues = stored >= 1 &&
        anchorRaw != null &&
        DateTime.tryParse(anchorRaw) != null &&
        shiftDayKey(anchorRaw, 1) == today;
    final next = continues ? stored + 1 : 1;

    await db.transaction(() async {
      await writeMeta(MetaKeys.streakCount, '$next');
      await writeMeta(MetaKeys.streakAnchorDate, today);
    });
    return next;
  }

  /// Bumps `last_seen_ts`. If the wall clock is *before* the stored value,
  /// the user rolled their device clock backwards and we ignore the
  /// difference — the booster gate will still see today's stored date.
  Future<DateTime> _touchLastSeen(DateTime? now) async {
    final effective =
        _effectiveNow(now, await readMeta(MetaKeys.lastSeenTs));
    await _writeLastSeen(effective);
    return effective;
  }

  static DateTime _effectiveNow(DateTime? now, String? lastSeenRaw) {
    final actualNow = now ?? DateTime.now();
    final stored =
        lastSeenRaw == null ? null : DateTime.tryParse(lastSeenRaw)?.toLocal();
    return (stored != null && actualNow.isBefore(stored)) ? stored : actualNow;
  }

  Future<void> _writeLastSeen(DateTime effective) =>
      writeMeta(MetaKeys.lastSeenTs, effective.toIso8601String());

  // ---------- booster ----------

  /// Touches `last_seen_ts` and reads today's booster allowance, all
  /// meta in one query.
  Future<_BoosterGate> _boosterGate(DateTime? now) async {
    final meta = await _readMetas([
      MetaKeys.lastSeenTs,
      MetaKeys.resetHour,
      MetaKeys.boostersPerDay,
      MetaKeys.lastBoosterDate,
      MetaKeys.boostersClaimedToday,
    ]);
    final effective = _effectiveNow(now, meta[MetaKeys.lastSeenTs]);
    await _writeLastSeen(effective);
    final day = _LogicalDay(effective, _resetHour.parse(meta[_resetHour.key]));
    final claimed = meta[MetaKeys.lastBoosterDate] == day.key
        ? int.tryParse(meta[MetaKeys.boostersClaimedToday] ?? '') ?? 0
        : 0;
    return _BoosterGate(
      day,
      perDay: _boostersPerDay.parse(meta[_boostersPerDay.key]),
      claimed: claimed,
    );
  }

  /// How many fresh booster packs the user can still claim today —
  /// `boosters_per_day` minus the count already claimed in this logical
  /// day. Surfaced to the home / pack-intro screens so they can show
  /// "N × packSize new cards" instead of always saying packSize.
  Future<int> remainingBoostersToday({DateTime? now}) async =>
      (await _boosterGate(now)).remaining;

  /// Claims every pack the user is still entitled to today, returning
  /// one [BoosterClaim] per pack so the reveal UI can run an inline
  /// pack-tear animation between groups. Skips any trailing slot whose
  /// pool ran dry. Empty result means nothing left to claim today (or
  /// the dictionary has no unseen cards).
  ///
  /// Each card is drawn by [_DrawPool.draw]: a rarity from
  /// [kBoosterRarityWeights], then a uniform-random unseen card of that
  /// rarity, empty tiers falling back to the non-empty ones.
  Future<List<BoosterClaim>> claimAllAvailableBoosters({
    int packSize = kDefaultPackSize,
    DateTime? now,
  }) async {
    final gate = await _boosterGate(now);
    if (gate.remaining == 0) return const [];
    final pool = await _loadDrawPool();
    final packs = <List<int>>[];
    while (packs.length < gate.remaining) {
      final picked = pool.draw(packSize);
      packs.add(picked);
      if (picked.isEmpty) break;
    }
    final drawn = [for (final p in packs) ...p];
    await db.transaction(() async {
      if (drawn.isNotEmpty) await _mintOwned(drawn, gate.day.now);
      await writeMeta(MetaKeys.lastBoosterDate, gate.day.key);
      await writeMeta(
        MetaKeys.boostersClaimedToday,
        '${gate.claimed + packs.length}',
      );
    });
    final byId = {for (final c in await cardsByIds(drawn)) c.id: c};
    return [
      for (final p in packs)
        BoosterClaim(cards: [for (final id in p) byId[id]!]),
    ];
  }

  /// Puts freshly drawn cards into the collection, due now, and takes
  /// them off the wishlist.
  Future<void> _mintOwned(List<int> ids, DateTime now) async {
    await db.batch((b) {
      b.insertAll(db.userCards, [
        for (final id in ids)
          UserCardsCompanion.insert(
            cardId: Value(id),
            nextDue: now,
            obtainedAt: now,
          ),
      ]);
      b.deleteWhere(db.wishlist, (w) => w.cardId.isIn(ids));
    });
  }

  /// The unseen pool under the current draw filters.
  ///
  /// `booster_pack_filter` narrows the pool to a single themed pack
  /// before the JLPT split. Wishlisted ids survive that narrowing —
  /// same carve-out the JLPT filter gets, for the same reason: the
  /// user asked for those cards by name.
  Future<_DrawPool> _loadDrawPool() async {
    final meta = await _readMetas(
      [MetaKeys.jlptOnly, MetaKeys.boosterPackFilter],
    );
    final packOnly = switch (meta[MetaKeys.boosterPackFilter]) {
      null || '' => null,
      final p => p,
    };
    final rows = await db.customSelect(
      'SELECT c.id, c.rarity, c.jlpt_level IS NOT NULL AS jlpt, '
      'w.card_id IS NOT NULL AS wished FROM cards c '
      'LEFT JOIN user_cards u ON u.card_id = c.id '
      'LEFT JOIN wishlist w ON w.card_id = c.id '
      'WHERE u.card_id IS NULL '
      '${packOnly == null ? '' : 'AND (c.pack = ? OR w.card_id IS NOT NULL)'}',
      variables: [if (packOnly != null) Variable.withString(packOnly)],
      readsFrom: {db.cards, db.userCards, db.wishlist},
    ).get();
    final pool = _DrawPool(
      jlptOnly: meta[MetaKeys.jlptOnly] == '1',
      random: _random,
    );
    for (final r in rows) {
      pool.add(
        r.read<int>('id'),
        Rarity.values[r.read<int>('rarity')],
        jlpt: r.read<bool>('jlpt'),
        wished: r.read<bool>('wished'),
      );
    }
    return pool;
  }

  // ---------- daily deck ----------

  /// All cards due today, plus today's freshly-claimed ones if the booster
  /// hasn't been opened yet. The result is shuffled so new cards surface
  /// in random positions.
  ///
  /// "Due today" is bounded by the end of today's *logical* day (next
  /// `resetHour`), not by wall-clock `now`. Without this, a card whose
  /// `nextDue` is e.g. 02:00 tomorrow (still today logically when reset
  /// is 4am) would either appear too early or skip a day depending on
  /// when the user opens the app.
  Future<List<DailyDeckEntry>> assembleDailyDeck({DateTime? now}) async {
    final dayEnd = (await _day(await _touchLastSeen(now))).end;

    final due = await (db.select(db.userCards)
          ..where((u) =>
              u.nextDue.isSmallerThanValue(dayEnd) &
              u.suspended.equals(false)))
        .get();

    final ids = due.map((u) => u.cardId).toList();
    if (ids.isEmpty) return const [];

    final cards = await (db.select(db.cards)..where((c) => c.id.isIn(ids)))
        .get();
    final byId = {for (final c in cards) c.id: c};

    final entries = [
      for (final u in due)
        if (byId[u.cardId] != null)
          DailyDeckEntry(card: byId[u.cardId]!, userCard: u),
    ]..shuffle(_random);
    return entries;
  }

  Future<int> dueCountToday({DateTime? now}) async {
    final dayEnd = (await _day(now)).end;
    final count = db.userCards.cardId.count();
    final query = db.selectOnly(db.userCards)
      ..addColumns([count])
      ..where(db.userCards.nextDue.isSmallerThanValue(dayEnd) &
          db.userCards.suspended.equals(false));
    final row = await query.getSingle();
    return row.read(count) ?? 0;
  }

  // ---------- review ----------

  /// Records a single review answer: updates level/ease/interval/next_due
  /// per the scheduler, clears the `is_new` flag, appends a row to
  /// `review_log` (with [ReviewKind] and optional [durationMs]), and
  /// increments today's `daily_stats` bucket. Returns both the new
  /// scheduling state (so the UI can show feedback) and a
  /// [ReviewSnapshot] the caller can hand back to [undoReview] to roll
  /// the answer back.
  Future<({ReviewOutcome outcome, ReviewSnapshot snapshot})> applyReview({
    required int cardId,
    required bool correct,
    int? durationMs,
    DateTime? now,
  }) async {
    final meta = await _readMetas([
      MetaKeys.lastSeenTs,
      MetaKeys.resetHour,
      MetaKeys.reviewTimeCapSeconds,
    ]);
    final actualNow = _effectiveNow(now, meta[MetaKeys.lastSeenTs]);
    final capSeconds = _reviewTimeCap.parse(meta[_reviewTimeCap.key]);
    final row = await (db.select(db.userCards).join([
      innerJoin(db.cards, db.cards.id.equalsExp(db.userCards.cardId)),
    ])
          ..where(db.userCards.cardId.equals(cardId)))
        .getSingle();
    final current = row.readTable(db.userCards);
    final card = row.readTable(db.cards);

    final outcome = scheduleNext(
      level: current.level,
      ease: current.ease,
      intervalMinutes: current.intervalMinutes,
      correct: correct,
      now: actualNow,
    );
    // The "very first review of this card" signal — we trust
    // lastReviewed over is_new because the booster reveal flow can
    // clear is_new before the first real review happens.
    final isFirstReview = current.lastReviewed == null;
    final dayKey =
        logicalDayKey(actualNow, _resetHour.parse(meta[_resetHour.key]));
    final kind = classifyReview(
      prevIntervalMinutes: current.intervalMinutes,
      correct: correct,
    );
    // Clamp the recorded duration so a single "phone left on the table"
    // outlier doesn't drag the median time-stats. Setting is in
    // seconds; persisted column is ms.
    final cappedDurationMs = durationMs?.clamp(0, capSeconds * 1000);

    late int reviewLogId;
    await db.transaction(() async {
      await _writeLastSeen(actualNow);
      await (db.update(db.userCards)
            ..where((u) => u.cardId.equals(cardId)))
          .write(UserCardsCompanion(
        level: Value(outcome.level),
        ease: Value(outcome.ease),
        intervalMinutes: Value(outcome.intervalMinutes),
        lastReviewed: Value(actualNow),
        nextDue: Value(outcome.nextDue),
        isNew: const Value(false),
        failCount: correct
            ? Value(current.failCount)
            : Value(current.failCount + 1),
      ));
      reviewLogId =
          await db.into(db.reviewLog).insert(ReviewLogCompanion.insert(
                reviewedAt: actualNow,
                prevIntervalMinutes: current.intervalMinutes,
                correct: correct,
                rarity: card.rarity.index,
                kind: Value(kind),
                durationMs: Value(cappedDurationMs),
              ));
      await _bumpDailyStats(
        dayKey: dayKey,
        rarity: card.rarity,
        correct: correct,
        isFirstReview: isFirstReview,
      );
    });

    final snapshot = ReviewSnapshot(
      priorUserCard: current,
      reviewLogId: reviewLogId,
      dayKey: dayKey,
      rarity: card.rarity,
      correct: correct,
      isFirstReview: isFirstReview,
    );
    return (outcome: outcome, snapshot: snapshot);
  }

  /// Reverts a single review applied via [applyReview]. Restores the
  /// `user_cards` row (level / ease / interval / lastReviewed / nextDue
  /// / isNew / failCount) to its pre-review values, deletes the
  /// appended `review_log` row, and decrements the matching
  /// `daily_stats` counters. Idempotent within a single snapshot —
  /// applying it twice does nothing the second time because the log
  /// row no longer exists; daily_stats decrements are clamped at 0.
  Future<void> undoReview(ReviewSnapshot snapshot) async {
    final prior = snapshot.priorUserCard;
    await db.transaction(() async {
      await (db.update(db.userCards)
            ..where((u) => u.cardId.equals(prior.cardId)))
          .write(UserCardsCompanion(
        level: Value(prior.level),
        ease: Value(prior.ease),
        intervalMinutes: Value(prior.intervalMinutes),
        lastReviewed: Value(prior.lastReviewed),
        nextDue: Value(prior.nextDue),
        isNew: Value(prior.isNew),
        failCount: Value(prior.failCount),
      ));
      await (db.delete(db.reviewLog)
            ..where((l) => l.id.equals(snapshot.reviewLogId)))
          .go();
      final col = rarityColumn(snapshot.rarity);
      final correctDec = snapshot.correct ? 1 : 0;
      final newDec = snapshot.isFirstReview ? 1 : 0;
      // MAX(0, ...) is defensive: in normal flow the row was just
      // bumped so the counters are >= 1, but a stale snapshot replayed
      // after the user manually wiped stats shouldn't drive them
      // negative.
      await db.customStatement(
        '''
        UPDATE daily_stats SET
          ${col}_total = MAX(0, ${col}_total - 1),
          ${col}_correct = MAX(0, ${col}_correct - ?),
          new_cards = MAX(0, new_cards - ?)
        WHERE date = ?
        ''',
        [correctDec, newDec, snapshot.dayKey],
      );
    });
  }

  /// UPSERT one review into the daily wide row. The column prefix is
  /// derived from a closed enum, never user input — safe to interpolate
  /// into the SQL.
  Future<void> _bumpDailyStats({
    required String dayKey,
    required Rarity rarity,
    required bool correct,
    required bool isFirstReview,
  }) async {
    final col = rarityColumn(rarity);
    final correctInc = correct ? 1 : 0;
    final newInc = isFirstReview ? 1 : 0;
    await db.customStatement(
      '''
      INSERT INTO daily_stats (date, ${col}_total, ${col}_correct, new_cards)
      VALUES (?, 1, ?, ?)
      ON CONFLICT(date) DO UPDATE SET
        ${col}_total = ${col}_total + 1,
        ${col}_correct = ${col}_correct + ?,
        new_cards = new_cards + ?
      ''',
      [dayKey, correctInc, newInc, correctInc, newInc],
    );
  }

  /// All senses for a card, ordered by their dictionary ordinal.
  Future<List<CardSenseRow>> sensesForCard(int cardId) async {
    return (db.select(db.cardSenses)
          ..where((s) => s.cardId.equals(cardId))
          ..orderBy([(s) => OrderingTerm.asc(s.ordinal)]))
        .get();
  }

  /// Senses for each of [cardIds], ordered by ordinal; a card without
  /// senses maps to an empty list.
  Future<Map<int, List<CardSenseRow>>> sensesForCards(
    List<int> cardIds,
  ) async {
    final out = {for (final id in cardIds) id: <CardSenseRow>[]};
    if (cardIds.isEmpty) return out;
    final rows = await (db.select(db.cardSenses)
          ..where((s) => s.cardId.isIn(cardIds))
          ..orderBy([
            (s) => OrderingTerm.asc(s.cardId),
            (s) => OrderingTerm.asc(s.ordinal),
          ]))
        .get();
    for (final r in rows) {
      out[r.cardId]!.add(r);
    }
    return out;
  }

  // ---------- collection ----------

  /// Collection grid query. Defaults to "owned cards only"; pass
  /// [includeUnowned] to surface every card in existence — unowned
  /// ones come back with [CollectionEntry.userCard] null so the UI can
  /// render them as silhouettes (the in-app "Show missing" toggle).
  /// Pass [wishedOnly] to intersect with the wishlist (forces
  /// [includeUnowned] effectively, since wishlisted-but-unowned cards
  /// are the whole point of the bookmark). Filters stack: free-text
  /// [query] (kanji / kana / meaning, case-insensitive) AND a
  /// [rarities] set. Ordered by rarity desc then kanji asc so rarer
  /// cards surface first.
  Future<List<CollectionEntry>> ownedCards({
    String query = '',
    Set<Rarity> rarities = const {},
    bool includeUnowned = false,
    bool wishedOnly = false,
    bool suspendedOnly = false,
  }) async {
    // Wishlist mode always wants unowned + owned wishlisted cards.
    // Suspended mode forces an inner join so we never widen to unowned
    // cards (you can't suspend something you don't own).
    final pickUnowned = (includeUnowned || wishedOnly) && !suspendedOnly;
    final joins = <Join>[
      pickUnowned
          ? leftOuterJoin(
              db.userCards, db.userCards.cardId.equalsExp(db.cards.id))
          : innerJoin(
              db.userCards, db.userCards.cardId.equalsExp(db.cards.id)),
      if (wishedOnly)
        innerJoin(
          db.wishlist, db.wishlist.cardId.equalsExp(db.cards.id)),
    ];
    final select = db.select(db.cards).join(joins);
    if (suspendedOnly) {
      select.where(db.userCards.suspended.equals(true));
    }

    final trimmed = query.trim();
    if (trimmed.isNotEmpty) {
      final like = '%${trimmed.toLowerCase()}%';
      select.where(
        db.cards.kanji.lower().like(like) |
            db.cards.kana.lower().like(like) |
            db.cards.meaning.lower().like(like),
      );
    }
    if (rarities.isNotEmpty) {
      select.where(
        db.cards.rarity.isIn(rarities.map((r) => r.index)),
      );
    }

    select.orderBy([
      OrderingTerm.desc(db.cards.rarity),
      OrderingTerm.asc(db.cards.kanji),
    ]);

    final rows = await select.get();
    return rows
        .map((r) => CollectionEntry(
              card: r.readTable(db.cards),
              userCard: r.readTableOrNull(db.userCards),
            ))
        .toList();
  }

  /// Number of cards currently on the wishlist. Cheap read so the
  /// collection chip can render a live count badge.
  Future<int> wishedCount() async {
    final count = db.wishlist.cardId.count();
    final row = await (db.selectOnly(db.wishlist)..addColumns([count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Per-rarity owned / total counts for the collection header.
  Future<CollectionStats> collectionStats() async {
    final counts = await _ownedVsTotal(db.cards.rarity);
    const empty = (owned: 0, total: 0);
    return CollectionStats(
      ownedByRarity: {
        for (final r in Rarity.values) r: (counts[r.index] ?? empty).owned,
      },
      totalByRarity: {
        for (final r in Rarity.values) r: (counts[r.index] ?? empty).total,
      },
    );
  }

  /// Owned vs total cards grouped by [column], in one pass over the
  /// deck. Cards whose [column] is null are left out.
  Future<Map<T, ({int owned, int total})>> _ownedVsTotal<T extends Object>(
    GeneratedColumn<T> column,
  ) async {
    final total = db.cards.id.count();
    final owned = db.userCards.cardId.count();
    final rows = await (db.selectOnly(db.cards).join([
      leftOuterJoin(db.userCards, db.userCards.cardId.equalsExp(db.cards.id)),
    ])
          ..addColumns([column, total, owned])
          ..where(column.isNotNull())
          ..groupBy([column]))
        .get();
    return {
      for (final r in rows)
        r.read(column)!: (owned: r.read(owned) ?? 0, total: r.read(total) ?? 0),
    };
  }

  /// The [limit] most recently obtained cards, newest first.
  Future<List<CollectionEntry>> recentlyObtained({int limit = 10}) async {
    final rows = await (db.select(db.cards).join([
      innerJoin(db.userCards, db.userCards.cardId.equalsExp(db.cards.id)),
    ])
          ..orderBy([
            OrderingTerm.desc(db.userCards.obtainedAt),
            OrderingTerm.desc(db.cards.rarity),
            OrderingTerm.asc(db.cards.kanji),
          ])
          ..limit(limit))
        .get();
    return [
      for (final r in rows)
        CollectionEntry(
          card: r.readTable(db.cards),
          userCard: r.readTable(db.userCards),
        ),
    ];
  }

  /// A card with its review state, or null if there is no such card.
  /// [CollectionEntry.userCard] is null when the card isn't owned.
  Future<CollectionEntry?> cardWithState(int cardId) async {
    final row = await (db.select(db.cards).join([
      leftOuterJoin(
        db.userCards,
        db.userCards.cardId.equalsExp(db.cards.id),
      ),
    ])
          ..where(db.cards.id.equals(cardId)))
        .getSingleOrNull();
    if (row == null) return null;
    return CollectionEntry(
      card: row.readTable(db.cards),
      userCard: row.readTableOrNull(db.userCards),
    );
  }

  /// The cards with these ids, in the order given; unknown ids are
  /// skipped.
  Future<List<CardRow>> cardsByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final rows =
        await (db.select(db.cards)..where((c) => c.id.isIn(ids))).get();
    final byId = {for (final c in rows) c.id: c};
    return [for (final id in ids) ?byId[id]];
  }

  /// Clears the `is_new` flag for the given cards. Called from the
  /// booster-reveal screen once a card has been flipped, so the review
  /// flow doesn't re-show the new-card overlay later.
  Future<void> markCardsSeen(List<int> cardIds) async {
    if (cardIds.isEmpty) return;
    await (db.update(db.userCards)
          ..where((u) => u.cardId.isIn(cardIds)))
        .write(const UserCardsCompanion(isNew: Value(false)));
  }

  /// Sets the suspended flag on an owned card. Suspended cards stay in
  /// the collection and keep their scheduling state frozen, but are
  /// filtered out of every review-queue query.
  Future<void> setSuspended(int cardId, bool suspended) async {
    await (db.update(db.userCards)
          ..where((u) => u.cardId.equals(cardId)))
        .write(UserCardsCompanion(suspended: Value(suspended)));
  }

  /// Used by the booster reveal: marks every card in [suspendCardIds]
  /// as suspended and draws an equal number of replacements from the
  /// unseen pool — the booster sampler still applies, so rarity /
  /// wishlist / JLPT / pack filters all carry over. Replacements get a fresh
  /// `user_cards` row (`nextDue = now`, `is_new = true`) so they flow
  /// straight into the next review session instead of being shown again
  /// during the reveal. Done in one transaction so a crash mid-flow
  /// can't leave a card "suspended without a replacement."
  ///
  /// Returns the freshly-minted replacement card rows in draw order.
  /// May return fewer entries than requested if the unseen pool runs
  /// dry — the caller should treat the difference as a session shrink
  /// rather than a retry.
  Future<List<CardRow>> suspendAndReplace({
    required List<int> suspendCardIds,
    DateTime? now,
  }) async {
    if (suspendCardIds.isEmpty) return const [];
    return db.transaction(() async {
      await (db.update(db.userCards)
            ..where((u) => u.cardId.isIn(suspendCardIds)))
          .write(const UserCardsCompanion(suspended: Value(true)));

      final picked = (await _loadDrawPool()).draw(suspendCardIds.length);
      if (picked.isEmpty) return const <CardRow>[];
      await _mintOwned(picked, now ?? DateTime.now());
      // Draw order, so the caller can reason about pack boundaries.
      return cardsByIds(picked);
    });
  }

  /// All example sentences linked to a card (M:N via card_examples).
  Future<List<ExampleRow>> examplesForCard(int cardId) async {
    final query = db.select(db.examples).join([
      innerJoin(
        db.cardExamples,
        db.cardExamples.exampleId.equalsExp(db.examples.id),
      ),
    ])..where(db.cardExamples.cardId.equals(cardId));
    final rows = await query.get();
    return rows.map((r) => r.readTable(db.examples)).toList();
  }
}
