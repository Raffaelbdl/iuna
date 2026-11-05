import 'package:iuna/db/database.dart';
import 'package:iuna/db/repository.dart';

/// An owned, met card for the games' pure tests.
DailyDeckEntry gameCard(
  int id,
  String kanji,
  String kana, {
  String? meaning,
  double ease = 2.0,
  int fails = 0,
}) {
  final t = DateTime(2026, 11, 1);
  return DailyDeckEntry(
    card: CardRow(
      id: id,
      kanji: kanji,
      kana: kana,
      meaning: meaning ?? 'meaning $id',
      rarity: Rarity.common,
      source: CardSource.seed,
    ),
    userCard: UserCardRow(
      cardId: id,
      level: 1,
      ease: ease,
      intervalMinutes: 1440,
      nextDue: t,
      obtainedAt: t,
      isNew: false,
      failCount: fails,
      suspended: false,
    ),
  );
}
