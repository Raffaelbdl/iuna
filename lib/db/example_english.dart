import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'database.dart';
import 'repository.dart' show MetaKeys;

/// Which round of seed English a deck has taken in.
const String kExampleEnglishVersion = '2';

/// A deck freshly copied from the bundled seed has this round's English
/// already.
Future<void> markSeedEnglish(AppDatabase db) => db.customStatement(
      'INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)',
      [MetaKeys.exampleEnglish, kExampleEnglishVersion],
    );

/// Brings Tatoeba's English from the bundled seed into a deck copied
/// from an older seed. It is data, not schema, so a meta flag gates it:
/// a restored backup takes it again, and a better seed can bump
/// [kExampleEnglishVersion]. Matched on the sentence, not the id: a deck
/// copied from an older seed numbers its examples differently. Only
/// empty translations are filled, so Kuma-sensei's stay as written.
Future<void> backfillExampleEnglish(
  AppDatabase db, {
  Future<void> Function(File target) seed = copyBundledSeed,
}) async {
  final flag = await (db.select(db.meta)..where((m) => m.key.equals(MetaKeys.exampleEnglish)))
      .getSingleOrNull();
  if (flag?.value == kExampleEnglishVersion) return;

  final copy = File('${(await getTemporaryDirectory()).path}/seed_english.sqlite');
  try {
    if (await copy.exists()) await copy.delete();
    await seed(copy);
    if (!await copy.exists()) return;
    // ATTACH and DETACH refuse to run inside a transaction.
    await db.customStatement('ATTACH DATABASE ? AS seed', [copy.path]);
    try {
      // The copy is thrown away after, so it can take the index the
      // lookup needs.
      await db.customStatement('CREATE INDEX seed.examples_by_sentence ON examples (sentence)');
      await db.transaction(() async {
        await db.customStatement('''
          UPDATE examples SET translation =
            (SELECT s.translation FROM seed.examples s
             WHERE s.sentence = examples.sentence AND s.translation IS NOT NULL)
          WHERE translation IS NULL AND generated = 0
            AND sentence IN (SELECT sentence FROM seed.examples WHERE translation IS NOT NULL)
        ''');
        await markSeedEnglish(db);
      });
    } finally {
      await db.customStatement('DETACH DATABASE seed');
    }
  } finally {
    if (await copy.exists()) await copy.delete();
  }
}
