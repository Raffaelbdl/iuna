import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/example_english.dart';
import 'package:iuna/db/repository.dart' show MetaKeys;
import 'package:sqlite3/sqlite3.dart' as sql;

import 'helpers/fake_path_provider.dart';

void main() {
  late Directory temp;
  late File seed;
  late AppDatabase db;
  var seedCopies = 0;

  Future<void> backfill() => backfillExampleEnglish(
        db,
        seed: (target) async {
          seedCopies++;
          await seed.copy(target.path);
        },
      );

  Future<String?> flag() async =>
      (await (db.select(db.meta)..where((m) => m.key.equals(MetaKeys.exampleEnglish)))
              .getSingleOrNull())
          ?.value;

  Future<Map<int, String?>> english() async => {
        for (final e in await db.select(db.examples).get()) e.id: e.translation,
      };

  setUp(() async {
    temp = useTempDocumentsDir('iuna_example_english_');
    final assets = Directory.systemTemp.createTempSync('iuna_bundled_seed_');
    addTearDown(() => assets.deleteSync(recursive: true));
    seed = File('${assets.path}/seed.sqlite');
    final raw = sql.sqlite3.open(seed.path);
    raw.execute('CREATE TABLE examples (id INTEGER PRIMARY KEY, sentence TEXT, translation TEXT)');
    raw.execute("""
      INSERT INTO examples VALUES
        (1, '駅に行く。', 'I go to the station.'),
        (2, '本を読む。', 'I read a book.'),
        (3, '水を飲む。', 'I drink water.'),
        (4, '寝る。', 'I sleep.')
    """);
    raw.dispose();

    db = AppDatabase.forTesting(NativeDatabase.memory());
    expect(await flag(), kExampleEnglishVersion, reason: 'a fresh deck is the current seed');
    await (db.delete(db.meta)..where((m) => m.key.equals(MetaKeys.exampleEnglish))).go();
    // The deck as an older seed left it, numbered its own way, plus what
    // came after.
    for (final e in [
      ExamplesCompanion.insert(id: const Value(1), sentence: '駅に行く。'),
      ExamplesCompanion.insert(id: const Value(2), sentence: '本を読む。', translation: const Value('Reading.')),
      ExamplesCompanion.insert(id: const Value(3), sentence: '友達が来る。'),
      ExamplesCompanion.insert(id: const Value(4), sentence: '寝る。', generated: const Value(true)),
      ExamplesCompanion.insert(id: const Value(9), sentence: '水を飲む。'),
    ]) {
      await db.into(db.examples).insert(e);
    }
    seedCopies = 0;
  });

  tearDown(() async {
    await db.close();
  });

  test("fills the seed's sentences that lack English, whatever their id, once", () async {
    await backfill();
    expect(await english(), {
      1: 'I go to the station.',
      2: 'Reading.',
      3: null,
      4: null,
      9: 'I drink water.',
    }, reason: "2 keeps its English, 3 is not in the seed, 4 is Kuma-sensei's, "
        '9 is a seed sentence under another id');
    expect(temp.listSync(), isEmpty, reason: 'the seed copy is cleaned up');
    expect(await flag(), kExampleEnglishVersion);

    await backfill();
    expect(seedCopies, 1, reason: 'the meta flag skips the second run');
  });

  test('a build without a bundled seed leaves the flag unset to try again', () async {
    await backfillExampleEnglish(db, seed: (_) async {});
    expect(await english(), {1: null, 2: 'Reading.', 3: null, 4: null, 9: null});
    expect(await flag(), isNull);
  });
}
