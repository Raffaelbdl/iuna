// Deck rules shared by the app and the command-line tools. Pure Dart —
// no Flutter import — so `dart run tools/...` can use it too.

import 'package:crypto/crypto.dart';

/// Gacha-style rarity tiers, decoupled from JLPT level. JLPT is stored
/// separately on the card and shown only when applicable (the seed deck
/// has it; user-added cards typically don't).
enum Rarity { common, rare, superRare, ssr, ur }

/// Review classification, mirroring Anki's `revlog.type`. `learn` is the
/// initial graduation phase (intervals < 1 day). `review` is the
/// post-graduation maintenance loop (interval ≥ 1 day, answered
/// correctly). `relearn` is any wrong answer — it always pushes the
/// card back into a learning loop.
enum ReviewKind { learn, review, relearn }

/// Maps a (prev_interval, correct) pair to a [ReviewKind]. Wrong
/// answers always become `relearn`. Correct answers below the 1-day
/// threshold are still in the learning queue (Iuna's first two
/// scheduler steps are 1d and 3d, with `<1d` only reachable when a
/// previous lapse has just happened); correct answers ≥ 1d are
/// post-graduation maintenance reviews.
ReviewKind classifyReview({
  required int prevIntervalMinutes,
  required bool correct,
}) {
  if (!correct) return ReviewKind.relearn;
  return prevIntervalMinutes < 60 * 24 ? ReviewKind.learn : ReviewKind.review;
}

/// Per-rarity column prefix in `daily_stats` (`c_total`, `sr_correct`,
/// …). Derived from a closed enum, never user input, so it is safe to
/// interpolate into SQL.
String rarityColumn(Rarity r) => switch (r) {
  Rarity.common => 'c',
  Rarity.rare => 'r',
  Rarity.superRare => 'sr',
  Rarity.ssr => 'ssr',
  Rarity.ur => 'ur',
};

/// `YYYY-MM-DD` for the logical day that contains [now], where the
/// day boundary moves to [resetHour] (0..23) instead of midnight.
/// At local time before [resetHour] the user is still on the previous
/// calendar day.
String logicalDayKey(DateTime now, int resetHour) =>
    _dayKey(now.toLocal().subtract(Duration(hours: resetHour)));

/// The day key [days] calendar days after [key] (before, if negative).
/// Calendar arithmetic, not 24 h steps from a local instant, which skip
/// or repeat a day across a DST change.
String shiftDayKey(String key, int days) {
  final d = DateTime.parse(key);
  return _dayKey(DateTime.utc(d.year, d.month, d.day + days));
}

String _dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Local-clock instant where the logical day containing [now] began.
/// Pairs with [logicalDayKey] to bound a `BETWEEN` query.
DateTime logicalDayStart(DateTime now, int resetHour) {
  final shifted = now.toLocal().subtract(Duration(hours: resetHour));
  final day = DateTime(shifted.year, shifted.month, shifted.day);
  return day.add(Duration(hours: resetHour));
}

/// Truncated sha256 published in the `.version` / manifest files of
/// every downloadable asset. The tools that publish and the app that
/// verifies must agree on it byte for byte.
String truncatedSha256(List<int> bytes) =>
    sha256.convert(bytes).toString().substring(0, 16);
