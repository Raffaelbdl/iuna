import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/jmdict_lookup.dart';
import 'package:iuna/db/repository.dart';

Future<int> _seedCard(AppDatabase db, String kanji, String kana, Rarity r) {
  return db.into(db.cards).insert(
        CardsCompanion.insert(
          kanji: kanji,
          kana: kana,
          meaning: '$kanji ($kana)',
          rarity: Value(r),
        ),
      );
}

extension on IunaRepository {
  /// Every pack still due today, flattened — with the default quota of
  /// one pack per day, exactly one pack.
  Future<BoosterClaim> claimToday({
    int packSize = kDefaultPackSize,
    DateTime? now,
  }) async =>
      BoosterClaim(cards: [
        for (final c in await claimAllAvailableBoosters(
          packSize: packSize,
          now: now,
        ))
          ...c.cards,
      ]);
}

void main() {
  late AppDatabase db;
  late IunaRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IunaRepository(db, random: Random(0));
  });

  tearDown(() async {
    await db.close();
  });

  test('booster claims up to N unseen cards and gates per day', () async {
    for (var i = 0; i < 15; i++) {
      await _seedCard(db, 'k$i', 'kana$i', Rarity.common);
    }

    expect(await repo.remainingBoostersToday() > 0, isTrue);

    final claim = await repo.claimToday();
    expect(claim.cards.length, kDefaultPackSize);

    expect(await repo.remainingBoostersToday() > 0, isFalse);

    final second = await repo.claimToday();
    expect(second.cards, isEmpty, reason: 'one pack per day');
  });

  test('booster yields fewer cards when the pool is exhausted', () async {
    for (var i = 0; i < 3; i++) {
      await _seedCard(db, 'k$i', 'kana$i', Rarity.common);
    }
    final claim = await repo.claimToday();
    expect(claim.cards.length, 3);
  });

  test('daily deck contains all due user_cards, shuffled', () async {
    for (var i = 0; i < kDefaultPackSize; i++) {
      await _seedCard(db, 'k$i', 'kana$i', Rarity.common);
    }
    await repo.claimToday();
    final deck = await repo.assembleDailyDeck();
    expect(deck.length, kDefaultPackSize);
    expect(deck.every((e) => e.isNew), isTrue);
  });

  test('boostersPerDay > 1 lets the user claim multiple fresh packs', () async {
    for (var i = 0; i < 35; i++) {
      await _seedCard(db, 'k$i', 'kana$i', Rarity.common);
    }
    await repo.setBoostersPerDay(3);
    final today = DateTime(2026, 4, 26, 12);

    final packs = await repo.claimAllAvailableBoosters(now: today);
    expect(packs, hasLength(3));
    final ids = [for (final p in packs) ...p.cards.map((c) => c.id)];
    expect(ids, hasLength(3 * kDefaultPackSize));
    expect(ids.toSet(), hasLength(ids.length),
        reason: 'each pack is fresh cards, not an earlier pack');
    expect(await repo.remainingBoostersToday(now: today) > 0, isFalse,
        reason: '3 packs claimed, daily quota exhausted');
  });

  test('booster respects the rarity weight curve', () async {
    // Seed enough of every rarity that no tier is exhausted by 200
    // draws, then verify the histogram tracks kBoosterRarityWeights.
    for (final r in Rarity.values) {
      for (var i = 0; i < 200; i++) {
        await _seedCard(db, '${r.index}-$i', 'k${r.index}-$i', r);
      }
    }
    final histogram = <Rarity, int>{for (final r in Rarity.values) r: 0};
    // Step the wall clock forward one day per iteration so each
    // claim is a fresh pack — the boosters_per_day quota caps at
    // kMaxBoostersPerDay (5), which would otherwise replay the
    // cumulative pack and balloon the count.
    for (var i = 0; i < 20; i++) {
      final day = DateTime(2026, 4, 26 + i, 9);
      final claim = await repo.claimToday(now: day);
      for (final card in claim.cards) {
        histogram[card.rarity] = histogram[card.rarity]! + 1;
      }
    }
    final total = histogram.values.fold<int>(0, (a, b) => a + b);
    expect(total, 20 * kDefaultPackSize);
    // Each tier should land within ±15 percentage points of its
    // expected weight — generous enough to stay deterministic with
    // Random(0) but tight enough to catch a broken sampler.
    for (final r in Rarity.values) {
      final actual = histogram[r]! / total;
      final expected = kBoosterRarityWeights[r]!;
      expect(
        (actual - expected).abs(),
        lessThan(0.15),
        reason: '$r drew $actual, expected ≈ $expected',
      );
    }
  });

  test('ownedCards wishedOnly returns wishlisted cards regardless of ownership',
      () async {
    final ownedWished = await _seedCard(db, 'a', 'a', Rarity.common);
    final unownedWished =
        await _seedCard(db, 'b', 'b', Rarity.superRare);
    final ownedNotWished =
        await _seedCard(db, 'c', 'c', Rarity.common);
    await _seedCard(db, 'd', 'd', Rarity.rare); // unowned, not wished
    for (final id in [ownedWished, ownedNotWished]) {
      await db.into(db.userCards).insert(UserCardsCompanion.insert(
            cardId: Value(id),
            nextDue: DateTime.now(),
            obtainedAt: DateTime.now(),
          ));
    }
    await repo.toggleWishlist(ownedWished);
    await repo.toggleWishlist(unownedWished);

    final wished = await repo.ownedCards(wishedOnly: true);
    final ids = wished.map((e) => e.card.id).toSet();
    expect(ids, {ownedWished, unownedWished});
    expect(await repo.wishedCount(), 2);
  });

  test('toggleWishlist round-trips and isWished reflects state',
      () async {
    final cardId = await _seedCard(db, '一瞥', 'いちべつ', Rarity.ur);
    expect(await repo.isWished(cardId), isFalse);
    expect(await repo.toggleWishlist(cardId), isTrue);
    expect(await repo.isWished(cardId), isTrue);
    expect(await repo.wishedCardIds(), [cardId]);
    expect(await repo.toggleWishlist(cardId), isFalse);
    expect(await repo.isWished(cardId), isFalse);
    expect(await repo.wishedCardIds(), <int>[]);
  });

  test('booster oversamples wishlisted unseen cards', () async {
    // 30 Common cards, exactly one of which is wishlisted. Drawn at
    // the natural 49% per-tier weight a specific Common card would
    // surface ~2% of the time. With kWishlistDrawBias = 0.3 the
    // wishlisted slot is hit on ~30% of draws, so the wishlisted
    // card should land in the very first pack with overwhelming
    // probability — we assert it's pulled within 3 packs (30 draws).
    int? wishedId;
    for (var i = 0; i < 30; i++) {
      final id = await _seedCard(db, 'k$i', 'kana$i', Rarity.common);
      if (i == 7) wishedId = id;
    }
    await repo.toggleWishlist(wishedId!);

    final pulled = <int>{};
    for (var d = 0; d < 3; d++) {
      final claim = await repo.claimToday(
        now: DateTime(2026, 4, 26 + d, 9),
      );
      pulled.addAll(claim.cards.map((c) => c.id));
      if (pulled.contains(wishedId)) break;
    }
    expect(pulled, contains(wishedId));
  });

  test('wishlisted card is removed from wishlist once it drops', () async {
    final a = await _seedCard(db, 'kA', 'kanaA', Rarity.common);
    final b = await _seedCard(db, 'kB', 'kanaB', Rarity.common);
    await repo.toggleWishlist(a);
    await repo.toggleWishlist(b);
    expect(await repo.wishedCardIds(), unorderedEquals([a, b]));

    final claim = await repo.claimToday(packSize: 1);
    final droppedId = claim.cards.single.id;

    expect(await repo.isWished(droppedId), isFalse,
        reason: 'dropped card should no longer be wishlisted');
    final remaining = await repo.wishedCardIds();
    expect(remaining, hasLength(1));
    expect(remaining, isNot(contains(droppedId)));
  });

  test('booster oversamples JLPT-tagged cards within a tier', () async {
    // Common-only deck split 50/50 between JLPT-tagged and non-tagged
    // cards. With kJlptDrawBias = 0.7 (vs uniform 0.5), JLPT picks
    // should land notably above half across many draws.
    for (var i = 0; i < 200; i++) {
      await db.into(db.cards).insert(CardsCompanion.insert(
            kanji: 'j$i',
            kana: 'jk$i',
            meaning: 'jlpt $i',
            rarity: const Value(Rarity.common),
            jlptLevel: Value(5 - (i % 5)),
          ));
      await db.into(db.cards).insert(CardsCompanion.insert(
            kanji: 'n$i',
            kana: 'nk$i',
            meaning: 'non-jlpt $i',
            rarity: const Value(Rarity.common),
          ));
    }

    var jlpt = 0;
    var total = 0;
    // Step the day so each iteration is a fresh pack; 10 days × 10
    // cards = 100 draws against a 400-card pool, no depletion bias.
    for (var d = 0; d < 10; d++) {
      final claim =
          await repo.claimToday(now: DateTime(2026, 4, 26 + d, 9));
      for (final c in claim.cards) {
        if (c.jlptLevel != null) jlpt++;
        total++;
      }
    }
    final ratio = jlpt / total;
    expect(ratio, greaterThan(0.6),
        reason: 'JLPT should over-sample beyond uniform 0.5 ($ratio)');
    expect(ratio, lessThan(0.85),
        reason: 'bias is partial — non-JLPT must still come through ($ratio)');
  });

  test('jlptOnly still surfaces a wishlisted non-JLPT card', () async {
    // Under jlptOnly the weighted branch is confined to JLPT-tagged
    // cards, but a card the user explicitly wishlisted must stay
    // reachable even without a JLPT tag — they asked for it by name.
    for (var i = 0; i < 40; i++) {
      await db.into(db.cards).insert(
            CardsCompanion.insert(
              kanji: 'j$i',
              kana: 'jk$i',
              meaning: 'jlpt $i',
              rarity: const Value(Rarity.common),
              jlptLevel: Value(5 - (i % 5)),
            ),
          );
    }
    int? wishedNonJlpt;
    for (var i = 0; i < 10; i++) {
      final id = await db.into(db.cards).insert(
            CardsCompanion.insert(
              kanji: 'n$i',
              kana: 'nk$i',
              meaning: 'non-jlpt $i',
              rarity: const Value(Rarity.common),
            ),
          );
      if (i == 3) wishedNonJlpt = id;
    }
    await repo.setJlptOnly(true);
    await repo.toggleWishlist(wishedNonJlpt!);

    final pulled = <int>{};
    for (var d = 0; d < 15; d++) {
      final claim =
          await repo.claimToday(now: DateTime(2026, 4, 26 + d, 9));
      for (final c in claim.cards) {
        pulled.add(c.id);
        if (c.jlptLevel == null) {
          expect(c.id, wishedNonJlpt,
              reason: 'jlptOnly must confine non-wishlisted draws to JLPT '
                  'cards; the only untagged card allowed is the wishlisted one');
        }
      }
      if (pulled.contains(wishedNonJlpt)) break;
    }
    expect(pulled, contains(wishedNonJlpt));
  });

  group('themed pack filter', () {
    Future<void> seedPacked(int count) async {
      for (var i = 0; i < count; i++) {
        await db.into(db.cards).insert(
              CardsCompanion.insert(
                kanji: 'p$i',
                kana: 'pk$i',
                meaning: 'pack $i',
                rarity: const Value(Rarity.common),
                pack: const Value('science'),
              ),
            );
      }
    }

    test('confines draws to the selected pack', () async {
      for (var i = 0; i < 40; i++) {
        await _seedCard(db, 'g$i', 'gk$i', Rarity.common);
      }
      await seedPacked(20);
      await repo.setBoosterPackFilter('science');

      final claim = await repo.claimToday();
      expect(claim.cards, hasLength(kDefaultPackSize));
      expect(claim.cards.every((c) => c.pack == 'science'), isTrue);
    });

    test('a wishlisted outsider still surfaces', () async {
      await seedPacked(30);
      final outsider = await _seedCard(db, '外', 'そと', Rarity.common);
      await repo.setBoosterPackFilter('science');
      await repo.toggleWishlist(outsider);

      final pulled = <int>{};
      for (var d = 0; d < 15; d++) {
        final claim =
            await repo.claimToday(now: DateTime(2026, 4, 26 + d, 9));
        for (final c in claim.cards) {
          pulled.add(c.id);
          if (c.pack != 'science') {
            expect(c.id, outsider,
                reason: 'the only non-pack card a filtered draw may return '
                    'is the wishlisted one');
          }
        }
        if (pulled.contains(outsider)) break;
      }
      expect(pulled, contains(outsider));
    });

    test('the two draw filters are mutually exclusive', () async {
      await repo.setJlptOnly(true);
      await repo.setBoosterPackFilter('science');
      expect(await repo.getJlptOnly(), isFalse);
      expect(await repo.getBoosterPackFilter(), 'science');

      await repo.setJlptOnly(true);
      expect(await repo.getBoosterPackFilter(), null);
    });

    test('clearing the filter restores the whole deck', () async {
      for (var i = 0; i < 40; i++) {
        await _seedCard(db, 'g$i', 'gk$i', Rarity.common);
      }
      await seedPacked(5);
      await repo.setBoosterPackFilter('science');
      await repo.setBoosterPackFilter(null);

      final claim = await repo.claimToday();
      expect(claim.cards.any((c) => c.pack == null), isTrue);
    });

    test('availablePacks + packProgress report owned vs total', () async {
      await seedPacked(4);
      await _seedCard(db, '外', 'そと', Rarity.common);
      expect(await repo.availablePacks(), ['science']);

      var progress = await repo.packProgress();
      expect(progress['science']?.owned, 0);
      expect(progress['science']?.total, 4);
      // No `packs` row (these cards were inserted directly, not via a
      // downloaded pack), so the label falls back to the raw name.
      expect(progress['science']?.label, 'science');

      await repo.setBoosterPackFilter('science');
      final claim = await repo.claimToday();
      progress = await repo.packProgress();
      expect(progress['science']?.owned, claim.cards.length);
      expect(progress['science']?.total, 4);
      expect(progress, hasLength(1),
          reason: 'untagged cards do not appear on the pack chart');
    });
  });

  test('booster falls back to non-JLPT when tier has no JLPT cards left',
      () async {
    // SR tier seeded with non-JLPT only; the JLPT subpool is empty so
    // the bias must not stall — every pick should still resolve.
    for (var i = 0; i < 30; i++) {
      await _seedCard(db, 's$i', 'sk$i', Rarity.superRare);
    }
    final claim = await repo.claimToday();
    expect(claim.cards.length, kDefaultPackSize);
    expect(claim.cards.every((c) => c.jlptLevel == null), isTrue);
  });

  test('booster falls back to other tiers when one is empty', () async {
    // Only Common cards exist; Rare/SR/SSR/UR are empty. Every pull
    // should still come back, all tagged Common — the fallback must
    // not stall on the empty tiers.
    for (var i = 0; i < 30; i++) {
      await _seedCard(db, 'c$i', 'k$i', Rarity.common);
    }
    final claim = await repo.claimToday();
    expect(claim.cards.length, kDefaultPackSize);
    expect(claim.cards.every((c) => c.rarity == Rarity.common), isTrue);
  });

  test('resetHour shifts the day boundary', () async {
    for (var i = 0; i < 6; i++) {
      await _seedCard(db, 'k$i', 'kana$i', Rarity.common);
    }
    await repo.setResetHour(4);

    final mondayLate = DateTime(2026, 4, 27, 23, 30);
    final tuesdayBeforeReset = DateTime(2026, 4, 28, 3, 0);
    final tuesdayAfterReset = DateTime(2026, 4, 28, 5, 0);

    await repo.claimToday(now: mondayLate);
    expect(
      await repo.remainingBoostersToday(now: tuesdayBeforeReset) > 0,
      isFalse,
      reason: 'before 04:00 the user is still on Monday\'s pack',
    );
    expect(
      await repo.remainingBoostersToday(now: tuesdayAfterReset) > 0,
      isTrue,
      reason: 'after 04:00 the day rolls over and a new pack is available',
    );
  });

  test('clock-rewind does not refresh the booster', () async {
    for (var i = 0; i < 5; i++) {
      await _seedCard(db, 'k$i', 'kana$i', Rarity.common);
    }
    final today = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: today);
    expect(await repo.remainingBoostersToday(now: today) > 0, isFalse);

    final yesterday = DateTime(2026, 4, 25, 12);
    expect(await repo.remainingBoostersToday(now: yesterday) > 0, isFalse,
        reason: 'rewinding the clock should not unlock another pack');
  });

  test('recordStreak honours resetHour', () async {
    await repo.setResetHour(4);
    final tuesdayLate = DateTime(2026, 4, 28, 23, 30);
    final wednesdayBeforeReset = DateTime(2026, 4, 29, 3, 0);
    final wednesdayAfterReset = DateTime(2026, 4, 29, 5, 0);

    expect(await repo.recordStreak(now: tuesdayLate), 1);
    expect(
      await repo.recordStreak(now: wednesdayBeforeReset),
      1,
      reason: 'before 04:00 we are still on Tuesday',
    );
    expect(
      await repo.recordStreak(now: wednesdayAfterReset),
      2,
      reason: 'after 04:00 we cross into Wednesday → +1',
    );
  });

  test('recordStreak: idempotent within a day, +1 next day, resets on gap',
      () async {
    final day1 = DateTime(2026, 4, 26, 9);
    expect(await repo.recordStreak(now: day1), 1);
    expect(await repo.recordStreak(now: day1.add(const Duration(hours: 6))),
        1, reason: 'same day → no change');

    final day2 = DateTime(2026, 4, 27, 8);
    expect(await repo.recordStreak(now: day2), 2,
        reason: 'consecutive day → +1');

    final day4 = DateTime(2026, 4, 29, 8);
    expect(await repo.recordStreak(now: day4), 1,
        reason: 'gap of more than one day → reset to 1');
  });

  test('shiftDayKey steps calendar days across DST and month ends', () {
    expect(shiftDayKey('2026-03-28', 1), '2026-03-29');
    expect(shiftDayKey('2026-03-30', -2), '2026-03-28');
    expect(shiftDayKey('2026-10-25', 1), '2026-10-26');
    expect(shiftDayKey('2026-12-31', 1), '2027-01-01');
    expect(shiftDayKey('2024-03-01', -1), '2024-02-29');
  });

  test('streaks and day series neither drop nor repeat a DST day', () async {
    // 2026-03-29 springs forward in most of Europe, and the reset hour
    // moves the day boundary off midnight.
    await repo.setResetHour(4);
    for (final d in [28, 29, 30]) {
      expect(await repo.recordStreak(now: DateTime(2026, 3, d, 12)), d - 27);
    }
    for (final d in [27, 28, 29, 30]) {
      await db.into(db.dailyStats).insert(
            DailyStatsCompanion.insert(date: '2026-03-$d', cTotal: const Value(1)),
          );
    }
    final now = DateTime(2026, 3, 30, 12);
    final streak = await repo.streakStats(recent: 5, now: now);
    expect(streak.current, 4);
    expect(streak.longest, 4);
    expect(streak.recent, [false, true, true, true, true]);
    expect(
      (await repo.dailyActivity(days: 5, now: now)).map((a) => a.date),
      ['2026-03-26', '2026-03-27', '2026-03-28', '2026-03-29', '2026-03-30'],
    );
  });

  test('sensesForCard returns senses ordered by ordinal', () async {
    final cardId = await _seedCard(db, 'k', 'k', Rarity.common);
    // Insert out of order to confirm the query sorts by ordinal.
    await db.into(db.cardSenses).insert(CardSensesCompanion.insert(
          cardId: cardId,
          ordinal: 2,
          gloss: 'second sense',
          pos: const Value('aux-v'),
        ));
    await db.into(db.cardSenses).insert(CardSensesCompanion.insert(
          cardId: cardId,
          ordinal: 1,
          gloss: 'first sense',
          pos: const Value('v5r,vt'),
        ));

    final senses = await repo.sensesForCard(cardId);
    expect(senses.map((s) => s.ordinal).toList(), [1, 2]);
    expect(senses.first.gloss, 'first sense');
    expect(senses.first.pos, 'v5r,vt');
  });

  test('ownedCards returns only cards with a user_card row', () async {
    final ownedId = await _seedCard(db, 'k1', 'kana1', Rarity.common);
    await _seedCard(db, 'k2', 'kana2', Rarity.common); // unowned
    await db.into(db.userCards).insert(UserCardsCompanion.insert(
          cardId: Value(ownedId),
          nextDue: DateTime.now(),
          obtainedAt: DateTime.now(),
        ));
    final entries = await repo.ownedCards();
    expect(entries.length, 1);
    expect(entries.first.card.kanji, 'k1');
  });

  test('ownedCards filters by query and rarity', () async {
    final cardA = await _seedCard(db, '猫', 'ねこ', Rarity.common);
    final cardB = await _seedCard(db, '魔法', 'まほう', Rarity.superRare);
    final cardC = await _seedCard(db, '結界', 'けっかい', Rarity.ssr);
    for (final id in [cardA, cardB, cardC]) {
      await db.into(db.userCards).insert(UserCardsCompanion.insert(
            cardId: Value(id),
            nextDue: DateTime.now(),
            obtainedAt: DateTime.now(),
          ));
    }

    final byKana = await repo.ownedCards(query: 'まほ');
    expect(byKana.map((e) => e.card.kanji).toList(), ['魔法']);

    final bySsr = await repo.ownedCards(rarities: const {Rarity.ssr});
    expect(bySsr.map((e) => e.card.kanji).toList(), ['結界']);

    final combined = await repo.ownedCards(
      query: 'け',
      rarities: const {Rarity.ssr, Rarity.common},
    );
    expect(combined.map((e) => e.card.kanji).toList(), ['結界']);
  });

  test('ownedCards includeUnowned: returns silhouettes for missing cards',
      () async {
    final ownedId = await _seedCard(db, '猫', 'ねこ', Rarity.common);
    await _seedCard(db, '魔法', 'まほう', Rarity.superRare); // unowned
    await db.into(db.userCards).insert(UserCardsCompanion.insert(
          cardId: Value(ownedId),
          nextDue: DateTime.now(),
          obtainedAt: DateTime.now(),
        ));

    final ownedOnly = await repo.ownedCards();
    expect(ownedOnly.map((e) => e.card.kanji).toList(), ['猫']);
    expect(ownedOnly.every((e) => e.isOwned), isTrue);

    final missing = await repo.ownedCards(includeUnowned: true);
    expect(missing.map((e) => e.card.kanji).toList(),
        containsAll(['猫', '魔法']));
    final unowned =
        missing.where((e) => e.card.kanji == '魔法').single;
    expect(unowned.isOwned, isFalse);
    expect(unowned.userCard, equals(null));
  });

  test('collectionStats counts owned vs total per rarity', () async {
    final commonOwned = await _seedCard(db, 'k1', 'kana1', Rarity.common);
    await _seedCard(db, 'k2', 'kana2', Rarity.common);
    final ssr = await _seedCard(db, 'k3', 'kana3', Rarity.ssr);
    await _seedCard(db, 'k4', 'kana4', Rarity.ur);
    for (final id in [commonOwned, ssr]) {
      await db.into(db.userCards).insert(UserCardsCompanion.insert(
            cardId: Value(id),
            nextDue: DateTime.now(),
            obtainedAt: DateTime.now(),
          ));
    }

    final stats = await repo.collectionStats();
    expect(stats.totalByRarity[Rarity.common], 2);
    expect(stats.totalByRarity[Rarity.ssr], 1);
    expect(stats.totalByRarity[Rarity.ur], 1);
    expect(stats.totalByRarity[Rarity.rare], 0);
    expect(stats.ownedByRarity[Rarity.common], 1);
    expect(stats.ownedByRarity[Rarity.ssr], 1);
    expect(stats.ownedByRarity[Rarity.ur], 0);
    expect(stats.owned, 2);
    expect(stats.total, 4);
  });

  test('markCardsSeen clears is_new for the given cards only', () async {
    for (var i = 0; i < 3; i++) {
      await _seedCard(db, 'k$i', 'kana$i', Rarity.common);
    }
    await repo.claimToday();

    final ids = (await db.select(db.cards).get()).map((c) => c.id).toList();
    expect(ids.length, 3);

    await repo.markCardsSeen([ids[0], ids[1]]);

    final byId = {
      for (final u in await db.select(db.userCards).get()) u.cardId: u,
    };
    expect(byId[ids[0]]!.isNew, isFalse);
    expect(byId[ids[1]]!.isNew, isFalse);
    expect(byId[ids[2]]!.isNew, isTrue,
        reason: 'unmentioned card should still be flagged new');
  });

  test('applyReview persists scheduler outcome and clears is_new', () async {
    await _seedCard(db, 'k', 'k', Rarity.common);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);

    final cardId = (await db.select(db.cards).getSingle()).id;

    final result =
        await repo.applyReview(cardId: cardId, correct: true, now: now);
    expect(result.outcome.level, 1);
    expect(result.outcome.intervalMinutes, 60 * 24);

    final stored = await (db.select(db.userCards)
          ..where((u) => u.cardId.equals(cardId)))
        .getSingle();
    expect(stored.level, 1);
    expect(stored.isNew, isFalse);
    expect(stored.nextDue, now.add(const Duration(days: 1)));
  });

  test('applyReview appends review_log and bumps daily_stats', () async {
    await _seedCard(db, 'k1', 'k1', Rarity.common);
    await _seedCard(db, 'k2', 'k2', Rarity.ur);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);

    final ids = (await db.select(db.cards).get()).map((c) => c.id).toList();
    await repo.applyReview(cardId: ids[0], correct: true, now: now);
    await repo.applyReview(cardId: ids[1], correct: false, now: now);

    final logs = await db.select(db.reviewLog).get();
    expect(logs.length, 2);
    expect(logs[0].correct, isTrue);
    expect(logs[0].rarity, Rarity.common.index);
    expect(logs[0].prevIntervalMinutes, 0);
    expect(logs[1].correct, isFalse);
    expect(logs[1].rarity, Rarity.ur.index);

    final stats = await db.select(db.dailyStats).getSingle();
    expect(stats.cTotal, 1);
    expect(stats.cCorrect, 1);
    expect(stats.urTotal, 1);
    expect(stats.urCorrect, 0);
    expect(stats.newCards, 2);
  });

  test('classifyReview maps (interval, correct) → ReviewKind', () {
    // Wrong is always relearn, regardless of interval.
    expect(
      classifyReview(prevIntervalMinutes: 0, correct: false),
      ReviewKind.relearn,
    );
    expect(
      classifyReview(
        prevIntervalMinutes: 60 * 24 * 30,
        correct: false,
      ),
      ReviewKind.relearn,
    );
    // Correct + still in learning steps (interval < 1d).
    expect(
      classifyReview(prevIntervalMinutes: 0, correct: true),
      ReviewKind.learn,
    );
    expect(
      classifyReview(
        prevIntervalMinutes: 60 * 12,
        correct: true,
      ),
      ReviewKind.learn,
    );
    // Correct + graduated (interval ≥ 1d).
    expect(
      classifyReview(
        prevIntervalMinutes: 60 * 24,
        correct: true,
      ),
      ReviewKind.review,
    );
    expect(
      classifyReview(
        prevIntervalMinutes: 60 * 24 * 30,
        correct: true,
      ),
      ReviewKind.review,
    );
  });

  test('review-time cap clamps recorded durationMs', () async {
    await _seedCard(db, 'k', 'k', Rarity.common);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);
    final cardId = (await db.select(db.cards).getSingle()).id;

    expect(await repo.getReviewTimeCapSeconds(),
        kDefaultReviewTimeCapSeconds);

    // 30s with 10s default cap → clamped to 10000.
    await repo.applyReview(
      cardId: cardId,
      correct: true,
      durationMs: 30 * 1000,
      now: now,
    );
    var log = await db.select(db.reviewLog).getSingle();
    expect(log.durationMs, 10 * 1000);

    // Below cap is preserved.
    await repo.setReviewTimeCapSeconds(20);
    await repo.applyReview(
      cardId: cardId,
      correct: true,
      durationMs: 7500,
      now: now.add(const Duration(days: 1, minutes: 1)),
    );
    final logs = await (db.select(db.reviewLog)
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    expect(logs[1].durationMs, 7500);

    // Way above the new 20s cap → clamped to 20000.
    await repo.applyReview(
      cardId: cardId,
      correct: false,
      durationMs: 5 * 60 * 1000,
      now: now.add(const Duration(days: 5)),
    );
    final all = await (db.select(db.reviewLog)
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    expect(all.last.durationMs, 20 * 1000);
  });

  test('setReviewTimeCapSeconds clamps to allowed range', () async {
    await repo.setReviewTimeCapSeconds(2);
    expect(await repo.getReviewTimeCapSeconds(),
        kMinReviewTimeCapSeconds);
    await repo.setReviewTimeCapSeconds(120);
    expect(await repo.getReviewTimeCapSeconds(),
        kMaxReviewTimeCapSeconds);
  });

  test('lastDriveBackup round-trips through meta', () async {
    expect(await repo.getLastDriveBackup(), equals(null));

    final ts = DateTime.utc(2026, 4, 28, 14, 32, 17);
    await repo.setLastDriveBackup(ts);
    final read = await repo.getLastDriveBackup();
    expect(read?.toUtc(), ts);

    // Overwrite preserves the latest.
    final newer = DateTime.utc(2026, 4, 29, 9);
    await repo.setLastDriveBackup(newer);
    expect((await repo.getLastDriveBackup())?.toUtc(), newer);
  });

  test('applyReview persists kind + duration_ms', () async {
    await _seedCard(db, 'k', 'k', Rarity.common);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);
    final cardId = (await db.select(db.cards).getSingle()).id;

    // First correct review: prev_interval=0 → learn, with duration.
    await repo.applyReview(
      cardId: cardId,
      correct: true,
      durationMs: 4200,
      now: now,
    );
    var logs = await db.select(db.reviewLog).get();
    expect(logs.single.kind, ReviewKind.learn);
    expect(logs.single.durationMs, 4200);

    // Second review next day: prev_interval=1d → review, no duration.
    await repo.applyReview(
      cardId: cardId,
      correct: true,
      now: now.add(const Duration(days: 1, minutes: 1)),
    );
    logs = await (db.select(db.reviewLog)
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    expect(logs[1].kind, ReviewKind.review);
    expect(logs[1].durationMs, equals(null));

    // Wrong answer: → relearn.
    await repo.applyReview(
      cardId: cardId,
      correct: false,
      durationMs: 9000,
      now: now.add(const Duration(days: 4)),
    );
    logs = await (db.select(db.reviewLog)
          ..orderBy([(l) => OrderingTerm.asc(l.id)]))
        .get();
    expect(logs[2].kind, ReviewKind.relearn);
    expect(logs[2].durationMs, 9000);
  });

  test('applyReview increments fail_count only on wrong answers', () async {
    await _seedCard(db, 'k', 'k', Rarity.common);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);
    final cardId = (await db.select(db.cards).getSingle()).id;

    await repo.applyReview(cardId: cardId, correct: false, now: now);
    var stored = await (db.select(db.userCards)
          ..where((u) => u.cardId.equals(cardId)))
        .getSingle();
    expect(stored.failCount, 1);

    await repo.applyReview(
      cardId: cardId,
      correct: true,
      now: now.add(const Duration(minutes: 10)),
    );
    stored = await (db.select(db.userCards)
          ..where((u) => u.cardId.equals(cardId)))
        .getSingle();
    expect(stored.failCount, 1, reason: 'correct answer leaves fail_count alone');

    await repo.applyReview(
      cardId: cardId,
      correct: false,
      now: now.add(const Duration(hours: 1)),
    );
    stored = await (db.select(db.userCards)
          ..where((u) => u.cardId.equals(cardId)))
        .getSingle();
    expect(stored.failCount, 2);
  });

  test('daily_stats counts new_cards on first review only', () async {
    await _seedCard(db, 'k', 'k', Rarity.common);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);
    final cardId = (await db.select(db.cards).getSingle()).id;

    await repo.applyReview(cardId: cardId, correct: true, now: now);
    await repo.applyReview(
      cardId: cardId,
      correct: true,
      now: now.add(const Duration(days: 1, minutes: 1)),
    );

    final stats = await db.select(db.dailyStats).get();
    expect(stats.length, 2);
    final byDate = {for (final s in stats) s.date: s};
    expect(byDate['2026-04-26']!.newCards, 1);
    expect(byDate['2026-04-27']!.newCards, 0,
        reason: 'second review does not count as new');
    expect(byDate['2026-04-26']!.cTotal, 1);
    expect(byDate['2026-04-27']!.cTotal, 1);
  });

  test('dailyActivity fills missing days with zero-rows', () async {
    await _seedCard(db, 'k', 'k', Rarity.common);
    final reviewDay = DateTime(2026, 4, 25, 12);
    await repo.claimToday(now: reviewDay);
    final cardId = (await db.select(db.cards).getSingle()).id;
    await repo.applyReview(cardId: cardId, correct: true, now: reviewDay);

    final later = DateTime(2026, 4, 27, 12);
    final activity = await repo.dailyActivity(days: 5, now: later);
    expect(activity.length, 5);
    expect(activity.last.date, '2026-04-27');
    final reviewedRow =
        activity.firstWhere((d) => d.date == '2026-04-25');
    expect(reviewedRow.total, 1);
    expect(reviewedRow.correct, 1);
    final emptyRow = activity.firstWhere((d) => d.date == '2026-04-26');
    expect(emptyRow.total, 0);
    expect(emptyRow.newCards, 0);
  });

  test('retentionCurve buckets reviews by prev interval', () async {
    await _seedCard(db, 'k1', 'k1', Rarity.common);
    await _seedCard(db, 'k2', 'k2', Rarity.common);
    final ids = (await db.select(db.cards).get()).map((c) => c.id).toList();
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);

    // First review of card 0: interval 0 → '<1d' bin.
    await repo.applyReview(cardId: ids[0], correct: false, now: now);
    // Second review of card 0 a week later: interval was 5min after the
    // miss → still '<1d'.
    await repo.applyReview(
      cardId: ids[0],
      correct: true,
      now: now.add(const Duration(days: 7)),
    );
    // First review of card 1: '<1d'.
    await repo.applyReview(cardId: ids[1], correct: true, now: now);
    // Manually bump card 1's interval to 21 days to land in '2-4w'
    // (the bucket is [14d, 30d), so 30 exactly would tip into 1-3mo).
    await db.customStatement(
      'UPDATE user_cards SET interval_minutes = ? WHERE card_id = ?',
      [60 * 24 * 21, ids[1]],
    );
    await repo.applyReview(
      cardId: ids[1],
      correct: true,
      now: now.add(const Duration(days: 21)),
    );

    final bins = await repo.retentionCurve();
    final byLabel = {for (final b in bins) b.label: b};
    expect(byLabel['<1d']!.total, 3,
        reason: 'two first-reviews + one short-interval re-test');
    expect(byLabel['<1d']!.correct, 2);
    expect(byLabel['2-4w']!.total, 1);
    expect(byLabel['2-4w']!.correct, 1);
  });

  test('retentionCurve windowDays clips to recent reviews', () async {
    await _seedCard(db, 'k', 'k', Rarity.common);
    final cardId = (await db.select(db.cards).getSingle()).id;
    await repo.claimToday(now: DateTime(2026, 1, 1));

    // Old review (well outside the window).
    await repo.applyReview(
      cardId: cardId,
      correct: false,
      now: DateTime(2026, 1, 1, 12),
    );
    // Recent review.
    await repo.applyReview(
      cardId: cardId,
      correct: true,
      now: DateTime(2026, 4, 26, 12),
    );

    final all = await repo.retentionCurve(now: DateTime(2026, 4, 27));
    expect(all.fold<int>(0, (s, b) => s + b.total), 2);

    final recent = await repo.retentionCurve(
      windowDays: 30,
      now: DateTime(2026, 4, 27),
    );
    expect(recent.fold<int>(0, (s, b) => s + b.total), 1,
        reason: 'older review is outside the 30-day window');
  });

  test('maturityHistogram skips interval-0 cards', () async {
    final c1 = await _seedCard(db, 'k1', 'k1', Rarity.common);
    final c2 = await _seedCard(db, 'k2', 'k2', Rarity.rare);
    final c3 = await _seedCard(db, 'k3', 'k3', Rarity.ur);
    final now = DateTime(2026, 4, 26, 12);
    // c1: never reviewed → interval 0, dropped.
    await db.into(db.userCards).insert(UserCardsCompanion.insert(
          cardId: Value(c1),
          nextDue: now,
          obtainedAt: now,
        ));
    // c2: 12-hour interval → '<1d'.
    await db.into(db.userCards).insert(UserCardsCompanion.insert(
          cardId: Value(c2),
          intervalMinutes: const Value(60 * 12),
          nextDue: now,
          obtainedAt: now,
        ));
    // c3: 60-day interval → '1-3mo'.
    await db.into(db.userCards).insert(UserCardsCompanion.insert(
          cardId: Value(c3),
          intervalMinutes: const Value(60 * 24 * 60),
          nextDue: now,
          obtainedAt: now,
        ));

    final hist = await repo.maturityHistogram();
    final byLabel = {for (final b in hist) b.label: b};
    expect(byLabel['<1d']!.count, 1);
    expect(byLabel['1-3mo']!.count, 1);
    expect(hist.fold<int>(0, (s, b) => s + b.count), 2);
  });

  test('dueForecast groups cards by next_due day, starting tomorrow', () async {
    final c1 = await _seedCard(db, 'k1', 'k1', Rarity.common);
    final c2 = await _seedCard(db, 'k2', 'k2', Rarity.common);
    final c3 = await _seedCard(db, 'k3', 'k3', Rarity.common);
    final now = DateTime(2026, 4, 26, 12);
    final overdue = now.subtract(const Duration(hours: 1));
    final tomorrow = DateTime(2026, 4, 27, 9);
    final dayAfter = DateTime(2026, 4, 28, 9);

    await db.into(db.userCards).insert(UserCardsCompanion.insert(
          cardId: Value(c1),
          nextDue: overdue,
          obtainedAt: now,
        ));
    await db.into(db.userCards).insert(UserCardsCompanion.insert(
          cardId: Value(c2),
          nextDue: tomorrow,
          obtainedAt: now,
        ));
    await db.into(db.userCards).insert(UserCardsCompanion.insert(
          cardId: Value(c3),
          nextDue: dayAfter,
          obtainedAt: now,
        ));

    final forecast = await repo.dueForecast(days: 3, now: now);
    expect(forecast.length, 3);
    expect(forecast[0].date, '2026-04-27');
    expect(forecast[0].due, 1);
    expect(forecast[1].date, '2026-04-28');
    expect(forecast[1].due, 1);
    expect(forecast[2].due, 0);
    // Today's overdue card must NOT show up here — that's dueCountToday.
    expect(forecast.map((f) => f.due).fold<int>(0, (a, b) => a + b), 2);
  });

  test('leeches returns top-N by fail_count, omitting zero', () async {
    final c1 = await _seedCard(db, 'k1', 'k1', Rarity.common);
    final c2 = await _seedCard(db, 'k2', 'k2', Rarity.common);
    final c3 = await _seedCard(db, 'k3', 'k3', Rarity.common);
    final now = DateTime(2026, 4, 26, 12);
    for (final id in [c1, c2, c3]) {
      await db.into(db.userCards).insert(UserCardsCompanion.insert(
            cardId: Value(id),
            nextDue: now,
            obtainedAt: now,
          ));
    }
    await db.customStatement(
        'UPDATE user_cards SET fail_count = ? WHERE card_id = ?', [5, c1]);
    await db.customStatement(
        'UPDATE user_cards SET fail_count = ? WHERE card_id = ?', [2, c2]);

    final leeches = await repo.leeches();
    expect(leeches.length, 2,
        reason: 'card with zero failures is excluded');
    expect(leeches[0].card.id, c1);
    expect(leeches[0].failCount, 5);
    expect(leeches[1].card.id, c2);
  });

  test('reviewBreakdown counts reviews and learned cards', () async {
    await _seedCard(db, 'k1', 'k1', Rarity.common);
    await _seedCard(db, 'k2', 'k2', Rarity.common);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);
    final ids = (await db.select(db.cards).get()).map((c) => c.id).toList();

    await repo.applyReview(cardId: ids[0], correct: true, now: now);
    await repo.applyReview(cardId: ids[0], correct: false, now: now);
    await repo.applyReview(cardId: ids[1], correct: true, now: now);

    final t = await repo.reviewBreakdown();
    expect(t.reviews, 3);
    expect(t.learned, 2);
  });

  test('undoReview restores user_cards, drops review_log, decrements stats',
      () async {
    await _seedCard(db, 'k', 'k', Rarity.common);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);
    final cardId = (await db.select(db.cards).getSingle()).id;

    final priorRow = await (db.select(db.userCards)
          ..where((u) => u.cardId.equals(cardId)))
        .getSingle();

    final result =
        await repo.applyReview(cardId: cardId, correct: true, now: now);
    expect(await db.select(db.reviewLog).get(), hasLength(1));
    final stats = await db.select(db.dailyStats).getSingle();
    expect(stats.cTotal, 1);
    expect(stats.cCorrect, 1);
    expect(stats.newCards, 1);

    await repo.undoReview(result.snapshot);

    final restored = await (db.select(db.userCards)
          ..where((u) => u.cardId.equals(cardId)))
        .getSingle();
    expect(restored.level, priorRow.level);
    expect(restored.ease, priorRow.ease);
    expect(restored.intervalMinutes, priorRow.intervalMinutes);
    expect(restored.lastReviewed, priorRow.lastReviewed);
    expect(restored.nextDue, priorRow.nextDue);
    expect(restored.isNew, priorRow.isNew);
    expect(restored.failCount, priorRow.failCount);
    expect(await db.select(db.reviewLog).get(), isEmpty);
    final after = await db.select(db.dailyStats).getSingle();
    expect(after.cTotal, 0);
    expect(after.cCorrect, 0);
    expect(after.newCards, 0);
  });

  test('undoReview rolls back wrong-answer fail_count bump', () async {
    await _seedCard(db, 'k', 'k', Rarity.common);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);
    final cardId = (await db.select(db.cards).getSingle()).id;

    final result =
        await repo.applyReview(cardId: cardId, correct: false, now: now);
    final bumped = await (db.select(db.userCards)
          ..where((u) => u.cardId.equals(cardId)))
        .getSingle();
    expect(bumped.failCount, 1);

    await repo.undoReview(result.snapshot);

    final restored = await (db.select(db.userCards)
          ..where((u) => u.cardId.equals(cardId)))
        .getSingle();
    expect(restored.failCount, 0);
  });

  test('todayStats sums correct + total across all rarities', () async {
    await _seedCard(db, 'k1', 'k1', Rarity.common);
    await _seedCard(db, 'k2', 'k2', Rarity.ur);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);
    final ids = (await db.select(db.cards).get()).map((c) => c.id).toList();

    expect((await repo.todayStats(now: now)).total, 0);

    await repo.applyReview(cardId: ids[0], correct: true, now: now);
    await repo.applyReview(cardId: ids[1], correct: false, now: now);

    final stats = await repo.todayStats(now: now);
    expect(stats.total, 2);
    expect(stats.correct, 1);

    // Yesterday's row stays out of the count.
    final yesterday = DateTime(2026, 4, 25, 12);
    expect((await repo.todayStats(now: yesterday)).total, 0);
  });

  test('remainingBoostersToday tracks consumed claims', () async {
    for (var i = 0; i < 35; i++) {
      await _seedCard(db, 'k$i', 'kana$i', Rarity.common);
    }
    await repo.setBoostersPerDay(3);
    final today = DateTime(2026, 4, 26, 12);

    expect(await repo.remainingBoostersToday(now: today), 3);

    await repo.claimToday(now: today);
    expect(await repo.remainingBoostersToday(now: today), 0);

    await repo.setBoostersPerDay(5);
    expect(await repo.remainingBoostersToday(now: today), 2,
        reason: 'the three claimed packs still count against today');
  });

  test('claimAllAvailableBoosters drains the daily quota in one call',
      () async {
    for (var i = 0; i < 35; i++) {
      await _seedCard(db, 'k$i', 'kana$i', Rarity.common);
    }
    await repo.setBoostersPerDay(3);
    final today = DateTime(2026, 4, 26, 12);

    final claims = await repo.claimAllAvailableBoosters(now: today);
    expect(claims, hasLength(3));
    expect(claims.every((c) => c.cards.length == kDefaultPackSize), isTrue);
    expect(await repo.remainingBoostersToday(now: today), 0);

    final empty = await repo.claimAllAvailableBoosters(now: today);
    expect(empty, isEmpty);
  });

  test('undoReview only rolls back the targeted review', () async {
    await _seedCard(db, 'k1', 'k1', Rarity.common);
    await _seedCard(db, 'k2', 'k2', Rarity.ur);
    final now = DateTime(2026, 4, 26, 12);
    await repo.claimToday(now: now);
    final ids = (await db.select(db.cards).get()).map((c) => c.id).toList();

    final first =
        await repo.applyReview(cardId: ids[0], correct: true, now: now);
    await repo.applyReview(cardId: ids[1], correct: true, now: now);

    await repo.undoReview(first.snapshot);

    final logs = await db.select(db.reviewLog).get();
    expect(logs, hasLength(1),
        reason: 'second review_log row stays put');
    expect(logs.single.rarity, Rarity.ur.index);

    final stats = await db.select(db.dailyStats).getSingle();
    expect(stats.cTotal, 0);
    expect(stats.cCorrect, 0);
    expect(stats.urTotal, 1);
    expect(stats.urCorrect, 1);
    expect(stats.newCards, 1);
  });

  group('promoteFromJmdict', () {
    JmdictHit makeHit({
      String kanji = '早合点',
      String kana = 'はやがてん',
      Rarity rarity = Rarity.ssr,
      int? jlptLevel,
      int? freqRank = 12000,
      List<JmdictSense>? senses,
    }) {
      return JmdictHit(
        kanji: kanji,
        kana: kana,
        senses: senses ??
            const [
              JmdictSense(
                pos: 'n,vs',
                gloss: 'jumping to a hasty conclusion',
                def: '',
              ),
              JmdictSense(
                pos: 'n,vs',
                gloss: 'misunderstanding, jumping to conclusions',
                def: '',
              ),
            ],
        rarity: rarity,
        jlptLevel: jlptLevel,
        freqRank: freqRank,
      );
    }

    test('inserts a new card with senses + wishlists it', () async {
      final hit = makeHit();
      final result = await repo.promoteFromJmdict(hit);

      expect(result.wasNew, isTrue);

      final card = await (db.select(db.cards)
            ..where((c) => c.id.equals(result.cardId)))
          .getSingle();
      expect(card.kanji, '早合点');
      expect(card.kana, 'はやがてん');
      expect(card.source, CardSource.user);
      expect(card.rarity, Rarity.ssr);
      expect(card.meaning, 'jumping to a hasty conclusion',
          reason: 'meaning is the first sense headline');

      final senses = await (db.select(db.cardSenses)
            ..where((s) => s.cardId.equals(result.cardId))
            ..orderBy([(s) => OrderingTerm.asc(s.ordinal)]))
          .get();
      expect(senses.map((s) => s.ordinal), [1, 2]);
      expect(senses.first.gloss, 'jumping to a hasty conclusion');
      expect(senses[1].gloss, 'misunderstanding, jumping to conclusions');

      expect(await repo.isWished(result.cardId), isTrue);
    });

    test('returns existing card id without rewriting senses', () async {
      final seedId = await db.into(db.cards).insert(
            CardsCompanion.insert(
              kanji: '食べる',
              kana: 'たべる',
              meaning: 'to eat',
              rarity: const Value(Rarity.common),
              source: const Value(CardSource.seed),
            ),
          );
      await db.into(db.cardSenses).insert(
            CardSensesCompanion.insert(
              cardId: seedId,
              ordinal: 1,
              gloss: 'to eat',
            ),
          );

      final result = await repo.promoteFromJmdict(makeHit(
        kanji: '食べる',
        kana: 'たべる',
        senses: const [
          JmdictSense(pos: 'v1', gloss: 'something else', def: ''),
        ],
      ));

      expect(result.cardId, seedId);
      expect(result.wasNew, isFalse);

      final card =
          await (db.select(db.cards)..where((c) => c.id.equals(seedId)))
              .getSingle();
      expect(card.source, CardSource.seed,
          reason: 'existing seed row not modified');
      expect(card.meaning, 'to eat',
          reason: 'meaning preserved on collision');

      final senses = await (db.select(db.cardSenses)
            ..where((s) => s.cardId.equals(seedId)))
          .get();
      expect(senses.length, 1);
      expect(senses.single.gloss, 'to eat',
          reason: 'JMdict glosses must not overwrite seed senses');

      expect(await repo.isWished(seedId), isTrue,
          reason: 'wishlist still gets the entry on collision');
    });

    test('repeated promotion is idempotent on the wishlist', () async {
      final hit = makeHit();
      final first = await repo.promoteFromJmdict(hit);
      final second = await repo.promoteFromJmdict(hit);

      expect(second.cardId, first.cardId);
      expect(second.wasNew, isFalse);

      final cards = await db.select(db.cards).get();
      expect(cards.length, 1);

      final wishlistRows = await db.select(db.wishlist).get();
      expect(wishlistRows.length, 1);
    });
  });

  group('lookupByHeadword', () {
    test('notFound when (kanji, kana) has no row', () async {
      final lookup = await repo.lookupByHeadword('foo', 'bar');
      expect(lookup.status, CardLookupStatus.notFound);
      expect(lookup.cardId, null);
    });

    test('available when card exists, not owned, not wishlisted', () async {
      final id = await _seedCard(db, '行く', 'いく', Rarity.common);
      final lookup = await repo.lookupByHeadword('行く', 'いく');
      expect(lookup.status, CardLookupStatus.available);
      expect(lookup.cardId, id);
    });

    test('wishlisted when card is on wishlist but not owned', () async {
      final id = await _seedCard(db, '行く', 'いく', Rarity.common);
      await repo.toggleWishlist(id);
      final lookup = await repo.lookupByHeadword('行く', 'いく');
      expect(lookup.status, CardLookupStatus.wishlisted);
      expect(lookup.cardId, id);
    });

    test('owned takes precedence even when also wishlisted', () async {
      final id = await _seedCard(db, '行く', 'いく', Rarity.common);
      await repo.toggleWishlist(id);
      final now = DateTime(2026, 4, 30);
      await db.into(db.userCards).insert(
            UserCardsCompanion.insert(
              cardId: Value(id),
              nextDue: now,
              obtainedAt: now,
            ),
          );

      final lookup = await repo.lookupByHeadword('行く', 'いく');
      expect(lookup.status, CardLookupStatus.owned);
      expect(lookup.cardId, id);
    });
  });

  group('SQL aggregates match a recount over the raw rows', () {
    const boundaries = [
      0, 1, 1439, 1440, 4319, 4320, 10079, 10080, 20159, 20160, 43199,
      43200, 129599, 129600, 259199, 259200, 1 << 30, (1 << 30) + 7,
    ];

    setUp(() async {
      final rng = Random(42);
      final base = DateTime.utc(2025, 1, 1);
      await db.batch((b) {
        b.insertAll(db.reviewLog, [
          for (var i = 0; i < 600; i++)
            ReviewLogCompanion.insert(
              reviewedAt:
                  base.add(Duration(minutes: rng.nextInt(60 * 24 * 600))),
              prevIntervalMinutes: i < boundaries.length
                  ? boundaries[i]
                  : rng.nextInt(60 * 24 * 400),
              correct: rng.nextBool(),
              rarity: rng.nextInt(Rarity.values.length),
              kind: Value(ReviewKind.values[rng.nextInt(3)]),
            ),
        ]);
      });
    });

    int bucketOf(int minutes) {
      for (final (i, (_, lo, hi)) in kIntervalBuckets.indexed) {
        if (minutes >= lo && minutes < hi) return i;
      }
      return kIntervalBuckets.length - 1;
    }

    ({int total, int correct}) count(Iterable<ReviewLogRow> rows) => (
          total: rows.length,
          correct: rows.where((r) => r.correct).length,
        );

    test('hour of day', () async {
      final rows = await db.select(db.reviewLog).get();
      final expected = List<int>.filled(24, 0);
      for (final r in rows) {
        expected[r.reviewedAt.toLocal().hour]++;
      }
      expect(await repo.hourOfDayHistogram(), expected);
    });

    test('retention curve, all-time and windowed', () async {
      final rows = await db.select(db.reviewLog).get();
      final now = DateTime.utc(2026, 6, 1);
      final cutoff = now.subtract(const Duration(days: 90));
      for (final (windowDays, keep) in [
        (null, (ReviewLogRow r) => true),
        (90, (ReviewLogRow r) => !r.reviewedAt.isBefore(cutoff)),
      ]) {
        final bins =
            await repo.retentionCurve(windowDays: windowDays, now: now);
        for (final (i, bin) in bins.indexed) {
          final inBin = rows.where(
            (r) => keep(r) && bucketOf(r.prevIntervalMinutes) == i,
          );
          expect((total: bin.total, correct: bin.correct), count(inBin),
              reason: '${bin.label} window=$windowDays');
        }
      }
    });

    test('pass-rate breakdowns and lifetime totals', () async {
      final rows = await db.select(db.reviewLog).get();
      final b = await repo.reviewBreakdown();
      expect(
        b.trueRetention,
        count(rows.where((r) => r.prevIntervalMinutes >= 60 * 24)),
      );
      expect(b.byKind, {
        for (final k in ReviewKind.values)
          k: count(rows.where((r) => r.kind == k)),
      });
      expect(b.byRarity, {
        for (final r in Rarity.values)
          r: count(rows.where((row) => row.rarity == r.index)),
      });
      expect(b.reviews, rows.length);
    });

    test('maturity histogram', () async {
      final ids = [
        for (var i = 0; i < boundaries.length; i++)
          await _seedCard(db, 'm$i', 'm$i', Rarity.common),
      ];
      final now = DateTime(2026, 4, 26);
      await db.batch((b) {
        b.insertAll(db.userCards, [
          for (final (i, id) in ids.indexed)
            UserCardsCompanion.insert(
              cardId: Value(id),
              intervalMinutes: Value(boundaries[i]),
              nextDue: now,
              obtainedAt: now,
            ),
        ]);
      });
      final expected = List<int>.filled(kIntervalBuckets.length, 0);
      for (final m in boundaries.where((m) => m > 0)) {
        expected[bucketOf(m)]++;
      }
      final hist = await repo.maturityHistogram();
      expect([for (final b in hist) b.count], expected);
    });
  });

  test('recentlyObtained, cardWithState, cardsByIds, sensesForCards',
      () async {
    final a = await _seedCard(db, 'a', 'a', Rarity.common);
    final b = await _seedCard(db, 'b', 'b', Rarity.ur);
    final c = await _seedCard(db, 'c', 'c', Rarity.rare);
    final t0 = DateTime(2026, 4, 1);
    for (final (id, days) in [(a, 0), (b, 2), (c, 1)]) {
      await db.into(db.userCards).insert(UserCardsCompanion.insert(
            cardId: Value(id),
            nextDue: t0,
            obtainedAt: t0.add(Duration(days: days)),
          ));
    }
    final unowned = await _seedCard(db, 'd', 'd', Rarity.common);
    for (final ordinal in [2, 1]) {
      await db.into(db.cardSenses).insert(CardSensesCompanion.insert(
            cardId: a,
            ordinal: ordinal,
            gloss: 'g$ordinal',
          ));
    }

    final recent = await repo.recentlyObtained(limit: 2);
    expect([for (final e in recent) e.card.id], [b, c]);

    expect((await repo.cardWithState(a))!.isOwned, isTrue);
    expect((await repo.cardWithState(unowned))!.isOwned, isFalse);
    expect(await repo.cardWithState(9999), equals(null));

    final byIds = await repo.cardsByIds([c, 9999, a]);
    expect([for (final r in byIds) r.id], [c, a]);

    final senses = await repo.sensesForCards([a, b]);
    expect([for (final s in senses[a]!) s.ordinal], [1, 2]);
    expect(senses[b], isEmpty);
  });
}
