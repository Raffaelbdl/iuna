import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/learn/db/learn_database.dart';
import 'package:iuna/learn/db/learn_repository.dart';
import 'package:iuna/learn/learn_backup.dart';
import 'package:iuna/services/drive_sync.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import '../helpers/fake_path_provider.dart';

http.Response _json(Object body) => http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );

List<int> _sqliteWithTables(String dir, List<String> tables) {
  final f = File('$dir/_probe.sqlite');
  if (f.existsSync()) f.deleteSync();
  final db = sql.sqlite3.open(f.path);
  for (final t in tables) {
    db.execute('CREATE TABLE $t (id INTEGER PRIMARY KEY)');
  }
  db.dispose();
  final bytes = f.readAsBytesSync();
  f.deleteSync();
  return bytes;
}

/// Records what a DriveApi was asked to do; [files] is what `list` sees.
class _FakeDrive {
  _FakeDrive({this.files = const []});

  final List<Map<String, String>> files;
  final uploads = <String>[];
  final deleted = <String>[];
  List<int>? downloadBytes;

  drive.DriveApi get api => drive.DriveApi(MockClient((req) async {
        if (req.method == 'POST') {
          final body = latin1.decode(req.bodyBytes);
          uploads.add(body);
          final name = RegExp(r'"name":"([^"]+)"').firstMatch(body)!.group(1)!;
          return _json({'id': 'new', 'name': name, 'size': '${req.bodyBytes.length}'});
        }
        if (req.method == 'DELETE') {
          deleted.add(req.url.pathSegments.last);
          return http.Response('', 204);
        }
        if (req.url.queryParameters['alt'] == 'media') {
          return http.Response.bytes(downloadBytes!, 200,
              headers: {'content-type': 'application/octet-stream'});
        }
        return _json({'files': files});
      }));
}

void main() {
  late Directory tmp;
  late AppDatabase deckDb;
  late IunaRepository deck;
  late LearnDatabase learnDb;
  late LearnRepository learn;
  var clock = DateTime(2026, 9, 10, 9);

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('iuna_learn_backup_');
    useDocumentsDir(tmp.path);
    deckDb = AppDatabase.forTesting(NativeDatabase.memory());
    deck = IunaRepository(deckDb);
    learnDb = LearnDatabase.forTesting(NativeDatabase.memory());
    clock = DateTime(2026, 9, 10, 9);
    learn = LearnRepository(learnDb, clock: () => clock);
  });

  tearDown(() async {
    await learn.dispose();
    await learnDb.close();
    await deckDb.close();
    tmp.deleteSync(recursive: true);
  });

  test('courses never used: nothing uploaded, Drive not even asked', () async {
    var asked = false;
    final sync = DriveSync(deck, apiProvider: () async {
      asked = true;
      return null;
    });
    expect(await sync.backupSource(CourseSnapshots(learn)), isA<BackupUnchanged>());
    expect(asked, isFalse);
  });

  test('changed courses upload once as iuna-learn-…, then are skipped', () async {
    await learn.createCourse(title: 'JLPT N1');
    final fake = _FakeDrive();
    final sync = DriveSync(deck, apiProvider: () async => fake.api);

    final stamp = DateTime(2026, 9, 10, 12);
    final first = await sync.backupSource(CourseSnapshots(learn), now: stamp);
    expect(first, isA<BackupSucceeded>());
    expect(fake.uploads.single, contains('iuna-learn-20260910-120000.sqlite'));
    expect(fake.uploads.single, contains('appDataFolder'));
    // googleapis base64-encodes multipart media; this is "SQLite format 3".
    expect(fake.uploads.single, contains('U1FMaXRlIGZvcm1hdCAz'),
        reason: 'the VACUUM INTO copy is what gets uploaded');
    expect(tmp.listSync().where((f) => f.path.contains('upload')), isEmpty,
        reason: 'the temporary copy is deleted after the upload');
    expect(await learn.getLastDriveBackup(), stamp);

    expect(await sync.backupSource(CourseSnapshots(learn), now: stamp.add(const Duration(hours: 1))),
        isA<BackupUnchanged>());
    expect(fake.uploads, hasLength(1));

    clock = DateTime(2026, 9, 10, 14);
    await learn.addPreference('prefers example-first');
    expect(await sync.backupSource(CourseSnapshots(learn), now: DateTime(2026, 9, 10, 15)),
        isA<BackupSucceeded>());
    expect(fake.uploads, hasLength(2));
  });

  test('retention keeps seven per family: course uploads never evict the library',
      () async {
    await learn.createCourse(title: 'Keigo');
    final files = [
      for (var i = 0; i < 9; i++) {'id': 'learn$i', 'name': 'iuna-learn-2026090$i-000000.sqlite'},
      for (var i = 0; i < 9; i++) {'id': 'lib$i', 'name': 'iuna-2026090$i-000000.sqlite'},
    ];
    final fake = _FakeDrive(files: files);
    final sync = DriveSync(deck, apiProvider: () async => fake.api);
    await sync.backupSource(CourseSnapshots(learn), now: DateTime(2026, 9, 10, 12));
    expect(fake.deleted, ['learn7', 'learn8']);
  });

  test('each family lists only its own snapshots', () async {
    final fake = _FakeDrive(files: [
      {'id': 'a', 'name': 'iuna-20260910-120000.sqlite'},
      {'id': 'b', 'name': 'iuna-learn-20260910-120000.sqlite'},
    ]);
    final sync = DriveSync(deck, apiProvider: () async => fake.api);
    expect((await sync.listSnapshots()).map((s) => s.id), ['a']);
    expect((await sync.listSnapshots(artifact: kCoursesArtifact)).map((s) => s.id), ['b']);
  });

  test('a courses restore stages learn.sqlite.pending and refuses a library file',
      () async {
    final fake = _FakeDrive()..downloadBytes = _sqliteWithTables(tmp.path, ['courses', 'chapters']);
    final sync = DriveSync(deck, apiProvider: () async => fake.api);
    const snap = DriveSnapshot(id: 'b', name: 'iuna-learn-20260910-120000.sqlite');

    expect(await sync.restoreFromSnapshot(snap, artifact: kCoursesArtifact),
        isA<DriveRestoreStaged>());
    final pending = File('${tmp.path}/$kLearnPendingRestoreFileName');
    expect(pending.existsSync(), isTrue);
    expect(File('${tmp.path}/$kPendingRestoreFileName').existsSync(), isFalse,
        reason: 'the library side-car must not be touched');
    pending.deleteSync();

    fake.downloadBytes = _sqliteWithTables(tmp.path, ['cards', 'user_cards']);
    expect(await sync.restoreFromSnapshot(snap, artifact: kCoursesArtifact),
        isA<DriveRestoreFailed>());
    expect(pending.existsSync(), isFalse);
  });

  test('backupAll adds courses only after a successful library upload', () async {
    File('${tmp.path}/$kDbFileName').writeAsBytesSync(List<int>.generate(64, (i) => i));
    await learn.createCourse(title: 'N2');
    final fake = _FakeDrive();
    final sync = DriveSync(deck, apiProvider: () async => fake.api);

    final both = await sync.backupAll(alongside: CourseSnapshots(learn), now: DateTime(2026, 9, 10, 12));
    expect(both.library, isA<BackupSucceeded>());
    expect(both.alongside, isA<BackupSucceeded>());
    expect(backupMessage(both, alongside: CourseSnapshots(learn)), 'Backed up library and courses · just now');

    final again = await sync.backupAll(alongside: CourseSnapshots(learn), now: DateTime(2026, 9, 10, 13));
    expect(again.alongside, isA<BackupUnchanged>());
    expect(backupMessage(again, alongside: CourseSnapshots(learn)), 'Backed up · just now');

    final signedOut = await DriveSync(deck, apiProvider: () async => null).backupAll(alongside: CourseSnapshots(learn));
    expect(signedOut.alongside, isNull);
    expect(backupMessage(signedOut, quietWhenSignedOut: true), isNull);
  });
}
