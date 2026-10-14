// Gzips every pack in `packs/*.json` into `packs/dist/` and writes the
// `packs.json` catalogue the app fetches.
//
// Usage:
//   dart run tools/package_packs.dart
//   tools/release_packs.sh          # push dist/ to Raffaelbdl/iuna-data
//
// The `packs/*.json` sources are committed — they're the reviewable
// record of what's published, and a parser change shows up as a real
// diff. `packs/dist/` is generated and gitignored, same arrangement as
// the JMdict sidecar.
//
// The catalogue's `version` for each pack is the truncated sha256 of
// its gzipped payload. The app verifies downloads against it and
// compares it with the installed version to offer updates, so it must
// be recomputed whenever a pack is rebuilt.

import 'dart:convert';
import 'dart:io';

import 'package:iuna/core/deck_rules.dart';
import 'package:iuna/core/pack_format.dart';

import 'pack_format.dart';

Future<int> main(List<String> argv) async {
  final srcDir = Directory(kPacksDir);
  if (!srcDir.existsSync()) {
    stderr.writeln('No $kPacksDir/ directory — nothing to package.');
    return 1;
  }

  final sources = srcDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (sources.isEmpty) {
    stderr.writeln('No pack sources in $kPacksDir/.');
    return 1;
  }

  final dist = Directory(kPacksDistDir);
  await dist.create(recursive: true);

  final entries = <Map<String, dynamic>>[];
  for (final src in sources) {
    final doc = jsonDecode(await src.readAsString()) as Map<String, dynamic>;
    final format = doc['format'];
    if (format != kPackFormatVersion) {
      stderr.writeln(
        '${src.path}: format $format, expected $kPackFormatVersion — '
        'rebuild it before packaging.',
      );
      return 1;
    }
    final name = doc['pack'] as String;

    // Compact on the wire; the pretty source stays in git for review.
    final raw = utf8.encode(jsonEncode(doc));
    final gz = gzip.encode(raw);
    final version = truncatedSha256(gz);

    final out = File('$kPacksDistDir/$name.json.gz');
    await out.writeAsBytes(gz, flush: true);

    entries.add(manifestEntry(doc, version: version));
    stdout.writeln(
      '  $name  ${(doc['cards'] as List).length} cards  '
      '${raw.length} → ${gz.length} bytes  $version',
    );
  }

  final manifest = File('$kPacksDistDir/packs.json');
  await manifest.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'format': kPackFormatVersion,
      'packs': entries,
    }),
    flush: true,
  );

  stdout.writeln('--- Packaged ${entries.length} pack(s) ---');
  stdout.writeln('  → ${manifest.path}');
  stdout.writeln('Publish with tools/release_packs.sh');
  return 0;
}
