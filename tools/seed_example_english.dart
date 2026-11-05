// Add Tatoeba's English to the example sentences of an existing seed,
// without rebuilding it (a rebuild needs the JLPT and frequency inputs
// too). `build_dict.dart` writes the English itself; this patches a seed
// built before it did.
//
// Usage:
//   dart run tools/seed_example_english.dart
//   dart run tools/seed_example_english.dart --jmdict path.gz --seed path

import 'dart:io';

import 'package:args/args.dart';
import 'package:sqlite3/sqlite3.dart';

import 'dict_importer.dart';

Future<void> main(List<String> argv) async {
  final args = (ArgParser()
        ..addOption('jmdict',
            help: 'JMdict XML with examples (.gz).', defaultsTo: kDefaultJmdictPath)
        ..addOption('seed', help: 'Seed sqlite to patch.', defaultsTo: 'assets/db/seed.sqlite'))
      .parse(argv);
  final jmdictPath = args['jmdict'] as String;
  final seedPath = args['seed'] as String;

  await ensureJmdictCached(jmdictPath);
  final english = <String, String>{};
  await for (final entry in openJmdictEntryStream(jmdictPath)) {
    english.addAll(entry.exampleEnglish);
  }
  stdout.writeln('${english.length} English sentences in $jmdictPath.');

  final db = sqlite3.open(seedPath);
  try {
    // The app's onCreate adds `generated` on first open; only the column
    // written here is needed now.
    final columns = {for (final r in db.select('PRAGMA table_info(examples)')) r['name']};
    if (!columns.contains('translation')) {
      db.execute('ALTER TABLE examples ADD COLUMN translation TEXT');
    }

    final update = db.prepare('UPDATE examples SET translation = ? WHERE id = ?');
    var filled = 0;
    db.execute('BEGIN');
    for (final row in db.select('SELECT id, sentence FROM examples WHERE translation IS NULL')) {
      final en = english[row['sentence'] as String];
      if (en == null) continue;
      update.execute([en, row['id']]);
      filled++;
    }
    db.execute('COMMIT');
    update.dispose();
    db.execute('VACUUM');

    final total = db.select('SELECT COUNT(*) AS n FROM examples').first['n'];
    stdout.writeln('Filled $filled of $total examples in $seedPath.');
  } finally {
    db.dispose();
  }
}
