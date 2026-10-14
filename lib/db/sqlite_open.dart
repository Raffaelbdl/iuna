import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

Future<Directory>? _documentsDir;

/// `<docs>/[name]`. The directory is looked up once per process: on
/// Android each lookup is a platform-channel round trip.
Future<File> documentsFile(String name) async {
  final dir = await (_documentsDir ??= getApplicationDocumentsDirectory()
      .catchError((Object e, StackTrace st) {
    _documentsDir = null;
    Error.throwWithStackTrace(e, st);
  }));
  return File(p.join(dir.path, name));
}

@visibleForTesting
void debugResetDocumentsDir() => _documentsDir = null;

/// A consistent copy of [db] at [target], which must not exist yet,
/// even while other writes land: `VACUUM INTO` reads in one
/// transaction.
Future<void> vacuumInto(DatabaseConnectionUser db, File target) =>
    db.customStatement('VACUUM INTO ?', [target.path]);

/// Opens `<docs>/[fileName]`. A restore stages its snapshot as
/// [pendingFileName]; it is swapped in here, before Drift holds the file,
/// because replacing it under a live connection is not safe. [seed]
/// creates the file on first launch.
LazyDatabase openDocumentsDatabase(
  String fileName, {
  required String pendingFileName,
  Future<void> Function(File target)? seed,
}) {
  return LazyDatabase(() async {
    final file = await documentsFile(fileName);
    final pending = await documentsFile(pendingFileName);

    if (await pending.exists()) {
      await pending.copy(file.path);
      await pending.delete();
    } else if (seed != null && !await file.exists()) {
      await seed(file);
    }

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    // Process-wide, and set by whichever database opens first.
    sqlite3.tempDirectory = (await getTemporaryDirectory()).path;

    return NativeDatabase.createInBackground(file);
  });
}

/// A database a restore can replace: the snapshot is staged as
/// [pendingFileName] and swapped in by the next [openDocumentsDatabase].
class SnapshotSpec {
  const SnapshotSpec({
    required this.pendingFileName,
    required this.requiredTables,
    required this.description,
  });

  final String pendingFileName;
  final List<String> requiredTables;

  /// How a rejected restore names what it expected.
  final String description;

  Future<File> pendingFile() => documentsFile(pendingFileName);

  /// Null when [file] is a SQLite 3 database holding every one of
  /// [requiredTables]; otherwise why not.
  Future<String?> validate(File file) => _validateSnapshot(
    file,
    tables: requiredTables,
    description: description,
  );
}

Future<String?> _validateSnapshot(
  File file, {
  required List<String> tables,
  required String description,
}) async {
  if (!await file.exists()) return 'File not found.';

  final raf = await file.open();
  try {
    if (await raf.length() < 16) {
      return 'File too small to be a SQLite database.';
    }
    final header = await raf.read(16);
    const expected = [
      0x53, 0x51, 0x4C, 0x69, 0x74, 0x65, 0x20, 0x66, // "SQLite f"
      0x6F, 0x72, 0x6D, 0x61, 0x74, 0x20, 0x33, 0x00, // "ormat 3\0"
    ];
    for (var i = 0; i < expected.length; i++) {
      if (header[i] != expected[i]) {
        return 'Not a SQLite 3 database.';
      }
    }
  } finally {
    await raf.close();
  }

  Database? probe;
  try {
    probe = sqlite3.open(file.path, mode: OpenMode.readOnly);
    final placeholders = List.filled(tables.length, '?').join(', ');
    final rows = probe.select(
      "SELECT name FROM sqlite_master WHERE type='table' AND name IN ($placeholders)",
      tables,
    );
    if (rows.length < tables.length) {
      final names = tables.map((t) => '`$t`').join(' and ');
      return "Doesn't look like $description — expected $names tables.";
    }
  } on SqliteException catch (e) {
    return 'Could not open file as SQLite: ${e.message}';
  } finally {
    probe?.dispose();
  }

  return null;
}
