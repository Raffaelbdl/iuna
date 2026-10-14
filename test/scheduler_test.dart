import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/services/scheduler.dart';

void main() {
  final now = DateTime(2026, 4, 26, 12);

  group('right swipe', () {
    test('first review on a fresh card schedules in one day', () {
      final out = scheduleNext(
        level: 0,
        ease: startingEase,
        intervalMinutes: 0,
        correct: true,
        now: now,
      );
      expect(out.level, 1);
      expect(out.intervalMinutes, 60 * 24);
      expect(out.ease, closeTo(2.1, 1e-9));
      expect(out.nextDue, now.add(const Duration(days: 1)));
    });

    test('second consecutive correct review schedules in three days', () {
      final out = scheduleNext(
        level: 1,
        ease: 2.1,
        intervalMinutes: 60 * 24,
        correct: true,
        now: now,
      );
      expect(out.level, 2);
      expect(out.intervalMinutes, 60 * 24 * 3);
    });

    test('third+ correct review multiplies the previous interval by ease',
        () {
      final out = scheduleNext(
        level: 2,
        ease: 2.2,
        intervalMinutes: 60 * 24 * 3,
        correct: true,
        now: now,
      );
      expect(out.level, 3);
      expect(out.ease, closeTo(2.3, 1e-9));
      // 3 days * 2.3 = 6.9 days
      expect(out.intervalMinutes,
          (60 * 24 * 3 * 2.3).round());
    });

    test('ease is capped at maxEase', () {
      final out = scheduleNext(
        level: 5,
        ease: 2.95,
        intervalMinutes: 60 * 24 * 30,
        correct: true,
        now: now,
      );
      expect(out.ease, maxEase);
    });
  });

  group('left swipe', () {
    test('drops level by one and halves the interval', () {
      final out = scheduleNext(
        level: 4,
        ease: 2.5,
        intervalMinutes: 60 * 24 * 10,
        correct: false,
        now: now,
      );
      expect(out.level, 3);
      expect(out.ease, closeTo(2.3, 1e-9));
      expect(out.intervalMinutes, 60 * 24 * 5);
    });

    test('level is floored at zero', () {
      final out = scheduleNext(
        level: 0,
        ease: minEase,
        intervalMinutes: 0,
        correct: false,
        now: now,
      );
      expect(out.level, 0);
      expect(out.ease, minEase, reason: 'ease floor holds');
      expect(out.intervalMinutes, minIntervalMinutes,
          reason: 'interval clamped to 10 minutes');
    });

    test('ease floor at minEase', () {
      final out = scheduleNext(
        level: 2,
        ease: 1.4,
        intervalMinutes: 60,
        correct: false,
        now: now,
      );
      expect(out.ease, minEase);
    });
  });

  test('a wrong-then-right sequence resets to 1d, not previous*ease', () {
    var s = scheduleNext(
      level: 5,
      ease: 2.5,
      intervalMinutes: 60 * 24 * 30,
      correct: false,
      now: now,
    );
    expect(s.level, 4);
    // user keeps getting it wrong until level 0
    while (s.level > 0) {
      s = scheduleNext(
        level: s.level,
        ease: s.ease,
        intervalMinutes: s.intervalMinutes,
        correct: false,
        now: now,
      );
    }
    expect(s.level, 0);
    final back = scheduleNext(
      level: s.level,
      ease: s.ease,
      intervalMinutes: s.intervalMinutes,
      correct: true,
      now: now,
    );
    expect(back.intervalMinutes, 60 * 24,
        reason: 'fresh-start branch fires when level resets to 0');
    expect(back.level, 1);
  });
}
