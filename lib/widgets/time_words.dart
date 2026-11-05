import 'package:intl/intl.dart';

/// An hour of the day as said aloud: "midnight", "noon", "4 AM".
String hourWords(int hour) => switch (hour) {
  0 => 'midnight',
  12 => 'noon',
  _ => DateFormat('h a').format(DateTime(2000, 1, 1, hour)),
};

/// A time of day as the app shows it: "3:10 PM", or "9 AM" and
/// "noon" on the hour.
String clockWords(DateTime t) =>
    t.minute == 0 ? hourWords(t.hour) : DateFormat('h:mm a').format(t);

/// When [t] is, seen from [now]: "now", "today at 3:10 PM", "tomorrow
/// at midnight", "Thu at 9 AM", then "Apr 30" past a week. [capitalized]
/// for a value standing on its own ("Today at 3:10 PM").
String whenWords(DateTime t, DateTime now, {bool capitalized = false}) {
  final words = _whenWords(t, now);
  return capitalized ? words[0].toUpperCase() + words.substring(1) : words;
}

String _whenWords(DateTime t, DateTime now) {
  if (!t.isAfter(now)) return 'now';
  // Calendar days in UTC, so a DST change can't make a day 23 hours.
  final days = DateTime.utc(
    t.year,
    t.month,
    t.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  final clock = clockWords(t);
  return switch (days) {
    0 => 'today at $clock',
    1 => 'tomorrow at $clock',
    < 7 => '${DateFormat('EEE').format(t)} at $clock',
    _ => DateFormat('MMM d').format(t),
  };
}

/// A calendar day as the app shows it: "Apr 25, 2026".
String dayWords(DateTime d) => DateFormat('MMM d, y').format(d);

/// A moment in the past, such as a backup: "Apr 25, 2026 at 3:10 PM".
String stampWords(DateTime t) => '${dayWords(t)} at ${clockWords(t)}';
