import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/sqlite_open.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Points `getApplicationDocumentsDirectory()` (and the temporary
/// directory) at [dir], where the app keeps its databases and the
/// JMdict sidecar.
void useDocumentsDir(String dir) {
  PathProviderPlatform.instance = _FakePathProvider(dir);
  debugResetDocumentsDir();
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.dir);
  final String dir;

  @override
  Future<String?> getApplicationDocumentsPath() async => dir;

  @override
  Future<String?> getTemporaryPath() async => dir;
}

/// A fresh temp directory as the documents directory, deleted when the
/// current test ends.
Directory useTempDocumentsDir(String prefix) {
  final dir = Directory.systemTemp.createTempSync(prefix);
  useDocumentsDir(dir.path);
  addTearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });
  return dir;
}
