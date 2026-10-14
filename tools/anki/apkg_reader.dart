// Reads an Anki .apkg archive and exposes the embedded SQLite database.
//
// .apkg layout (Anki 2.1.50+):
//   collection.anki2     — legacy stub, mostly empty
//   collection.anki21b   — real data, zstd-compressed
//   meta                 — small marker indicating which to use
//   N                    — numbered media blobs (we ignore them)
//
// We shell out to `unzip` and `zstd` to avoid pulling pure-Dart zip and
// zstd implementations into the tree for a one-off CLI tool.
//
// Two collection schemas exist in the wild. Modern Anki (schema 18)
// normalises notetypes and decks into real tables; anything older keeps
// them as JSON blobs in `col.models` / `col.decks`. Shared decks
// exported years ago still ship the legacy shape, so both lookups fall
// back to the JSON blobs when the tables are absent.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

class ApkgReader {
  ApkgReader._(this._tempDir, this.db);

  final Directory _tempDir;
  final Database db;

  /// Opens [apkgPath], decompresses the modern collection database, and
  /// returns a reader holding the open SQLite handle. Caller must
  /// [close] when done.
  static Future<ApkgReader> open(String apkgPath) async {
    if (!await File(apkgPath).exists()) {
      throw ArgumentError('File not found: $apkgPath');
    }
    final tempDir =
        await Directory.systemTemp.createTemp('iuna_apkg_');

    try {
      await _run('unzip', ['-o', '-q', apkgPath, '-d', tempDir.path]);
    } catch (e) {
      await tempDir.delete(recursive: true);
      rethrow;
    }

    // Preference order matches Anki's own: the zstd-compressed
    // `anki21b` when present, then the uncompressed `anki21`, then the
    // `anki2` stub. Exports that carry an `anki21` leave `anki2` behind
    // as an almost-empty compatibility shell, so checking it first
    // would silently read a deck with no notes in it.
    final zstd = File(p.join(tempDir.path, 'collection.anki21b'));
    final plain = File(p.join(tempDir.path, 'collection.anki21'));
    final legacy = File(p.join(tempDir.path, 'collection.anki2'));
    final dbPath = p.join(tempDir.path, 'collection.sqlite');

    try {
      if (await zstd.exists()) {
        await _run('zstd', ['-d', '-f', '-q', zstd.path, '-o', dbPath]);
      } else if (await plain.exists()) {
        await plain.copy(dbPath);
      } else if (await legacy.exists()) {
        await legacy.copy(dbPath);
      } else {
        throw StateError(
          'apkg contains no collection.anki21b / .anki21 / .anki2',
        );
      }
      final db = sqlite3.open(dbPath);
      // Anki ships a custom `unicase` collation as part of its
      // executable; the schema declares some text columns with
      // `COLLATE unicase`. Stock libsqlite3 doesn't have it, so any
      // query touching such a column fails with "no such collation".
      // Register a binary fallback — the importer only does exact-
      // match lookups on these columns, so case-folded-vs-binary
      // doesn't matter for us.
      db.createCollation(
        name: 'unicase',
        function: (a, b) {
          if (a == null && b == null) return 0;
          if (a == null) return -1;
          if (b == null) return 1;
          return a.compareTo(b);
        },
      );
      return ApkgReader._(tempDir, db);
    } catch (e) {
      await tempDir.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> close() async {
    db.dispose();
    if (await _tempDir.exists()) {
      await _tempDir.delete(recursive: true);
    }
  }

  /// Numeric notetype id for a model with the given [name], or `null`
  /// if no matching model exists.
  int? noteTypeIdByName(String name) {
    for (final entry in noteTypes().entries) {
      if (entry.value == name) return entry.key;
    }
    return null;
  }

  /// Map of notetype id → name, from either the `notetypes` table or
  /// the legacy `col.models` JSON blob.
  Map<int, String> noteTypes() =>
      _idNameMap(table: 'notetypes', legacyColumn: 'models');

  /// Map of `decks.id → decks.name`. Cheap to call; results aren't
  /// cached so callers can do it once.
  Map<int, String> decks() =>
      _idNameMap(table: 'decks', legacyColumn: 'decks');

  bool _hasTable(String name) => db
      .select("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          [name])
      .isNotEmpty;

  Map<int, String> _idNameMap({
    required String table,
    required String legacyColumn,
  }) {
    final out = <int, String>{};
    if (_hasTable(table)) {
      for (final row in db.select('SELECT id, name FROM $table')) {
        out[row['id'] as int] = row['name'] as String;
      }
      return out;
    }
    final col = db.select('SELECT $legacyColumn FROM col LIMIT 1');
    if (col.isEmpty) return out;
    final decoded =
        jsonDecode(col.first[legacyColumn] as String) as Map<String, dynamic>;
    decoded.forEach((id, value) {
      final parsed = int.tryParse(id);
      final name = (value as Map<String, dynamic>)['name'];
      if (parsed != null && name is String) out[parsed] = name;
    });
    return out;
  }
}

Future<void> _run(String exe, List<String> args) async {
  final result = await Process.run(exe, args);
  if (result.exitCode != 0) {
    throw ProcessException(exe, args, result.stderr.toString(), result.exitCode);
  }
}
