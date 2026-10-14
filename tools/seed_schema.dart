// DDL for the seed sqlite asset, used by `build_dict.dart` and the
// importer test. Tracks the Drift schema in `lib/db/database.dart`
// loosely: a column the seed lacks (e.g. `user_cards.suspended`) is
// added by `onCreate`'s `_addColumnIfMissing` on first open.

import 'package:sqlite3/sqlite3.dart';

void createSchema(Database db) {
  db.execute('''
    CREATE TABLE cards (
      id          INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      kanji       TEXT NOT NULL,
      kana        TEXT NOT NULL,
      furigana    TEXT,
      meaning     TEXT NOT NULL,
      rarity      INTEGER NOT NULL DEFAULT 0,
      jlpt_level  INTEGER,
      audio_path  TEXT,
      image_path  TEXT,
      source      INTEGER NOT NULL DEFAULT 0,
      pack        TEXT,
      UNIQUE(kanji, kana)
    );
  ''');
  db.execute('''
    CREATE TABLE card_senses (
      id         INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      card_id    INTEGER NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
      ordinal    INTEGER NOT NULL,
      pos        TEXT NOT NULL DEFAULT '',
      gloss      TEXT NOT NULL,
      definition TEXT NOT NULL DEFAULT '',
      UNIQUE(card_id, ordinal)
    );
  ''');
  db.execute('''
    CREATE TABLE examples (
      id           INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      sentence     TEXT NOT NULL,
      source_title TEXT
    );
  ''');
  db.execute('''
    CREATE TABLE card_examples (
      card_id    INTEGER NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
      example_id INTEGER NOT NULL REFERENCES examples(id) ON DELETE CASCADE,
      PRIMARY KEY (card_id, example_id)
    );
  ''');
  db.execute('''
    CREATE TABLE user_cards (
      card_id          INTEGER NOT NULL PRIMARY KEY
                       REFERENCES cards(id) ON DELETE CASCADE,
      level            INTEGER NOT NULL DEFAULT 0,
      ease             REAL NOT NULL DEFAULT 2.0,
      interval_minutes INTEGER NOT NULL DEFAULT 0,
      last_reviewed    INTEGER,
      next_due         INTEGER NOT NULL,
      obtained_at      INTEGER NOT NULL,
      is_new           INTEGER NOT NULL DEFAULT 1,
      fail_count       INTEGER NOT NULL DEFAULT 0
    );
  ''');
  db.execute('''
    CREATE TABLE meta (
      "key" TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL
    );
  ''');
  db.execute('''
    CREATE TABLE wishlist (
      card_id  INTEGER NOT NULL PRIMARY KEY
               REFERENCES cards(id) ON DELETE CASCADE,
      added_at INTEGER NOT NULL
    );
  ''');
  db.execute('''
    CREATE TABLE daily_stats (
      date         TEXT NOT NULL PRIMARY KEY,
      c_total      INTEGER NOT NULL DEFAULT 0,
      c_correct    INTEGER NOT NULL DEFAULT 0,
      r_total      INTEGER NOT NULL DEFAULT 0,
      r_correct    INTEGER NOT NULL DEFAULT 0,
      sr_total     INTEGER NOT NULL DEFAULT 0,
      sr_correct   INTEGER NOT NULL DEFAULT 0,
      ssr_total    INTEGER NOT NULL DEFAULT 0,
      ssr_correct  INTEGER NOT NULL DEFAULT 0,
      ur_total     INTEGER NOT NULL DEFAULT 0,
      ur_correct   INTEGER NOT NULL DEFAULT 0,
      new_cards    INTEGER NOT NULL DEFAULT 0
    );
  ''');
  db.execute('''
    CREATE TABLE review_log (
      id                    INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      reviewed_at           INTEGER NOT NULL,
      prev_interval_minutes INTEGER NOT NULL,
      correct               INTEGER NOT NULL,
      rarity                INTEGER NOT NULL,
      kind                  INTEGER NOT NULL DEFAULT 1,
      duration_ms           INTEGER
    );
  ''');
}
