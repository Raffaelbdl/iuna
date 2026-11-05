import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  test('a v7 deck gains examples.translation and .generated and keeps its rows', () async {
    final dir = Directory.systemTemp.createTempSync('iuna_deck_v7_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/iuna.sqlite');

    // The v7 examples table, as the seed and every release up to v7 made it.
    final raw = sql.sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE examples (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        sentence TEXT NOT NULL,
        source_title TEXT NULL
      )''');
    raw.execute("INSERT INTO examples (sentence) VALUES ('明日学校へ行く。')");
    raw.execute('PRAGMA user_version = 7');
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final row = (await db.select(db.examples).get()).single;
    expect(row.sentence, '明日学校へ行く。');
    expect(row.translation, isNull);
    expect(row.generated, isFalse);
  });

  test('a fresh install from the seed patches the new example columns in', () async {
    final dir = Directory.systemTemp.createTempSync('iuna_deck_seed_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/iuna.sqlite');

    // The seed asset ships its tables without a user_version, so
    // onCreate's CREATE TABLE IF NOT EXISTS leaves them as they are.
    final raw = sql.sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE examples (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sentence TEXT NOT NULL,
        source_title TEXT
      )''');
    raw.execute("INSERT INTO examples (sentence) VALUES ('明日学校へ行く。')");
    raw.dispose();

    final db = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final row = (await db.select(db.examples).get()).single;
    expect(row.translation, isNull);
    expect(row.generated, isFalse);
  });
}
