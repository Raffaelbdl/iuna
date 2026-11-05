import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../core/deck_rules.dart';
import '../core/jmdict_labels.dart';
import 'sqlite_open.dart';

/// The sidecar `DictDownload` installs under the documents directory.
const kJmdictFileName = 'jmdict.sqlite';

class JmdictSense {
  const JmdictSense({
    required this.pos,
    required this.gloss,
    required this.def,
  });

  /// Comma-separated POS codes, e.g. `v5k-s,vt`.
  final String pos;

  /// Comma+space-joined English glosses, e.g. `to put on, to wear`.
  final String gloss;

  /// Optional prose: `<s_inf>` note + selected `<misc>` tags. Empty
  /// string when JMdict has nothing to surface.
  final String def;

  /// Whether this sense carries misc [tag] (`uk`, `arch`…) among the
  /// labels in [def]: a whole label, not a word inside the note.
  bool hasMisc(String tag) {
    final label = jmdictMiscLabels[tag]!;
    return def.contains(label) && def.split(kDefinitionSeparator).contains(label);
  }
}

class JmdictHit {
  const JmdictHit({
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

/// Read-only sqlite lookup against the JMdict sidecar managed by
/// [DictDownload]. Singleton; the underlying database handle is opened
/// lazily on first use and held until [dispose] is called (e.g. when
/// the user clears the dictionary cache).
class JmdictLookup {
  JmdictLookup._();

  /// A read-only handle of its own on the sidecar at [path], for a
  /// background isolate: there [instance] can't resolve the documents
  /// directory. The caller [dispose]s it.
  JmdictLookup.openFile(String path)
    : _db = sqlite3.open(path, mode: OpenMode.readOnly);

  static final JmdictLookup instance = JmdictLookup._();

  Database? _db;
  Future<void>? _opening;

  /// Opens the sqlite handle if a sidecar is on disk and not already
  /// open. Safe to call from anywhere; concurrent calls coalesce on
  /// the in-flight future.
  Future<void> warmUp() {
    if (_db != null) return Future.value();
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<void> _open() async {
    final file = await documentsFile(kJmdictFileName);
    if (!file.existsSync()) return;
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    _db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  }

  /// True when an open handle exists. Use [DictDownload.isInstalled]
  /// for the disk-level check before warm-up.
  bool get isOpen => _db != null;

  /// Prefix-matches [query] against `kanji` and `kana`. Returns up to
  /// [limit] hits ordered by frequency rank (most-frequent first;
  /// unranked entries last). Empty query → empty result.
  Future<List<JmdictHit>> search(String query, {int limit = 30}) async {
    await warmUp();
    final db = _db;
    if (db == null) return const [];
    final q = query.trim();
    if (q.isEmpty) return const [];
    // GLOB is case-sensitive and uses prefix indexes; LIKE doesn't
    // unless we toggle case_sensitive_like, and Japanese has no case
    // folding to worry about anyway.
    final pattern = '$q*';
    final stmt = db.prepare('''
      SELECT $_hitColumns
      FROM jmdict
      WHERE kanji GLOB ? OR kana GLOB ?
      ORDER BY (freq_rank IS NULL), freq_rank ASC, kanji
      LIMIT ?
    ''');
    try {
      final rows = stmt.select([pattern, pattern, limit]);
      return [for (final r in rows) _hitFromRow(r)];
    } finally {
      stmt.dispose();
    }
  }

  /// Exact lookup by `(kanji, kana)`. Returns null if unmatched or if
  /// the dictionary is not installed.
  Future<JmdictHit?> exact(String kanji, String kana) async {
    await warmUp();
    final db = _db;
    if (db == null) return null;
    final stmt = db.prepare('''
      SELECT $_hitColumns
      FROM jmdict
      WHERE kanji = ? AND kana = ?
      LIMIT 1
    ''');
    try {
      final rows = stmt.select([kanji, kana]);
      if (rows.isEmpty) return null;
      return _hitFromRow(rows.first);
    } finally {
      stmt.dispose();
    }
  }

  /// Every headword written or read as one of [forms], from the handle
  /// [warmUp] opened; nothing when it isn't open.
  List<JmdictHit> byForms(Iterable<String> forms) {
    final db = _db;
    if (db == null) return const [];
    // One JSON parameter instead of a placeholder per form: no variable
    // limit to chunk around, and no row returned twice across chunks.
    final rows = db.select(
      'SELECT $_hitColumns FROM jmdict '
      'WHERE kanji IN (SELECT value FROM json_each(?1)) '
      'OR kana IN (SELECT value FROM json_each(?1))',
      [jsonEncode(forms.toList())],
    );
    return [for (final r in rows) _hitFromRow(r)];
  }

  /// Closes the sqlite handle. Required before deleting the file on
  /// disk (Android keeps the inode alive otherwise, so disk space
  /// isn't reclaimed).
  void dispose() {
    _db?.dispose();
    _db = null;
  }
}

/// What [_hitFromRow] reads.
const _hitColumns = 'kanji, kana, senses_json, rarity, jlpt_level, freq_rank';

JmdictHit _hitFromRow(Row r) {
  final raw = jsonDecode(r['senses_json'] as String) as List;
  return JmdictHit(
    kanji: r['kanji'] as String,
    kana: r['kana'] as String,
    senses: [
      for (final s in raw)
        JmdictSense(
          pos: (s as Map)['pos'] as String? ?? '',
          gloss: s['gloss'] as String? ?? '',
          def: s['def'] as String? ?? '',
        ),
    ],
    rarity: Rarity.values[r['rarity'] as int],
    jlptLevel: r['jlpt_level'] as int?,
    freqRank: r['freq_rank'] as int?,
  );
}
