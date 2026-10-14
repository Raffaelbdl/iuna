import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/services/drive_sync.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'helpers/fake_path_provider.dart';

List<int> _validIunaSnapshotBytes(String dirPath) {
  final tmp = File('$dirPath/_valid_seed.sqlite');
  if (tmp.existsSync()) tmp.deleteSync();
  final db = sql.sqlite3.open(tmp.path);
  try {
    db.execute('CREATE TABLE cards (id INTEGER PRIMARY KEY)');
    db.execute('CREATE TABLE user_cards (card_id INTEGER PRIMARY KEY)');
  } finally {
    db.dispose();
  }
  final bytes = tmp.readAsBytesSync();
  tmp.deleteSync();
  return bytes;
}

drive.DriveApi _api(MockClientHandler handler) =>
    drive.DriveApi(MockClient(handler));

void main() {
  late AppDatabase db;
  late IunaRepository repo;
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('iuna_drive_sync_');
    useDocumentsDir(tmpDir.path);
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IunaRepository(db);
  });

  tearDown(() async {
    await db.close();
    tmpDir.deleteSync(recursive: true);
  });

  test('listSnapshots parses files newest-first', () async {
    final api = _api((req) async {
      expect(req.method, 'GET');
      expect(req.url.queryParameters['spaces'], 'appDataFolder');
      expect(req.url.queryParameters['orderBy'], 'modifiedTime desc');
      return http.Response(
        jsonEncode({
          'files': [
            {
              'id': 'a',
              'name': 'iuna-20260428-120000.sqlite',
              'size': '100',
              'modifiedTime': '2026-04-28T12:00:00.000Z',
            },
            {
              'id': 'b',
              'name': 'iuna-20260427-120000.sqlite',
              'size': '200',
              'modifiedTime': '2026-04-27T12:00:00.000Z',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final sync = DriveSync(repo, apiProvider: () async => api);
    final snapshots = await sync.listSnapshots();
    expect(snapshots.length, 2);
    expect(snapshots.first.id, 'a');
    expect(snapshots.first.size, 100);
    expect(snapshots.first.modifiedTime?.toUtc(),
        DateTime.utc(2026, 4, 28, 12));
  });

  test('backup uploads multipart with appDataFolder parent and stamps meta',
      () async {
    File('${tmpDir.path}/$kDbFileName').writeAsBytesSync(
      List<int>.generate(64, (i) => i),
    );

    var requests = 0;
    String? capturedBody;
    final api = _api((req) async {
      requests++;
      if (requests == 1) {
        // files.create with multipart upload.
        capturedBody = req.body;
        expect(req.url.queryParameters['uploadType'], 'multipart');
        return http.Response(
          jsonEncode({
            'id': 'newid',
            'name': 'iuna-20260428-120000.sqlite',
            'size': '64',
            'modifiedTime': '2026-04-28T12:00:00.000Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      // Subsequent: list-for-prune.
      return http.Response(
        jsonEncode({'files': [{'id': 'newid'}]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final sync = DriveSync(repo, apiProvider: () async => api);
    final result = await sync.backup(now: DateTime.utc(2026, 4, 28, 12));
    expect(result, isA<BackupSucceeded>());
    expect((result as BackupSucceeded).snapshot.id, 'newid');

    // The multipart body must declare appDataFolder as the parent.
    expect(capturedBody, isNotNull);
    expect(capturedBody!, contains('appDataFolder'));

    // Meta timestamp is set after a successful upload.
    expect(
      (await repo.getLastDriveBackup())?.toUtc(),
      DateTime.utc(2026, 4, 28, 12),
    );
  });

  test('backup returns BackupNotSignedIn when api provider yields null',
      () async {
    final sync = DriveSync(repo, apiProvider: () async => null);
    final result = await sync.backup();
    expect(result, isA<BackupNotSignedIn>());
  });

  test('restoreFromSnapshot streams a valid sqlite into pending file',
      () async {
    final bytes = _validIunaSnapshotBytes(tmpDir.path);
    final api = _api((req) async {
      expect(req.url.queryParameters['alt'], 'media');
      return http.Response.bytes(
        bytes,
        200,
        headers: {'content-type': 'application/octet-stream'},
      );
    });
    final sync = DriveSync(repo, apiProvider: () async => api);
    final result = await sync.restoreFromSnapshot(
      const DriveSnapshot(id: 'snap-id', name: 'snap.sqlite'),
    );
    expect(result, isA<DriveRestoreStaged>());

    final pending = File('${tmpDir.path}/$kPendingRestoreFileName');
    expect(pending.existsSync(), isTrue);
    expect(pending.readAsBytesSync(), bytes);
  });

  test('restoreFromSnapshot rejects garbage bytes and deletes pending file',
      () async {
    final api = _api((req) async {
      // Six bytes — passes the size check but fails the SQLite magic
      // header. Mimics a truncated download or a non-sqlite file
      // somehow ending up in appDataFolder.
      return http.Response.bytes(
        const [0x53, 0x51, 0x4c, 0x69, 0x74, 0x65],
        200,
        headers: {'content-type': 'application/octet-stream'},
      );
    });
    final sync = DriveSync(repo, apiProvider: () async => api);
    final result = await sync.restoreFromSnapshot(
      const DriveSnapshot(id: 'snap-id', name: 'snap.sqlite'),
    );
    expect(result, isA<DriveRestoreFailed>());

    final pending = File('${tmpDir.path}/$kPendingRestoreFileName');
    expect(
      pending.existsSync(),
      isFalse,
      reason: 'rejected pending file must be cleaned up so the next '
          'launch does not swap garbage in',
    );
  });

  test('listSnapshots returns empty list when api provider yields null',
      () async {
    final sync = DriveSync(repo, apiProvider: () async => null);
    expect(await sync.listSnapshots(), isEmpty);
  });
}
