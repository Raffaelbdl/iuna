import 'package:package_info_plus/package_info_plus.dart';

/// Stands in for the platform's package info, which widget tests lack.
void useFakePackageInfo({String version = '0.1.1'}) {
  PackageInfo.setMockInitialValues(
    appName: 'Iuna',
    packageName: 'io.github.raffaelbdl.iuna',
    version: version,
    buildNumber: '1',
    buildSignature: '',
  );
}
