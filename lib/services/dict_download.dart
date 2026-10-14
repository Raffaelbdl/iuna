import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../db/jmdict_lookup.dart';
import '../db/sqlite_open.dart';
import 'remote_asset.dart';

const _versionUrl = '$kIunaDataBase/jmdict.version';
const _gzUrl = '$kIunaDataBase/jmdict.sqlite.gz';

const _versionFileName = 'jmdict.version';

/// Downloads and manages the JMdict sidecar hosted on
/// `Raffaelbdl/iuna-data`. The sqlite file lives at
/// `<docs>/jmdict.sqlite` and is opened read-only by [JmdictLookup].
class DictDownload {
  DictDownload._();

  static Future<File> _sqliteFile() => documentsFile(kJmdictFileName);

  static Future<File> _versionFile() => documentsFile(_versionFileName);

  /// The download in progress, if any.
  static RemoteInstall? get current => _current;
  static RemoteInstall? _current;

  /// True when both the sqlite file and its version marker are on disk.
  static Future<bool> isInstalled() async {
    final (sqlite, version) = await (_sqliteFile(), _versionFile()).wait;
    return sqlite.existsSync() && version.existsSync();
  }

  /// On-disk size of the installed sqlite, or 0 if absent.
  static Future<int> installedSize() async {
    final f = await _sqliteFile();
    return f.existsSync() ? f.lengthSync() : 0;
  }

  /// Local version hash, or null if not installed.
  static Future<String?> localVersion() async {
    final f = await _versionFile();
    if (!f.existsSync()) return null;
    return f.readAsStringSync().trim();
  }

  /// Downloads + verifies + decompresses + installs, or joins the
  /// download already running. The new database is written beside the
  /// live one and renamed over it, so a kill mid-write leaves the old
  /// install intact; [JmdictLookup] reopens on its next lookup.
  static RemoteInstall install({http.Client? client}) {
    return _current ??= RemoteAsset.install<String>(
      url: _gzUrl,
      fetchHash: (c) async {
        final remote = await c.get(Uri.parse(_versionUrl));
        if (remote.statusCode != 200) {
          throw HttpException('version: HTTP ${remote.statusCode}');
        }
        return remote.body.trim();
      },
      client: client,
      decode: documentsFile('$kJmdictFileName.tmp').then((f) => _writeTo(f.path)),
      apply: (tmpPath, version) async {
        final marker = await _versionFile();
        if (marker.existsSync()) await marker.delete();
        JmdictLookup.instance.dispose();
        await File(tmpPath).rename((await _sqliteFile()).path);
        await marker.writeAsString('$version\n', flush: true);
      },
      onEnd: () => _current = null,
    );
  }

  // A closure over [path] alone, so it can be sent to the isolate.
  static String Function(Uint8List raw) _writeTo(String path) => (raw) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(raw, flush: true);
    return path;
  };

  /// Closes [JmdictLookup] (an open handle keeps the disk space
  /// claimed) and deletes the version marker, then the sqlite.
  static Future<void> uninstall() async {
    final (sqlite, version) = await (_sqliteFile(), _versionFile()).wait;
    if (version.existsSync()) version.deleteSync();
    JmdictLookup.instance.dispose();
    if (sqlite.existsSync()) sqlite.deleteSync();
  }
}
