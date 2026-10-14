// Build `assets/db/jmdict.sqlite.gz` — full JMdict lookup sidecar for
// the experimental "Add card" flow. Unlike `build_dict.dart` (which
// filters down to ~30k learner-relevant cards), this keeps every JMdict
// entry so a user looking up a rare word will find it. The sidecar is
// gzipped and shipped as an asset; on first use the runtime
// decompresses it once into the app's documents dir and opens it
// read-only.
//
// Usage:
//   dart run tools/build_jmdict_sidecar.dart                       # canonical paths
//   dart run tools/build_jmdict_sidecar.dart --jmdict path.json    # local source
//   dart run tools/build_jmdict_sidecar.dart --limit 1000          # fast iteration
//
// Output:
//   tools/_build/jmdict.sqlite       # uncompressed working copy
//   assets/db/jmdict.sqlite.gz       # shipped artifact
//   assets/db/jmdict.version         # 16-hex-char sha256 of the .gz

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:iuna/core/deck_rules.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dict_importer.dart';

const _defaultBuildPath = 'tools/_build/jmdict.sqlite';
const _defaultGzPath = 'assets/db/jmdict.sqlite.gz';
const _defaultVersionPath = 'assets/db/jmdict.version';
const _defaultLicensePath = 'assets/db/jmdict.LICENSE.txt';

Future<void> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('jmdict',
        help: 'Path to JMdict source (.gz, .xml, or .json). '
            'Downloaded from EDRDG when missing and the path ends in .gz.',
        defaultsTo: kDefaultJmdictPath)
    ..addOption('tanos-dir',
        help: 'Directory with jlpt-n{1..5}.tsv (kanji<TAB>kana per line).',
        defaultsTo: kDefaultTanosDir)
    ..addOption('freq',
        help: 'Word-per-line frequency list. Line N is rank N (0-based).')
    ..addOption('out',
        help: 'Uncompressed sqlite working path.',
        defaultsTo: _defaultBuildPath)
    ..addOption('gz',
        help: 'Gzipped output path (the shipped asset).',
        defaultsTo: _defaultGzPath)
    ..addOption('version',
        help: 'Version-marker output path (sha256 of the .gz).',
        defaultsTo: _defaultVersionPath)
    ..addOption('license',
        help: 'CC-BY-SA 4.0 attribution text path.',
        defaultsTo: _defaultLicensePath)
    ..addOption('limit',
        help: 'Cap the number of imported entries (for fast iteration).')
    ..addFlag('help', abbr: 'h', negatable: false);

  late final ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(parser.usage);
    exitCode = 64;
    return;
  }
  if (args['help'] as bool) {
    stdout.writeln(parser.usage);
    return;
  }

  final jmdictPath = args['jmdict'] as String;
  final tanosDir = Directory(args['tanos-dir'] as String);
  final freqPath = args['freq'] as String?;
  final outPath = args['out'] as String;
  final gzPath = args['gz'] as String;
  final versionPath = args['version'] as String;
  final licensePath = args['license'] as String;
  final limit = int.tryParse(args['limit'] as String? ?? '');

  if (jmdictPath.endsWith('.gz') && !File(jmdictPath).existsSync()) {
    await ensureJmdictCached(jmdictPath);
  } else if (!File(jmdictPath).existsSync()) {
    stderr.writeln('JMdict source not found: $jmdictPath');
    exitCode = 66;
    return;
  }

  stdout.writeln('Loading Tanos JLPT data from ${tanosDir.path}...');
  final jlpt = await loadTanosJlpt(tanosDir);
  stdout.writeln('  ${jlpt.length} JLPT entries loaded.');

  final freq = freqPath == null
      ? const <String, int>{}
      : await loadFrequencyRanks(File(freqPath));
  if (freqPath != null) {
    stdout.writeln('  ${freq.length} frequency-ranked words loaded '
        'from $freqPath.');
  }

  final outFile = File(outPath);
  if (outFile.existsSync()) outFile.deleteSync();
  outFile.parent.createSync(recursive: true);
  final db = sqlite3.open(outPath);
  createJmdictSidecarSchema(db);

  final entries = openJmdictEntryStream(jmdictPath);
  final sw = Stopwatch()..start();
  final stats = await _importInto(
    db,
    entries,
    jlpt: jlpt,
    frequencyRanks: freq,
    limit: limit,
  );

  db.execute('VACUUM');
  // The runtime opens this read-only, but the build process leaves a
  // -wal sidecar behind that we don't want shipping in the gzip.
  db.execute('PRAGMA journal_mode = DELETE');
  db.dispose();
  sw.stop();

  final rawBytes = outFile.readAsBytesSync();
  final gzBytes = GZipCodec(level: 9).encode(rawBytes);
  final gzFile = File(gzPath);
  gzFile.parent.createSync(recursive: true);
  gzFile.writeAsBytesSync(gzBytes);

  final version = truncatedSha256(gzBytes);
  File(versionPath).writeAsStringSync('$version\n');

  File(licensePath).writeAsStringSync(_licenseText(
    version: version,
    builtAt: DateTime.now().toUtc(),
    hasJlpt: jlpt.isNotEmpty,
    hasFreq: freq.isNotEmpty,
  ));

  final rawMb = (rawBytes.length / 1024 / 1024).toStringAsFixed(1);
  final gzMb = (gzBytes.length / 1024 / 1024).toStringAsFixed(1);
  stdout.writeln('Wrote $outPath '
      '(${stats.entries} entries, $rawMb MB) '
      'in ${sw.elapsed.inSeconds}s.');
  stdout.writeln('Wrote $gzPath ($gzMb MB).');
  stdout.writeln('Wrote $versionPath ($version).');
  stdout.writeln('Wrote $licensePath.');
}

String _licenseText({
  required String version,
  required DateTime builtAt,
  required bool hasJlpt,
  required bool hasFreq,
}) {
  final iso = '${builtAt.toIso8601String().split('.').first}Z';
  final overlays = <String>[
    if (hasJlpt)
      'JLPT vocabulary tags from stephenmk/yomitan-jlpt-vocab '
          '(CC-BY-SA 4.0): https://github.com/stephenmk/yomitan-jlpt-vocab',
    if (hasFreq)
      'Frequency rankings from the internet-jp list by Serge Sharoff '
          '(University of Leeds), mirrored by hingston/japanese '
          '(CC BY 2.5): https://github.com/hingston/japanese',
  ];
  final overlaySection = overlays.isEmpty
      ? ''
      : '\nOverlay sources merged into this build:\n'
          '${overlays.map((s) => '  * $s').join('\n')}\n';
  return '''
jmdict.sqlite.gz — JMdict dictionary derivative

This file is a derivative of the JMdict dictionary file by James
William Breen and The Electronic Dictionary Research and Development
Group (EDRDG), distributed under the Creative Commons
Attribution-ShareAlike 4.0 International licence (CC-BY-SA 4.0).

  Original JMdict source:  https://www.edrdg.org/jmdict/j_jmdict.html
  EDRDG licence statement: https://www.edrdg.org/edrdg/licence.html
  CC-BY-SA 4.0:            https://creativecommons.org/licenses/by-sa/4.0/
$overlaySection
Modifications from the upstream sources:

  * Selected fields extracted (kanji, kana, senses, JLPT level,
    frequency rank) and re-encoded as a SQLite database.
  * Senses serialized as JSON arrays of {pos, gloss, def}.
  * Rarity precomputed (5-tier bucket) from priority tags + JLPT +
    frequency, stored as an integer per row.
  * Examples (Tatoeba sentences) and non-English glosses omitted.

This derivative inherits CC-BY-SA 4.0. Anyone redistributing this
file (or works derived from it) must keep this attribution and
licence the result under CC-BY-SA 4.0 as well.

Build hash: $version
Built:      $iso
''';
}

/// The sidecar's DDL, also used by the tests' synthetic sidecars.
void createJmdictSidecarSchema(Database db) {
  db.execute('''
    CREATE TABLE jmdict (
      kanji       TEXT NOT NULL,
      kana        TEXT NOT NULL,
      senses_json TEXT NOT NULL,
      rarity      INTEGER NOT NULL,
      jlpt_level  INTEGER,
      freq_rank   INTEGER,
      UNIQUE(kanji, kana)
    );
  ''');
  db.execute('CREATE INDEX idx_jmdict_kanji ON jmdict(kanji);');
  db.execute('CREATE INDEX idx_jmdict_kana ON jmdict(kana);');
}

class _Stats {
  int entries = 0;
  int skipped = 0;
}

Future<_Stats> _importInto(
  Database db,
  Stream<JmdictEntry> entries, {
  required Map<(String, String), int> jlpt,
  Map<String, int> frequencyRanks = const {},
  int? limit,
}) async {
  final stats = _Stats();
  final insert = db.prepare('''
    INSERT OR IGNORE INTO jmdict
      (kanji, kana, senses_json, rarity, jlpt_level, freq_rank)
    VALUES (?, ?, ?, ?, ?, ?)
  ''');

  db.execute('BEGIN');
  try {
    await for (final entry in entries) {
      final jlptLevel = jlpt[(entry.kanji, entry.kana)];
      final rank = frequencyRanks[entry.kanji] ??
          frequencyRanks[entry.kana];
      final rarity = rarityFor(
        priorityTags: entry.priorityTags,
        isCommon: entry.isCommon,
        frequencyRank: rank,
        jlptLevel: jlptLevel,
      );

      final senses = [
        for (final s in entry.senses)
          {
            'pos': posCsv(s.pos),
            'gloss': glossCsv(s.glosses),
            'def': buildDefinition(s),
          }
      ];

      insert.execute([
        entry.kanji,
        entry.kana,
        jsonEncode(senses),
        rarity.index,
        jlptLevel,
        rank,
      ]);
      if (db.updatedRows == 0) {
        stats.skipped++;
        continue;
      }
      stats.entries++;
      if (limit != null && stats.entries >= limit) break;
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }

  insert.dispose();
  if (stats.skipped > 0) {
    stdout.writeln('  ${stats.skipped} duplicate (kanji, kana) entries '
        'skipped.');
  }
  return stats;
}
