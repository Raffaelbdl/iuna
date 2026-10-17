import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'remote_asset.dart';

const _latestUrl =
    'https://api.github.com/repos/Raffaelbdl/iuna/releases/latest';

/// The newest GitHub Release, as `.github/workflows/release.yml`
/// publishes it: a `vX.Y.Z` tag with one release-signed APK attached.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.apkUrl,
    required this.bytes,
    required this.sha256,
  });

  /// Throws [FormatException] when the release has no APK, or GitHub
  /// gave the APK no sha256 digest.
  factory AppRelease.fromJson(Map<String, dynamic> json) {
    final tag = json['tag_name'] as String? ?? '';
    final assets = (json['assets'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final apk = assets
        .where((a) => (a['name'] as String? ?? '').endsWith('.apk'))
        .firstOrNull;
    if (apk == null) throw FormatException('release $tag has no APK');
    final digest = apk['digest'] as String? ?? '';
    if (!digest.startsWith('sha256:')) {
      throw FormatException('release $tag: APK has no sha256 digest');
    }
    return AppRelease(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      apkUrl: apk['browser_download_url'] as String,
      bytes: apk['size'] as int? ?? 0,
      sha256: digest.substring('sha256:'.length),
    );
  }

  /// `X.Y.Z`, without the tag's `v`.
  final String version;
  final String apkUrl;
  final int bytes;
  final String sha256;
}

/// True when [remote] is a later `X.Y.Z` than [local].
bool isNewerVersion(String remote, String local) {
  List<int> parts(String v) =>
      v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final r = parts(remote);
  final l = parts(local);
  for (var i = 0; i < r.length || i < l.length; i++) {
    final a = i < r.length ? r[i] : 0;
    final b = i < l.length ? l[i] : 0;
    if (a != b) return a > b;
  }
  return false;
}

/// Settings → Check for updates: finds the latest GitHub Release,
/// downloads its APK into the cache and hands it to Android's package
/// installer, which asks the learner to confirm. Being signed with the
/// same key, the new APK upgrades in place and keeps both databases.
class AppUpdate {
  AppUpdate._();

  static const _channel = MethodChannel('io.github.raffaelbdl.iuna/update');

  static bool get supported => Platform.isAndroid;

  /// The download in progress, if any.
  static RemoteInstall? get current => _current;
  static RemoteInstall? _current;

  /// The latest release when it is newer than [installed], else null.
  static Future<AppRelease?> check(
    String installed, {
    http.Client? client,
  }) async {
    final release = await _latest(client);
    return isNewerVersion(release.version, installed) ? release : null;
  }

  static Future<AppRelease> _latest(http.Client? client) async {
    final c = client ?? http.Client();
    try {
      final resp = await c.get(
        Uri.parse(_latestUrl),
        headers: {'Accept': 'application/vnd.github+json'},
      );
      if (resp.statusCode != 200) {
        throw HttpException('releases: HTTP ${resp.statusCode}');
      }
      return AppRelease.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
    } finally {
      if (client == null) c.close();
    }
  }

  static Future<File> _apkFile() async =>
      File(p.join((await getTemporaryDirectory()).path, 'updates', 'iuna.apk'));

  /// Downloads and verifies [release]'s APK, then opens the installer;
  /// or joins the download already running.
  static Future<RemoteInstall> download(
    AppRelease release, {
    http.Client? client,
  }) async {
    final apk = await _apkFile();
    return _current ??= RemoteAsset.downloadFile(
      url: release.apkUrl,
      path: apk.path,
      sha256Hex: release.sha256,
      client: client,
      apply: () =>
          _channel.invokeMethod<void>('installApk', {'path': apk.path}),
      onEnd: () => _current = null,
    );
  }

  /// Deletes an APK left from an earlier update; called once at launch.
  /// The installer copies the APK before it installs, so by then it's
  /// dead weight.
  static Future<void> clearDownloaded() async {
    try {
      await (await _apkFile()).parent.delete(recursive: true);
    } on PathNotFoundException {
      // Nothing downloaded.
    }
  }
}
