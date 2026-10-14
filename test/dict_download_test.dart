import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iuna/core/deck_rules.dart';
import 'package:iuna/services/dict_download.dart';
import 'package:iuna/services/remote_asset.dart';
import 'package:sqlite3/sqlite3.dart';

import 'helpers/fake_path_provider.dart';

const _versionUrl = '$kIunaDataBase/jmdict.version';
const _gzUrl = '$kIunaDataBase/jmdict.sqlite.gz';

({Uint8List gz, String hash}) _buildFixtureGz(Directory tmp) {
  final path = '${tmp.path}/_fixture.sqlite';
  final db = sqlite3.open(path);
  db.execute('CREATE TABLE jmdict (kanji TEXT, kana TEXT)');
  db.execute("INSERT INTO jmdict VALUES ('a', 'b')");
  db.execute('VACUUM');
  db.dispose();
  final raw = File(path).readAsBytesSync();
  File(path).deleteSync();
  final gz = Uint8List.fromList(gzip.encode(raw));
  final hash = truncatedSha256(gz);
  return (gz: gz, hash: hash);
}

/// Every progress value [install] reports, through to its end.
Future<List<RemoteProgress>> _events(RemoteInstall install) async {
  final events = [install.value];
  install.addListener(() => events.add(install.value));
  await install.result;
  return events;
}

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('iuna_dict_download_');
    useDocumentsDir(tmpDir.path);
  });

  tearDown(() {
    tmpDir.deleteSync(recursive: true);
  });

  test('isInstalled / localVersion are false / null on a fresh dir',
      () async {
    expect(await DictDownload.isInstalled(), isFalse);
    expect(await DictDownload.localVersion(), isNull);
    expect(await DictDownload.installedSize(), 0);
  });

  test('install happy path writes sqlite + version atomically', () async {
    final fixture = _buildFixtureGz(tmpDir);
    final client = MockClient((req) async {
      if (req.url.toString() == _versionUrl) {
        return http.Response('${fixture.hash}\n', 200);
      }
      if (req.url.toString() == _gzUrl) {
        return http.Response.bytes(fixture.gz, 200);
      }
      return http.Response('not found', 404);
    });

    final install = DictDownload.install(client: client);
    expect(DictDownload.install(client: client), same(install),
        reason: 'a second request joins the running download');
    final phases = [for (final p in await _events(install)) p.phase];

    expect(phases.first, RemotePhase.fetchingVersion);
    expect(phases.last, RemotePhase.done);
    expect(phases, contains(RemotePhase.downloading));
    expect(phases, contains(RemotePhase.verifying));
    expect(phases, isNot(contains(RemotePhase.failed)));

    expect(await DictDownload.isInstalled(), isTrue);
    expect(await DictDownload.localVersion(), fixture.hash);
    expect(await DictDownload.installedSize(), greaterThan(0));
    expect(File('${tmpDir.path}/jmdict.sqlite.tmp').existsSync(), isFalse);
    expect(DictDownload.current, isNull);
  });

  test('install fails when sha256 of the .gz disagrees with .version',
      () async {
    final fixture = _buildFixtureGz(tmpDir);
    final client = MockClient((req) async {
      if (req.url.toString() == _versionUrl) {
        return http.Response('deadbeefdeadbeef\n', 200);
      }
      if (req.url.toString() == _gzUrl) {
        return http.Response.bytes(fixture.gz, 200);
      }
      return http.Response('', 404);
    });

    final failure = (await _events(DictDownload.install(client: client)))
        .where((p) => p.phase == RemotePhase.failed)
        .firstOrNull;

    expect(failure, isNotNull);
    expect(failure!.error, contains('integrity check failed'));
    expect(await DictDownload.isInstalled(), isFalse,
        reason: 'failed install must not leave partial files behind');
  });

  test('install fails cleanly when version endpoint returns 404',
      () async {
    final client = MockClient((req) async => http.Response('nope', 404));

    final failure = (await _events(DictDownload.install(client: client)))
        .where((p) => p.phase == RemotePhase.failed)
        .firstOrNull;

    expect(failure, isNotNull);
    expect(failure!.error, contains('version: HTTP 404'));
    expect(await DictDownload.isInstalled(), isFalse);
  });

  test('uninstall removes both files', () async {
    File('${tmpDir.path}/jmdict.sqlite').writeAsBytesSync(const [1, 2, 3]);
    File('${tmpDir.path}/jmdict.version').writeAsStringSync('hash\n');
    expect(await DictDownload.isInstalled(), isTrue);

    await DictDownload.uninstall();
    expect(await DictDownload.isInstalled(), isFalse);
    expect(File('${tmpDir.path}/jmdict.sqlite').existsSync(), isFalse);
    expect(File('${tmpDir.path}/jmdict.version').existsSync(), isFalse);
  });
}
