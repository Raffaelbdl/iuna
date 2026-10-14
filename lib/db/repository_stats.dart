part of 'repository.dart';

/// One row of the daily activity chart.
class DailyActivity {
  const DailyActivity({
    required this.date,
    required this.totalsByRarity,
    required this.correctByRarity,
    required this.newCards,
  });

  /// Logical-day key (`YYYY-MM-DD`).
  final String date;
  final Map<Rarity, int> totalsByRarity;
  final Map<Rarity, int> correctByRarity;
  final int newCards;

  int get total => totalsByRarity.values.fold(0, (sum, v) => sum + v);
  int get correct => correctByRarity.values.fold(0, (sum, v) => sum + v);
  int get wrong => total - correct;
  double? get accuracy => total == 0 ? null : correct / total;
}

/// One bin of the retention curve.
class RetentionBin {
  const RetentionBin({
    required this.label,
    required this.minMinutes,
    required this.maxMinutes,
    required this.total,
    required this.correct,
  });

  final String label;
  final int minMinutes;
  final int maxMinutes;
  final int total;
  final int correct;

  double? get retention => total == 0 ? null : correct / total;
}

/// One bin of the maturity histogram (current `user_cards` state,
/// bucketed by `intervalMinutes`).
class MaturityBin {
  const MaturityBin({
    required this.label,
    required this.minMinutes,
    required this.maxMinutes,
    required this.count,
  });

  final String label;
  final int minMinutes;
  final int maxMinutes;
  final int count;
}

/// One row of the upcoming-review forecast.
class ForecastDay {
  const ForecastDay({required this.date, required this.due});

  /// Local-date key (`YYYY-MM-DD`).
  final String date;
  final int due;
}

/// One leech: a card the user keeps failing.
class LeechEntry {
  const LeechEntry({required this.card, required this.failCount});

  final CardRow card;
  final int failCount;
}

/// Streak metrics for the stats screen — current run, longest ever,
/// total active days, plus a recent on/off strip for visualising the
/// last few weeks.
class StreakStats {
  const StreakStats({
    required this.current,
    required this.longest,
    required this.totalDays,
    required this.recent,
  });

  final int current;
  final int longest;
  final int totalDays;

  /// One bool per day, oldest first → today last. Length matches the
  /// `recent` arg passed to [DeckStats.streakStats].
  final List<bool> recent;
}

/// Pass rates folded from one grouped scan of `review_log`, plus the
/// lifetime headline counts.
class ReviewBreakdown {
  const ReviewBreakdown({
    required this.trueRetention,
    required this.byKind,
    required this.byRarity,
    required this.reviews,
    required this.learned,
  });

  /// Anki-style "true retention": the pass rate over post-graduation
  /// reviews (prev interval ≥ 1 day), whatever their [ReviewKind]. It
  /// can't be read off `byKind[review]`: [classifyReview] files every
  /// wrong answer under `relearn`, which makes `review`-kind rows
  /// tautologically 100% correct. Counting prev interval ≥ 1 day keeps
  /// both the successes (`review`) and the mature lapses (`relearn`
  /// from a graduated card).
  final ({int total, int correct}) trueRetention;

  /// Pass rate per [ReviewKind] (the donut on the stats screen).
  final Map<ReviewKind, ({int total, int correct})> byKind;

  /// Pass rate per rarity ("Accuracy by rarity").
  final Map<Rarity, ({int total, int correct})> byRarity;

  /// Lifetime review count.
  final int reviews;

  /// Owned cards.
  final int learned;
}

/// One day of (total ms spent, median answer time) for the time-spent
/// chart.
class TimeSpentDay {
  const TimeSpentDay({
    required this.date,
    required this.totalMs,
    required this.medianMs,
  });

  final String date;
  final int totalMs;
  final int? medianMs;
}

/// Logarithmic retention / maturity bins. Same shape used for both —
/// retention asks "of reviews that came in at this interval, how many
/// did we get right?", maturity asks "how many cards currently sit at
/// this interval?". Boundaries are (min, max], left-inclusive on the
/// first bin so prevIntervalMinutes == 0 (very first review) lands in
/// '<1d'.
const List<(String, int, int)> kIntervalBuckets = [
  ('<1d', 0, 60 * 24),
  ('1-3d', 60 * 24, 60 * 24 * 3),
  ('4-7d', 60 * 24 * 3, 60 * 24 * 7),
  ('1-2w', 60 * 24 * 7, 60 * 24 * 14),
  ('2-4w', 60 * 24 * 14, 60 * 24 * 30),
  ('1-3mo', 60 * 24 * 30, 60 * 24 * 90),
  ('3-6mo', 60 * 24 * 90, 60 * 24 * 180),
  ('6mo+', 60 * 24 * 180, 1 << 30),
];

/// SQL expression giving the [kIntervalBuckets] index of [column]; a
/// value outside every bin lands in the last one.
String _bucketCase(String column) {
  final sql = StringBuffer('CASE');
  for (var i = 0; i < kIntervalBuckets.length - 1; i++) {
    final (_, lo, hi) = kIntervalBuckets[i];
    sql.write(' WHEN $column >= $lo AND $column < $hi THEN $i');
  }
  sql.write(' ELSE ${kIntervalBuckets.length - 1} END');
  return '$sql';
}

typedef _PassRate = ({int total, int correct});

_PassRate _plus(_PassRate a, int total, int correct) =>
    (total: a.total + total, correct: a.correct + correct);

/// Read-only queries behind the stats screen.
extension DeckStats on IunaRepository {
  /// Aggregate review counts for today's logical day. Used by the
  /// review-done screen to surface the day total alongside the just-
  /// finished session — split-session users don't get judged on the
  /// last batch alone.
  Future<({int total, int correct})> todayStats({DateTime? now}) async {
    final day = await _day(now);
    final row = await (db.select(
      db.dailyStats,
    )..where((s) => s.date.equals(day.key))).getSingleOrNull();
    final activity = _activityFromRow(day.key, row);
    return (total: activity.total, correct: activity.correct);
  }

  /// Daily activity for the [days] logical days ending at [now]
  /// inclusive. Days with no reviews are filled in with zeros so the
  /// chart x-axis is continuous (gaps read as "didn't study", not
  /// "missing data").
  Future<List<DailyActivity>> dailyActivity({
    int days = 30,
    DateTime? now,
  }) async {
    final keys = (await _day(now)).lastKeys(days);
    final rows = await (db.select(
      db.dailyStats,
    )..where((s) => s.date.isBiggerOrEqualValue(keys.first))).get();
    final byKey = {for (final r in rows) r.date: r};
    return [for (final k in keys) _activityFromRow(k, byKey[k])];
  }

  static DailyActivity _activityFromRow(String key, DailyStatRow? row) {
    return DailyActivity(
      date: key,
      totalsByRarity: {
        Rarity.common: row?.cTotal ?? 0,
        Rarity.rare: row?.rTotal ?? 0,
        Rarity.superRare: row?.srTotal ?? 0,
        Rarity.ssr: row?.ssrTotal ?? 0,
        Rarity.ur: row?.urTotal ?? 0,
      },
      correctByRarity: {
        Rarity.common: row?.cCorrect ?? 0,
        Rarity.rare: row?.rCorrect ?? 0,
        Rarity.superRare: row?.srCorrect ?? 0,
        Rarity.ssr: row?.ssrCorrect ?? 0,
        Rarity.ur: row?.urCorrect ?? 0,
      },
      newCards: row?.newCards ?? 0,
    );
  }

  /// Retention curve: for each [kIntervalBuckets] bin, what fraction of
  /// reviews that came in at that interval were correct? [windowDays]
  /// optionally clips to recent data; null means all-time.
  Future<List<RetentionBin>> retentionCurve({
    int? windowDays,
    DateTime? now,
  }) async {
    final cutoff = windowDays == null
        ? null
        : (now ?? DateTime.now()).subtract(Duration(days: windowDays));
    final rows = await db
        .customSelect(
          'SELECT ${_bucketCase('prev_interval_minutes')} AS b, '
          'COUNT(*) AS n, SUM(correct) AS ok FROM review_log '
          '${cutoff == null ? '' : 'WHERE reviewed_at >= ?'} GROUP BY b',
          variables: [if (cutoff != null) Variable.withDateTime(cutoff)],
          readsFrom: {db.reviewLog},
        )
        .get();
    final totals = List<int>.filled(kIntervalBuckets.length, 0);
    final correct = List<int>.filled(kIntervalBuckets.length, 0);
    for (final r in rows) {
      totals[r.read<int>('b')] = r.read<int>('n');
      correct[r.read<int>('b')] = r.read<int>('ok');
    }
    return [
      for (final (i, (label, lo, hi)) in kIntervalBuckets.indexed)
        RetentionBin(
          label: label,
          minMinutes: lo,
          maxMinutes: hi,
          total: totals[i],
          correct: correct[i],
        ),
    ];
  }

  /// "How mature is my deck right now?" — owned cards bucketed by
  /// current `intervalMinutes`. Cards with interval 0 (claimed but
  /// never reviewed) are dropped, since they belong to the booster
  /// flow rather than the SRS timeline.
  Future<List<MaturityBin>> maturityHistogram() async {
    final rows = await db
        .customSelect(
          'SELECT ${_bucketCase('interval_minutes')} AS b, COUNT(*) AS n '
          'FROM user_cards WHERE interval_minutes > 0 GROUP BY b',
          readsFrom: {db.userCards},
        )
        .get();
    final counts = List<int>.filled(kIntervalBuckets.length, 0);
    for (final r in rows) {
      counts[r.read<int>('b')] = r.read<int>('n');
    }
    return [
      for (final (i, (label, lo, hi)) in kIntervalBuckets.indexed)
        MaturityBin(
          label: label,
          minMinutes: lo,
          maxMinutes: hi,
          count: counts[i],
        ),
    ];
  }

  /// Number of cards due per logical day for the next [days] days,
  /// starting *tomorrow* (today's due cards are surfaced by
  /// [IunaRepository.dueCountToday] instead). The first entry is
  /// "tomorrow".
  Future<List<ForecastDay>> dueForecast({int days = 14, DateTime? now}) async {
    final day = await _day(now);
    final keys = [for (var i = 1; i <= days; i++) shiftDayKey(day.key, i)];
    // A day's margin at the far end: the keys decide what counts.
    final rows =
        await (db.selectOnly(db.userCards)
              ..addColumns([db.userCards.nextDue])
              ..where(
                db.userCards.nextDue.isBiggerOrEqualValue(day.end) &
                    db.userCards.nextDue.isSmallerThanValue(
                      day.start.add(Duration(days: days + 2)),
                    ) &
                    db.userCards.suspended.equals(false),
              ))
            .get();

    final counts = <String, int>{};
    for (final r in rows) {
      final key = day.keyOf(r.read(db.userCards.nextDue)!);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return [for (final k in keys) ForecastDay(date: k, due: counts[k] ?? 0)];
  }

  /// Top-N cards by lifetime fail count. Cards with zero failures are
  /// omitted — the list is meant to surface stubborn cards, so an
  /// empty result reads as "nothing's been hard" rather than "we
  /// haven't reviewed anything".
  Future<List<LeechEntry>> leeches({int limit = 10}) async {
    final query =
        db.select(db.cards).join([
            innerJoin(db.userCards, db.userCards.cardId.equalsExp(db.cards.id)),
          ])
          ..where(db.userCards.failCount.isBiggerThanValue(0))
          ..orderBy([
            OrderingTerm.desc(db.userCards.failCount),
            OrderingTerm.asc(db.cards.kanji),
          ])
          ..limit(limit);
    final rows = await query.get();
    return [
      for (final r in rows)
        LeechEntry(
          card: r.readTable(db.cards),
          failCount: r.readTable(db.userCards).failCount,
        ),
    ];
  }

  /// Every all-time pass rate on the stats screen plus the lifetime
  /// counts, from one `review_log` scan grouped by (kind, rarity,
  /// mature) — a few dozen rows.
  Future<ReviewBreakdown> reviewBreakdown() async {
    final learnedCount = db.userCards.cardId.count();
    final (cells, learnedRow) = await (
      db
          .customSelect(
            'SELECT kind, rarity, '
            'prev_interval_minutes >= ${60 * 24} AS mature, '
            'COUNT(*) AS n, SUM(correct) AS ok FROM review_log '
            'GROUP BY kind, rarity, mature',
            readsFrom: {db.reviewLog},
          )
          .get(),
      (db.selectOnly(db.userCards)..addColumns([learnedCount])).getSingle(),
    ).wait;

    const zero = (total: 0, correct: 0);
    var trueRetention = zero;
    final byKind = {for (final k in ReviewKind.values) k: zero};
    final byRarity = {for (final r in Rarity.values) r: zero};
    var reviews = 0;
    for (final c in cells) {
      final n = c.read<int>('n');
      final ok = c.read<int>('ok');
      final kind = ReviewKind.values[c.read<int>('kind')];
      final rarity = Rarity.values[c.read<int>('rarity')];
      byKind[kind] = _plus(byKind[kind]!, n, ok);
      byRarity[rarity] = _plus(byRarity[rarity]!, n, ok);
      if (c.read<int>('mature') == 1) {
        trueRetention = _plus(trueRetention, n, ok);
      }
      reviews += n;
    }
    return ReviewBreakdown(
      trueRetention: trueRetention,
      byKind: byKind,
      byRarity: byRarity,
      reviews: reviews,
      learned: learnedRow.read(learnedCount) ?? 0,
    );
  }

  /// Owned vs total cards per JLPT level (1..5 → N1..N5). Cards with
  /// no JLPT tag are excluded — they're typically user-added words and
  /// don't belong on a JLPT progress chart.
  Future<Map<int, ({int owned, int total})>> jlptProgress() async {
    final counts = await _ownedVsTotal(db.cards.jlptLevel);
    return {
      for (var lvl = 1; lvl <= 5; lvl++)
        lvl: counts[lvl] ?? (owned: 0, total: 0),
    };
  }

  /// Display labels for installed packs, keyed by pack name. A pack
  /// whose row is missing (a backup restored from before the packs
  /// table existed) falls back to its raw name.
  Future<Map<String, String>> packLabels() async {
    final rows = await db.select(db.packs).get();
    return {for (final r in rows) r.name: r.label};
  }

  /// Owned vs total cards per themed pack, keyed by `cards.pack`. A
  /// newly installed pack appears here — and therefore on the stats
  /// screen — as soon as it tags a card, with no further wiring.
  Future<Map<String, ({String label, int owned, int total})>>
  packProgress() async {
    final labels = await packLabels();
    final counts = await _ownedVsTotal(db.cards.pack);
    return {
      for (final MapEntry(:key, :value) in counts.entries)
        key: (
          label: labels[key] ?? key,
          owned: value.owned,
          total: value.total,
        ),
    };
  }

  /// 24 buckets (0..23) of review counts by hour-of-day, in local time.
  /// Drives the radial "When you study" clock.
  Future<List<int>> hourOfDayHistogram() async {
    // Grouped by quarter-hour rather than by SQLite's own `localtime`:
    // every UTC offset in use is a multiple of 15 minutes, so each
    // bucket falls in exactly one local hour, and Dart (DST included)
    // decides which.
    const quarter = 15 * 60;
    final rows = await db
        .customSelect(
          'SELECT reviewed_at / $quarter AS q, COUNT(*) AS n '
          'FROM review_log GROUP BY q',
          readsFrom: {db.reviewLog},
        )
        .get();
    final out = List<int>.filled(24, 0);
    for (final r in rows) {
      final at = DateTime.fromMillisecondsSinceEpoch(
        r.read<int>('q') * quarter * 1000,
      );
      out[at.hour] += r.read<int>('n');
    }
    return out;
  }

  /// Per-day total time spent reviewing + median answer time (ms). Days
  /// with no recorded `durationMs` come back with [TimeSpentDay.totalMs]
  /// 0 and [TimeSpentDay.medianMs] null so the chart can blank that
  /// column rather than draw a misleading zero-line.
  Future<List<TimeSpentDay>> timeSpentSeries({
    int days = 30,
    DateTime? now,
  }) async {
    final day = await _day(now);
    final log = db.reviewLog;
    // A day's margin at the near end: the keys decide what counts.
    final rows =
        await (db.selectOnly(log)
              ..addColumns([log.reviewedAt, log.durationMs])
              ..where(
                log.reviewedAt.isBiggerOrEqualValue(
                      day.start.subtract(Duration(days: days)),
                    ) &
                    log.durationMs.isNotNull(),
              ))
            .get();
    final byDay = <String, List<int>>{};
    for (final r in rows) {
      byDay
          .putIfAbsent(day.keyOf(r.read(log.reviewedAt)!), () => <int>[])
          .add(r.read(log.durationMs)!);
    }
    return [
      for (final key in day.lastKeys(days))
        _timeSpent(key, byDay[key] ?? const []),
    ];
  }

  static TimeSpentDay _timeSpent(String key, List<int> durations) {
    return TimeSpentDay(
      date: key,
      totalMs: durations.fold<int>(0, (a, b) => a + b),
      medianMs: durations.isEmpty
          ? null
          : ([...durations]..sort())[durations.length ~/ 2],
    );
  }

  /// Streak metrics + a [recent]-day on/off strip ending today. Reads
  /// directly off `daily_stats`, so it counts a day as "active" when
  /// the user logged any review (across any rarity).
  Future<StreakStats> streakStats({int recent = 35, DateTime? now}) async {
    final day = await _day(now);
    final rows = await db.select(db.dailyStats).get();
    final activeKeys = {
      for (final r in rows)
        if (_activityFromRow(r.date, r).total > 0 &&
            DateTime.tryParse(r.date) != null)
          r.date,
    };

    var current = 0;
    for (var k = day.key; activeKeys.contains(k); k = shiftDayKey(k, -1)) {
      current++;
    }

    var longest = 0;
    var run = 0;
    String? prev;
    for (final k in activeKeys.toList()..sort()) {
      run = prev != null && shiftDayKey(prev, 1) == k ? run + 1 : 1;
      if (run > longest) longest = run;
      prev = k;
    }
    if (current > longest) longest = current;

    return StreakStats(
      current: current,
      longest: longest,
      totalDays: activeKeys.length,
      recent: [for (final k in day.lastKeys(recent)) activeKeys.contains(k)],
    );
  }
}
