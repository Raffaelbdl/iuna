// The update check: reading GitHub's release JSON, comparing versions,
// the sha256 gate on the APK, and the About tile's two outcomes.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iuna/screens/settings/about_section.dart';
import 'package:iuna/services/app_update.dart';
import 'package:iuna/services/remote_asset.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'helpers/fake_path_provider.dart';

const _latestUrl =
    'https://api.github.com/repos/Raffaelbdl/iuna/releases/latest';
const _apkUrl =
    'https://github.com/Raffaelbdl/iuna/releases/download/v0.2.0/iuna-v0.2.0.apk';

Map<String, dynamic> _release(String tag, {String? digest}) => {
  'tag_name': tag,
  'assets': [
    {
      'name': 'iuna-$tag.apk',
      'size': 68653010,
      'digest': ?digest,
      'browser_download_url': _apkUrl,
    },
  ],
};

const _digest =
    'sha256:ca133294287dcada9ebf20d2232852ed6597c719efc16970e087be35b4753086';

void main() {
  group('AppRelease.fromJson', () {
    test('reads the version, APK and digest', () {
      final r = AppRelease.fromJson(_release('v0.2.0', digest: _digest));
      expect(r.version, '0.2.0');
      expect(r.apkUrl, _apkUrl);
      expect(r.bytes, 68653010);
      expect(r.sha256, _digest.substring(7));
    });

    test('refuses an APK without a digest', () {
      expect(
        () => AppRelease.fromJson(_release('v0.2.0')),
        throwsFormatException,
      );
    });

    test('refuses a release without an APK', () {
      expect(
        () => AppRelease.fromJson({'tag_name': 'v0.2.0', 'assets': []}),
        throwsFormatException,
      );
    });
  });

  test('isNewerVersion compares X.Y.Z numerically', () {
    expect(isNewerVersion('0.1.10', '0.1.9'), isTrue);
    expect(isNewerVersion('0.2.0', '0.1.1+2'), isTrue);
    expect(isNewerVersion('1.0', '0.9.9'), isTrue);
    expect(isNewerVersion('0.1.1', '0.1.1'), isFalse);
    expect(isNewerVersion('0.1.1', '0.1.1+5'), isFalse);
    expect(isNewerVersion('0.1.0', '0.1.1'), isFalse);
  });

  group('RemoteAsset.downloadFile', () {
    final body = utf8.encode('not really an apk');
    final hex = sha256.convert(body).toString();
    http.Client client() =>
        MockClient((_) async => http.Response.bytes(body, 200));

    test('writes the file and applies once the hash matches', () async {
      final dir = Directory.systemTemp.createTempSync('iuna_update_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/updates/iuna.apk';
      var applied = false;
      final install = RemoteAsset.downloadFile(
        url: _apkUrl,
        path: path,
        sha256Hex: hex,
        client: client(),
        apply: () async => applied = true,
      );
      expect(await install.result, isNull);
      expect(File(path).readAsBytesSync(), body);
      expect(File('$path.part').existsSync(), isFalse);
      expect(applied, isTrue);
    });

    test('a hash mismatch leaves no file and never applies', () async {
      final dir = Directory.systemTemp.createTempSync('iuna_update_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/iuna.apk';
      var applied = false;
      final install = RemoteAsset.downloadFile(
        url: _apkUrl,
        path: path,
        sha256Hex: '0' * 64,
        client: client(),
        apply: () async => applied = true,
      );
      expect(await install.result, contains('integrity check failed'));
      expect(install.value.phase, RemotePhase.failed);
      expect(File(path).existsSync(), isFalse);
      expect(File('$path.part').existsSync(), isFalse);
      expect(applied, isFalse);
    });
  });

  group('AboutSection', () {
    setUp(() {
      useTempDocumentsDir('iuna_about_');
      PackageInfo.setMockInitialValues(
        appName: 'Iuna',
        packageName: 'io.github.raffaelbdl.iuna',
        version: '0.1.1',
        buildNumber: '2',
        buildSignature: '',
      );
    });

    Future<void> pump(WidgetTester tester, String latestTag) async {
      final client = MockClient((req) async {
        expect(req.url.toString(), _latestUrl);
        return http.Response(
          jsonEncode(_release(latestTag, digest: _digest)),
          200,
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AboutSection(updatable: true, client: client)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the installed version', (tester) async {
      await pump(tester, 'v0.1.1');
      expect(find.text('Version 0.1.1'), findsOneWidget);
    });

    testWidgets('says so when already on the latest release', (tester) async {
      await pump(tester, 'v0.1.1');
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.text('Iuna 0.1.1 is up to date.'), findsOneWidget);
    });

    testWidgets('offers a newer release before downloading', (tester) async {
      await pump(tester, 'v0.2.0');
      await tester.tap(find.text('Check for updates'));
      await tester.pumpAndSettle();
      expect(find.text('Update to 0.2.0?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(AppUpdate.current, isNull);
    });
  });
}
