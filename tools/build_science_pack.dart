// Converts the shared "Science Terms" Anki deck into the card pack at
// `packs/science.json`.
//
// Usage:
//   dart run tools/build_science_pack.dart \
//     --apkg Japanese_Programming_Math_and_Science_Terms.apkg \
//     [--jmdict /path/to/jmdict.sqlite] [--out packs/science.json]
//
// Then `dart run tools/package_packs.dart` to gzip + manifest, and
// `tools/release_packs.sh` to publish. Packs are downloaded by the app,
// not bundled in the APK — see CLAUDE.md → Card packs.
//
// The deck carries no review history, so nothing here touches
// scheduling; the output is purely card definitions.
//
// Rarity comes from whatever corpus signal we can find, in order:
//   1. the seed deck's own row for this (kanji, kana)
//   2. the JMdict sidecar's precomputed rarity (`--jmdict`, optional;
//      decompress `assets/db/jmdict.sqlite.gz` first)
//   3. [kFallbackRarity] — specialist vocabulary that no frequency list
//      ranks at all.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:iuna/core/deck_rules.dart';
import 'package:iuna/core/pack_format.dart';
import 'package:sqlite3/sqlite3.dart';

import 'anki/apkg_reader.dart';
import 'anki/science_parser.dart';
import 'pack_format.dart';

const kPackName = 'science';
const kPackLabel = 'Science & Programming';
const kPackDescription =
    'Japanese for programming, mathematics and the sciences.';
final kFallbackRarity = Rarity.ssr.index;

/// Attribution for the upstream deck. Author and licence are left unset
/// on purpose: the AnkiWeb page is client-rendered and the `.apkg`
/// declares neither, so there is nothing to state truthfully. The deck's
/// own embedded description points at shared/info/113211889, an earlier
/// upload of the same deck.
const kSourceTitle = 'Japanese Programming, Math and Science Terms';
const kSourceUrl = 'https://ankiweb.net/shared/info/433387608';

Future<int> main(List<String> argv) async {
  final parser = ArgParser()
    ..addOption('apkg', help: 'Path to the Anki .apkg file', mandatory: true)
    ..addOption('out',
        defaultsTo: '$kPacksDir/$kPackName.json',
        help: 'Where to write the pack JSON.')
    ..addOption('source-url',
        defaultsTo: kSourceUrl,
        help: 'AnkiWeb (or other) page to credit as the deck source.')
    ..addOption('seed',
        defaultsTo: 'assets/db/seed.sqlite',
        help: 'Seed sqlite used to inherit rarity for known headwords.')
    ..addOption('jmdict',
        help: 'Optional uncompressed JMdict sidecar for rarity lookup.')
    ..addFlag('verbose',
        abbr: 'v',
        defaultsTo: false,
        help: 'List headwords where the expression and reading fields '
            'disagree.')
    ..addFlag('help', abbr: 'h', negatable: false);

  final ArgResults args;
  try {
    args = parser.parse(argv);
  } catch (e) {
    stderr.writeln(e);
    stderr.writeln(parser.usage);
    return 2;
  }
  if (args['help'] as bool) {
    stdout.writeln(parser.usage);
    return 0;
  }

  final reader = await ApkgReader.open(args['apkg'] as String);
  final lookups = <Database>[];
  try {
    final modelId = reader.noteTypeIdByName(kScienceModelName);
    if (modelId == null) {
      stderr.writeln('No "$kScienceModelName" notetype in this apkg.');
      stderr.writeln('Available notetypes: ${reader.noteTypes().values}');
      return 1;
    }

    for (final path in [args['seed'] as String?, args['jmdict'] as String?]) {
      if (path == null || !File(path).existsSync()) continue;
      lookups.add(sqlite3.open(path, mode: OpenMode.readOnly));
    }
    if (lookups.isEmpty) {
      stdout.writeln('No rarity source available — everything falls back.');
    }

    var fromCorpus = 0;
    final science = ScienceParser(
      reader.db,
      modelId: modelId,
      rarityResolver: (kanji, kana) {
        for (final db in lookups) {
          final hit = _lookupRarity(db, kanji, kana);
          if (hit != null) {
            fromCorpus++;
            return hit;
          }
        }
        return (rarity: kFallbackRarity, jlptLevel: null);
      },
    );

    final entries = science.parseAll();
    final stats = science.stats;
    if (entries.isEmpty) {
      stderr.writeln('Nothing parsed.');
      return 1;
    }

    // Two Anki notes can collapse onto the same headword once
    // synonyms are dropped; the pack is keyed by (kanji, kana).
    final byKey = <String, PackCard>{};
    for (final e in entries) {
      byKey.putIfAbsent('${e.kanji} ${e.kana}', () => e);
    }

    final payload = packDocument(
      name: kPackName,
      label: kPackLabel,
      description: kPackDescription,
      sourceTitle: kSourceTitle,
      sourceUrl: args['source-url'] as String,
      cards: [for (final e in byKey.values) e.toJson()],
    );

    final out = File(args['out'] as String);
    await out.parent.create(recursive: true);
    await out.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
      flush: true,
    );

    stdout.writeln('--- Pack built ---');
    stdout.writeln('  notes read        : ${stats.total}');
    stdout.writeln('  dropped           : ${stats.dropped}');
    stdout.writeln('  collapsed dupes   : ${entries.length - byKey.length}');
    stdout.writeln('  cards written     : ${byKey.length}');
    stdout.writeln('  senses            : ${stats.senses}');
    stdout.writeln('  headword mismatch : ${stats.headwordMismatch}');
    stdout.writeln('  rarity from corpus: $fromCorpus');
    stdout.writeln('  by rarity         : C=${stats.byRarity[0]} '
        'R=${stats.byRarity[1]} SR=${stats.byRarity[2]} '
        'SSR=${stats.byRarity[3]} UR=${stats.byRarity[4]}');
    stdout.writeln('  → ${out.path} (${await out.length()} bytes)');
    if (args['verbose'] as bool) {
      for (final m in stats.mismatches) {
        stdout.writeln('    mismatch: $m');
      }
    }
    return 0;
  } finally {
    for (final db in lookups) {
      db.dispose();
    }
    await reader.close();
  }
}

({int rarity, int? jlptLevel})? _lookupRarity(
  Database db,
  String kanji,
  String kana,
) {
  final table = _rarityTable(db);
  if (table == null) return null;
  final rows = db.select(
    'SELECT rarity, jlpt_level FROM $table WHERE kanji = ? AND kana = ? LIMIT 1',
    [kanji, kana],
  );
  if (rows.isEmpty) return null;
  return (
    rarity: rows.first['rarity'] as int,
    jlptLevel: rows.first['jlpt_level'] as int?,
  );
}

final _rarityTableCache = <Database, String?>{};

String? _rarityTable(Database db) => _rarityTableCache.putIfAbsent(db, () {
      for (final name in ['cards', 'jmdict']) {
        final hit = db.select(
          "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?",
          [name],
        );
        if (hit.isNotEmpty) return name;
      }
      return null;
    });
