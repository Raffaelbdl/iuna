import 'dart:math';

/// Binary-grade SM-2 variant. The user's grade is just right or wrong
/// (swipe right / swipe left); a long-press "easy" can be added later
/// without a schema migration since `ease` is already persisted.
///
/// State per user_card:
///   level            — gamified counter, +1 right / -1 wrong, floored at 0.
///   ease             — multiplier in [1.3, 3.0], starts at 2.0.
///   intervalMinutes  — current scheduling gap; 0 for newly-claimed cards.
///
/// Schedule rules:
///   - Right swipe, pre-review level == 0  → next interval = 1 day.
///   - Right swipe, pre-review level == 1  → next interval = 3 days.
///   - Right swipe, pre-review level >= 2  → next = previous × ease.
///   - Right swipe also bumps ease by +0.1 (cap 3.0).
///   - Wrong swipe                        → next = max(10 min, previous × 0.5),
///                                           ease -= 0.2 (floor 1.3),
///                                           level = max(0, level-1).
///
/// The pre-review level decides which schedule branch fires, so a wrong
/// answer (which drops level back toward 0) gracefully resets the
/// short-term scheduling without losing the persisted ease history.

const _minutesPerDay = 60 * 24;
const minIntervalMinutes = 10;
const startingEase = 2.0;
const minEase = 1.3;
const maxEase = 3.0;
const easeStep = 0.1;
const easePenalty = 0.2;

class ReviewOutcome {
  ReviewOutcome({
    required this.level,
    required this.ease,
    required this.intervalMinutes,
    required this.nextDue,
  });

  final int level;
  final double ease;
  final int intervalMinutes;
  final DateTime nextDue;
}

ReviewOutcome scheduleNext({
  required int level,
  required double ease,
  required int intervalMinutes,
  required bool correct,
  required DateTime now,
}) {
  if (correct) {
    final newEase = (ease + easeStep).clamp(minEase, maxEase);
    final int next;
    if (level <= 0) {
      next = _minutesPerDay;
    } else if (level == 1) {
      next = 3 * _minutesPerDay;
    } else {
      // After the two fixed steps, grow by the (post-review) ease.
      next = max(_minutesPerDay, (intervalMinutes * newEase).round());
    }
    return ReviewOutcome(
      level: level + 1,
      ease: newEase,
      intervalMinutes: next,
      nextDue: now.add(Duration(minutes: next)),
    );
  } else {
    final newEase = (ease - easePenalty).clamp(minEase, maxEase);
    final next = max(minIntervalMinutes, (intervalMinutes * 0.5).round());
    return ReviewOutcome(
      level: max(0, level - 1),
      ease: newEase,
      intervalMinutes: next,
      nextDue: now.add(Duration(minutes: next)),
    );
  }
}
