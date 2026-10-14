// Build `assets/db/seed.sqlite` from a JMdict source plus optional
// JLPT and frequency overlays.
//
// Usage:
//   dart run tools/build_dict.dart                              # uses cache
//   dart run tools/build_dict.dart --limit 1000                 # fast subset
//   dart run tools/build_dict.dart --jmdict path.json           # local JSON
//   dart run tools/build_dict.dart --jmdict path.gz             # raw XML.gz
//   dart run tools/build_dict.dart --tanos-dir tanos/           # JLPT overlay
//   dart run tools/build_dict.dart --freq freq15k.txt           # rarity bands
//   dart run tools/build_dict.dart --include-untagged           # full dump
//
// Two source formats are supported, auto-detected from the file's
// extension:
//   * `.gz` / `.xml` — raw JMdict XML (e.g. `JMdict_e_examp.gz` from
//     EDRDG, CC-BY-SA 4.0).
//   * `.json` — scriptin/jmdict-simplified's pre-parsed JSON (same
//     upstream data, just easier to consume; same licence).
//
// The bundled seed inherits JMdict's CC-BY-SA 4.0 licence, surfaced in
// Settings → Data sources.

import 'dart:io';

import 'package:args/args.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dict_importer.dart';
import 'seed_schema.dart';

const _defaultOutPath = 'assets/db/seed.sqlite';
const _defaultExamplesPerCard = 3;

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
        help: 'Word-per-line frequency list. Line N is rank N (0-based). '
            'Used when no priority tag / JLPT level is available.')
    ..addOption('out',
        help: 'Output sqlite path.', defaultsTo: _defaultOutPath)
    ..addOption('limit',
        help: 'Cap the number of imported entries (for fast iteration).')
    ..addOption('examples-per-card',
        help: 'Max example sentences kept per card.',
        defaultsTo: '$_defaultExamplesPerCard')
    ..addFlag('include-untagged',
        help: 'Keep entries with no priority tag, no frequency rank, '
            'and no JLPT level. Multiplies the output size.',
        defaultsTo: false)
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
  final limit = int.tryParse(args['limit'] as String? ?? '');
  final examplesPerCard =
      int.tryParse(args['examples-per-card'] as String) ??
          _defaultExamplesPerCard;
  final includeUntagged = args['include-untagged'] as bool;

  // Only auto-download for the canonical raw-XML cache path; pointing
  // at any other file means "use exactly that".
  if (jmdictPath.endsWith('.gz')) {
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
  createSchema(db);

  final entries = openJmdictEntryStream(jmdictPath);
  final sw = Stopwatch()..start();
  final stats = await importInto(
    db,
    entries,
    jlpt: jlpt,
    frequencyRanks: freq,
    limit: limit,
    examplesPerCard: examplesPerCard,
    includeUntagged: includeUntagged,
  );

  db.execute('VACUUM');
  db.dispose();
  sw.stop();

  final sizeKb = (outFile.lengthSync() / 1024).round();
  stdout.writeln('Wrote $outPath '
      '(${stats.cards} cards, ${stats.senses} senses, '
      '${stats.examples} examples, $sizeKb KB) '
      'in ${sw.elapsed.inSeconds}s.');
}
