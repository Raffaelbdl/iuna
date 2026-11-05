import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/games/sentence_feed.dart';
import 'package:iuna/games/sentence_tiles.dart';

import 'game_test_helpers.dart';
import 'sentence_words.dart';

/// Owned cards with their example sentences, by kanji: what the
/// sentence tests play with.
const kSentenceDeck = {
  '猫': [
    ('猫は魚を食べた。', 'The cat ate the fish.'),
    ('猫が魚を食べてしまった。', 'The cat went and ate the fish.'),
  ],
  '本': [('私は昨日この本を読んだ。', 'I read this book yesterday.')],
  '魚': [
    ('私は魚を食べた。', 'I ate fish.'),
    // 鰻 is neither owned nor common: never asked.
    ('私は鰻を食べた。', 'I ate eel.'),
    // Too long for a game.
    ('私は毎日魚を食べて、猫は毎日魚を食べてしまった。', 'Long.'),
  ],
  '勉強': [
    ('私は毎日勉強した。', 'I studied every day.'),
    // No English, no clue.
    ('私は昨日勉強した。', null),
  ],
  '私': <(String, String?)>[],
};

const _kana = {'猫': 'ねこ', '本': 'ほん', '魚': 'さかな', '勉強': 'べんきょう', '私': 'わたし'};

/// The deck in memory, and each card's id by kanji.
Future<(AppDatabase, Map<String, int>)> sentenceDeck() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final ids = <String, int>{};
  for (final MapEntry(key: kanji, value: examples) in kSentenceDeck.entries) {
    final id = ids[kanji] = await ownCard(db, kanji, _kana[kanji]!, kanji);
    for (final (sentence, english) in examples) {
      final ex = await db
          .into(db.examples)
          .insert(
            ExamplesCompanion.insert(
              sentence: sentence,
              translation: Value(english),
            ),
          );
      await db
          .into(db.cardExamples)
          .insert(CardExamplesCompanion.insert(cardId: id, exampleId: ex));
    }
  }
  return (db, ids);
}

/// Tiles on the spot over [kSentenceWords], recording each batch.
SentenceTiler syncTiler([List<List<String>>? batches]) => (sentences) async {
  batches?.add(sentences);
  final lexicon = sentenceLexicon();
  return [for (final s in sentences) tileSentence(s, lexicon)];
};
