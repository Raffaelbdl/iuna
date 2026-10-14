import 'dart:convert';
import 'dart:io';

import 'package:iuna/core/deck_rules.dart';
import 'package:iuna/db/jmdict_lookup.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../tools/build_jmdict_sidecar.dart' show createJmdictSidecarSchema;

/// One headword for [writeTestSidecar].
class SidecarEntry {
  const SidecarEntry({
    required this.kanji,
    required this.kana,
    required this.senses,
    required this.rarity,
    this.jlptLevel,
    this.freqRank,
  });

  final String kanji;
  final String kana;
  final List<JmdictSense> senses;
  final Rarity rarity;
  final int? jlptLevel;
  final int? freqRank;
}

/// Writes a JMdict sidecar with the real build schema at [path],
/// replacing any file already there.
void writeTestSidecar(String path, List<SidecarEntry> entries) {
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  final db = sqlite3.open(path);
  createJmdictSidecarSchema(db);
  final ins = db.prepare('''
    INSERT INTO jmdict (kanji, kana, senses_json, rarity, jlpt_level, freq_rank)
    VALUES (?, ?, ?, ?, ?, ?)
  ''');
  for (final e in entries) {
    ins.execute([
      e.kanji,
      e.kana,
      jsonEncode([
        for (final s in e.senses) {'pos': s.pos, 'gloss': s.gloss, 'def': s.def},
      ]),
      e.rarity.index,
      e.jlptLevel,
      e.freqRank,
    ]);
  }
  ins.dispose();
  db.dispose();
}
