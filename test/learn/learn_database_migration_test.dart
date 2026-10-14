import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/learn/db/learn_database.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

void main() {
  test('a v1 database gains messages.kind and keeps its rows', () async {
    final dir = Directory.systemTemp.createTempSync('iuna_learn_v1_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/learn.sqlite');

    // The v1 messages table, as the first release created it.
    final raw = sql.sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE messages (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        tool_calls TEXT NULL,
        tool_call_id TEXT NULL,
        tool_name TEXT NULL,
        archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
        created_at INTEGER NOT NULL
      )''');
    raw.execute(
      "INSERT INTO messages (session_id, role, content, created_at) VALUES (1, 'note', 'hello', 0)",
    );
    raw.execute('PRAGMA user_version = 1');
    raw.dispose();

    final db = LearnDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final rows = await db.select(db.messages).get();
    expect(rows.single.content, 'hello');
    expect(rows.single.kind, isNull);
    expect(rows.single.attachments, isNull);
  });

  test('a v2 database gains messages.attachments and keeps its rows', () async {
    final dir = Directory.systemTemp.createTempSync('iuna_learn_v2_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/learn.sqlite');

    // The v2 messages table: v1 plus `kind`, before photos existed.
    final raw = sql.sqlite3.open(file.path);
    raw.execute('''
      CREATE TABLE messages (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        tool_calls TEXT NULL,
        tool_call_id TEXT NULL,
        tool_name TEXT NULL,
        kind TEXT NULL,
        archived INTEGER NOT NULL DEFAULT 0 CHECK (archived IN (0, 1)),
        created_at INTEGER NOT NULL
      )''');
    raw.execute(
      "INSERT INTO messages (session_id, role, content, kind, created_at) "
      "VALUES (1, 'note', 'hello', 'kickoff', 0)",
    );
    raw.execute('PRAGMA user_version = 2');
    raw.dispose();

    final db = LearnDatabase.forTesting(NativeDatabase(file));
    addTearDown(db.close);
    final rows = await db.select(db.messages).get();
    expect(rows.single.kind, 'kickoff');
    expect(rows.single.attachments, isNull);
  });
}
