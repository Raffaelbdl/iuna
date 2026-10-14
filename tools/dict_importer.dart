// Streaming JMdict importer — pure logic only. The CLI front-end lives
// in `build_dict.dart`; tests exercise this file directly with a small
// synthetic fixture.
//
// Source: JMdict_e_examples.gz from EDRDG (CC-BY-SA 4.0). The dataset
// is several hundred thousand entries / ~30 MB uncompressed, so we
// stream-parse the XML rather than DOM-loading it.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:iuna/core/deck_rules.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:xml/xml.dart';
import 'package:xml/xml_events.dart';

/// EDRDG renamed `JMdict_e_examples.gz` to this, and its https cert is
/// broken, hence plain http.
const kJmdictUrl = 'http://ftp.edrdg.org/pub/Nihongo/JMdict_e_examp.gz';
const kDefaultJmdictPath = 'tools/_cache/JMdict_e_examp.gz';
const kDefaultTanosDir = 'tools/_cache/tanos';

/// Picks the right parser based on extension. `.json` → simplified
/// JSON; `.gz` / `.xml` → raw JMdict XML (gzip auto-detected).
Stream<JmdictEntry> openJmdictEntryStream(String path) {
  final lower = path.toLowerCase();
  final bytes = File(path).openRead();
  if (lower.endsWith('.json')) return parseJmdictJson(bytes);
  if (lower.endsWith('.json.gz') || lower.endsWith('.json.tgz')) {
    return parseJmdictJson(bytes, gzipped: true);
  }
  return parseJmdictXml(bytes, gzipped: lower.endsWith('.gz'));
}

/// Downloads JMdict to [path] unless it is already cached, so repeat
/// builds don't hit EDRDG.
Future<void> ensureJmdictCached(String path) async {
  final file = File(path);
  if (file.existsSync() && file.lengthSync() > 1_000_000) {
    stdout.writeln('Using cached JMdict at $path '
        '(${(file.lengthSync() / 1024).round()} KB).');
    return;
  }
  stdout.writeln('Downloading $kJmdictUrl ...');
  file.parent.createSync(recursive: true);
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(kJmdictUrl));
    final resp = await req.close();
    if (resp.statusCode != 200) {
      throw HttpException(
        'GET $kJmdictUrl returned ${resp.statusCode}',
        uri: Uri.parse(kJmdictUrl),
      );
    }
    await resp.pipe(file.openWrite());
  } finally {
    client.close(force: true);
  }
  stdout.writeln('Saved $path '
      '(${(file.lengthSync() / 1024).round()} KB).');
}

/// One JMdict `<entry>` flattened into the shape the seed builder needs.
class JmdictEntry {
  JmdictEntry({
    required this.kanji,
    required this.kana,
    required this.senses,
    required this.priorityTags,
    required this.exampleSentences,
    this.isCommon = false,
  });

  /// Primary headword. Falls back to [kana] when the entry has no
  /// `<k_ele>` (kana-only words like ありがとう).
  final String kanji;
  final String kana;
  final List<JmdictSense> senses;

  /// Union of every `<ke_pri>` and `<re_pri>` tag in the entry. Used
  /// for rarity bucketing on the raw-XML path. Empty on the simplified
  /// JSON path (where priority detail collapses to [isCommon]).
  final Set<String> priorityTags;

  /// Japanese example sentences pulled from `<example>` /
  /// `<ex_sent xml:lang="jpn">`. Capped by the caller, not here.
  final List<String> exampleSentences;

  /// scriptin/jmdict-simplified collapses every `<ke_pri>`/`<re_pri>`
  /// signal into a single `common` flag per kanji/kana element. We OR
  /// those together at the entry level so the rarity bucketer has at
  /// least a binary signal even when the raw priority list is gone.
  final bool isCommon;
}

class JmdictSense {
  JmdictSense({
    required this.pos,
    required this.glosses,
    this.note = '',
    this.misc = const [],
  });

  /// POS / grammar entity names (e.g. `v5k-s`, `vt`, `n`). Order matches
  /// the XML.
  final List<String> pos;

  /// English glosses for this sense, in source order.
  final List<String> glosses;

  /// Free-text `<s_inf>` note, if any.
  final String note;

  /// `<misc>` entity names (e.g. `uk` "usually written using kana
  /// alone", `arch`, `obs`).
  final List<String> misc;
}

/// Streaming JMdict parser. Yields one [JmdictEntry] per `<entry>` in
/// document order.
///
/// [bytes] is the raw byte stream (gzipped or not). When [gzipped] is
/// true (the default) we run it through `GZipCodec().decoder` first.
Stream<JmdictEntry> parseJmdictXml(
  Stream<List<int>> bytes, {
  bool gzipped = true,
}) {
  final raw = gzipped ? bytes.transform(gzip.decoder) : bytes;
  return raw
      .transform(utf8.decoder)
      .toXmlEvents(entityMapping: _PreserveEntityMapping())
      .selectSubtreeEvents((event) => event.name == 'entry')
      .toXmlNodes()
      .expand((nodes) => nodes)
      .where((node) => node is XmlElement)
      .cast<XmlElement>()
      .map(_buildEntry)
      .where((e) => e != null)
      .cast<JmdictEntry>();
}

/// JMdict declares hundreds of `<!ENTITY>`s in its DOCTYPE — `&v5k-s;`,
/// `&n;`, `&uk;`, etc. We don't want them expanded to their human-prose
/// values; we want the entity *name* preserved so `<pos>&v5k-s;</pos>`
/// reads as the literal text `v5k-s`. This mapping returns the standard
/// XML entities (amp/lt/gt/quot/apos) verbatim and substitutes the
/// entity name for everything else.
class _PreserveEntityMapping extends XmlDefaultEntityMapping {
  _PreserveEntityMapping() : super.xml();

  @override
  String? decodeEntity(String name) {
    return super.decodeEntity(name) ?? name;
  }
}

JmdictEntry? _buildEntry(XmlElement entry) {
  String? kanji;
  String? kana;
  final priority = <String>{};
  final senses = <JmdictSense>[];
  final examples = <String>[];

  for (final kEle in entry.findElements('k_ele')) {
    kanji ??= kEle.getElement('keb')?.innerText;
    for (final pri in kEle.findElements('ke_pri')) {
      priority.add(pri.innerText);
    }
  }
  for (final rEle in entry.findElements('r_ele')) {
    kana ??= rEle.getElement('reb')?.innerText;
    for (final pri in rEle.findElements('re_pri')) {
      priority.add(pri.innerText);
    }
  }

  if (kana == null || kana.isEmpty) return null;
  kanji ??= kana;

  for (final sense in entry.findElements('sense')) {
    final pos = <String>[
      for (final p in sense.findElements('pos')) p.innerText.trim(),
    ]..removeWhere((s) => s.isEmpty);
    final glosses = <String>[];
    for (final g in sense.findElements('gloss')) {
      final lang = g.getAttribute('xml:lang') ?? 'eng';
      if (lang != 'eng') continue;
      final text = g.innerText.trim();
      if (text.isNotEmpty) glosses.add(text);
    }
    if (glosses.isEmpty) continue;

    final note = sense
        .findElements('s_inf')
        .map((e) => e.innerText.trim())
        .where((s) => s.isNotEmpty)
        .join(' / ');
    final misc = <String>[
      for (final m in sense.findElements('misc')) m.innerText.trim(),
    ]..removeWhere((s) => s.isEmpty);

    senses.add(JmdictSense(
      pos: pos,
      glosses: glosses,
      note: note,
      misc: misc,
    ));

    for (final ex in sense.findElements('example')) {
      for (final s in ex.findElements('ex_sent')) {
        final lang = s.getAttribute('xml:lang') ?? 'eng';
        if (lang != 'jpn') continue;
        final text = s.innerText.trim();
        if (text.isNotEmpty) examples.add(text);
      }
    }
  }

  if (senses.isEmpty) return null;

  return JmdictEntry(
    kanji: kanji,
    kana: kana,
    senses: senses,
    priorityTags: priority,
    exampleSentences: examples,
    isCommon: priority.isNotEmpty,
  );
}

/// Streams entries out of scriptin/jmdict-simplified's JSON payload.
/// The format is a single root object with a `words: [...]` array
/// (~216k entries, ~125 MB pretty-printed). We bytes→utf8→jsonDecode in
/// one shot — a 1-shot build tool can afford to keep the parsed tree
/// in memory for the duration. [gzipped] kept symmetric with
/// [parseJmdictXml] in case the caller is piping a `.tgz`.
Stream<JmdictEntry> parseJmdictJson(
  Stream<List<int>> bytes, {
  bool gzipped = false,
}) async* {
  final raw = gzipped ? bytes.transform(gzip.decoder) : bytes;
  final builder = BytesBuilder(copy: false);
  await for (final chunk in raw) {
    builder.add(chunk);
  }
  final root = jsonDecode(utf8.decode(builder.takeBytes()))
      as Map<String, dynamic>;
  final words = (root['words'] as List).cast<Map<String, dynamic>>();
  for (final w in words) {
    final entry = _buildJsonEntry(w);
    if (entry != null) yield entry;
  }
}

JmdictEntry? _buildJsonEntry(Map<String, dynamic> w) {
  final kanjiList = (w['kanji'] as List).cast<Map<String, dynamic>>();
  final kanaList = (w['kana'] as List).cast<Map<String, dynamic>>();
  if (kanaList.isEmpty) return null;

  // Prefer `common: true` forms when the entry has both common and
  // search-only kanji (e.g. simplified vs. archaic spellings).
  Map<String, dynamic>? pickPrimary(List<Map<String, dynamic>> xs) {
    if (xs.isEmpty) return null;
    return xs.firstWhere(
      (e) => e['common'] == true,
      orElse: () => xs.first,
    );
  }

  final primaryKanji = pickPrimary(kanjiList);
  final primaryKana = pickPrimary(kanaList);
  if (primaryKana == null) return null;

  final kana = (primaryKana['text'] as String).trim();
  final kanji = (primaryKanji?['text'] as String?)?.trim() ?? kana;
  if (kana.isEmpty) return null;

  final isCommon = kanjiList.any((e) => e['common'] == true) ||
      kanaList.any((e) => e['common'] == true);

  final senses = <JmdictSense>[];
  final examples = <String>[];
  final senseList = (w['sense'] as List).cast<Map<String, dynamic>>();
  for (final s in senseList) {
    final glosses = <String>[
      for (final g in (s['gloss'] as List).cast<Map<String, dynamic>>())
        if ((g['lang'] ?? 'eng') == 'eng' && (g['text'] as String).trim().isNotEmpty)
          (g['text'] as String).trim(),
    ];
    if (glosses.isEmpty) continue;

    final pos = <String>[
      for (final p in (s['partOfSpeech'] as List).cast<String>()) p.trim(),
    ]..removeWhere((p) => p.isEmpty);
    final note = (s['info'] as List)
        .cast<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' / ');
    final misc = <String>[
      for (final m in (s['misc'] as List).cast<String>()) m.trim(),
    ]..removeWhere((p) => p.isEmpty);

    senses.add(JmdictSense(
      pos: pos,
      glosses: glosses,
      note: note,
      misc: misc,
    ));

    for (final ex in (s['examples'] as List? ?? const [])
        .cast<Map<String, dynamic>>()) {
      for (final sent
          in (ex['sentences'] as List).cast<Map<String, dynamic>>()) {
        if ((sent['lang'] ?? 'eng') != 'jpn') continue;
        final text = (sent['text'] as String).trim();
        if (text.isNotEmpty) examples.add(text);
      }
    }
  }

  if (senses.isEmpty) return null;

  return JmdictEntry(
    kanji: kanji,
    kana: kana,
    senses: senses,
    priorityTags: const <String>{},
    exampleSentences: examples,
    isCommon: isCommon,
  );
}

/// Buckets a JMdict entry into a gacha rarity.
///
/// Three sources of information, in precedence order:
/// 1. Raw `<ke_pri>`/`<re_pri>` tags from JMdict XML — preserves the
///    original 5-tier shape (news1/ichi1 → Common, news2 → Rare,
///    spec1/2 → SR, nf01..nf24 → SSR, nf25..nf48 → UR).
/// 2. A frequency rank from a CC-BY corpus list (e.g. Leeds Japanese
///    15k). Bands are 0..1999 → Common, 2000..4999 → Rare,
///    5000..8999 → SR, 9000..13999 → SSR, 14000+ → UR.
/// 3. JLPT level (N5..N1) maps 1:1 to Common..UR.
///
/// If a JLPT level is supplied it overrides the frequency band so the
/// JLPT shelf reads as five clean tiers, matching the seed deck. The
/// scriptin/jmdict-simplified path collapses XML's priority detail into
/// a single [isCommon] flag, which is used as the last-resort fallback
/// (true → Common, false → UR).
Rarity rarityFor({
  Set<String> priorityTags = const <String>{},
  bool isCommon = false,
  int? frequencyRank,
  int? jlptLevel,
}) {
  bool has(String tag) => priorityTags.contains(tag);
  if (has('news1') || has('ichi1') || has('gai1')) return Rarity.common;
  if (has('news2') || has('ichi2')) return Rarity.rare;
  if (has('spec1') || has('spec2')) return Rarity.superRare;
  for (final t in priorityTags) {
    if (!t.startsWith('nf')) continue;
    final n = int.tryParse(t.substring(2));
    if (n == null) continue;
    return n <= 24 ? Rarity.ssr : Rarity.ur;
  }

  if (jlptLevel != null) {
    switch (jlptLevel) {
      case 5:
        return Rarity.common;
      case 4:
        return Rarity.rare;
      case 3:
        return Rarity.superRare;
      case 2:
        return Rarity.ssr;
      case 1:
        return Rarity.ur;
    }
  }

  if (frequencyRank != null) {
    if (frequencyRank < 2000) return Rarity.common;
    if (frequencyRank < 5000) return Rarity.rare;
    if (frequencyRank < 9000) return Rarity.superRare;
    if (frequencyRank < 14000) return Rarity.ssr;
    return Rarity.ur;
  }

  if (isCommon) return Rarity.common;
  return Rarity.ur;
}

/// True when an entry deserves a card. Entries with no priority tag,
/// no `common` flag, no frequency rank, and no JLPT level are typically
/// archaic/obscure words — bundling all 200k JMdict entries would blow
/// past the 5 MB seed budget for negligible learner value.
bool keepEntry({
  Set<String> priorityTags = const <String>{},
  bool isCommon = false,
  int? frequencyRank,
  int? jlptLevel,
  bool includeUntagged = false,
}) {
  if (includeUntagged) return true;
  return priorityTags.isNotEmpty ||
      isCommon ||
      frequencyRank != null ||
      jlptLevel != null;
}

/// Loads a frequency-ranked word list. One headword per line, ordered
/// from most to least frequent (rank 0 = most frequent). Blank lines
/// and `#`-prefixed comments are skipped. Returns a `word → rank` map.
Future<Map<String, int>> loadFrequencyRanks(File file) async {
  final out = <String, int>{};
  if (!file.existsSync()) return out;
  final lines = await file.readAsLines();
  var rank = 0;
  for (final raw in lines) {
    final word = raw.trim();
    if (word.isEmpty || word.startsWith('#')) continue;
    out.putIfAbsent(word, () => rank);
    rank++;
  }
  return out;
}

/// Joins one sense's POS list into the comma-separated string we store
/// in `card_senses.pos`.
String posCsv(List<String> pos) => pos.join(',');

/// Joins one sense's glosses into the comma-separated string we store
/// in `card_senses.gloss`.
String glossCsv(List<String> glosses) => glosses.join(', ');

/// Builds the `card_senses.definition` cell from `<s_inf>` + selected
/// `<misc>` tags. Skips empty notes so we don't write whitespace-only
/// strings.
String buildDefinition(JmdictSense sense) {
  final parts = <String>[];
  if (sense.note.isNotEmpty) parts.add(sense.note);
  // A short list of misc tags worth surfacing in the UI. Most JMdict
  // misc values are linguistic shorthand the user doesn't need to see.
  const userVisibleMisc = {
    'uk': 'usually written in kana',
    'arch': 'archaic',
    'obs': 'obsolete',
    'col': 'colloquial',
    'sl': 'slang',
    'hon': 'honorific',
    'hum': 'humble',
    'pol': 'polite',
    'derog': 'derogatory',
    'rare': 'rare',
    'fam': 'familiar',
    'chn': "children's term",
    'm-sl': 'manga slang',
    'on-mim': 'onomatopoeic / mimetic',
  };
  for (final m in sense.misc) {
    final label = userVisibleMisc[m];
    if (label != null) parts.add(label);
  }
  return parts.join(' · ');
}

/// Aggregate counters returned by [importInto].
class ImportStats {
  int cards = 0;
  int senses = 0;
  int examples = 0;
}

/// Drains [entries], applies the [jlpt] and [frequencyRanks] overlays,
/// buckets rarity, and writes rows into the open sqlite [db]. Caller
/// owns connection lifecycle and schema creation, and is also
/// responsible for picking the right parser ([parseJmdictXml] /
/// [parseJmdictJson]) for the source format.
///
/// Wraps the writes in a single transaction; if anything throws we
/// roll back and rethrow so a partial seed never lands on disk.
Future<ImportStats> importInto(
  Database db,
  Stream<JmdictEntry> entries, {
  required Map<(String, String), int> jlpt,
  Map<String, int> frequencyRanks = const {},
  int? limit,
  int examplesPerCard = 3,
  bool includeUntagged = false,
}) async {
  final stats = ImportStats();

  final insertCard = db.prepare('''
    INSERT OR IGNORE INTO cards
      (kanji, kana, meaning, rarity, jlpt_level, source)
    VALUES (?, ?, ?, ?, ?, 0)
  ''');
  final insertSense = db.prepare('''
    INSERT INTO card_senses (card_id, ordinal, pos, gloss, definition)
    VALUES (?, ?, ?, ?, ?)
  ''');
  final insertExample = db.prepare('''
    INSERT INTO examples (sentence, source_title) VALUES (?, NULL)
  ''');
  final linkExample = db.prepare('''
    INSERT OR IGNORE INTO card_examples (card_id, example_id) VALUES (?, ?)
  ''');

  // Reuse example rows when the same Tatoeba sentence appears under
  // multiple entries — JMdict_e_examples is heavy on these.
  final exampleIds = <String, int>{};

  db.execute('BEGIN');
  try {
    await for (final entry in entries) {
      final jlptLevel = jlpt[(entry.kanji, entry.kana)];
      final rank = frequencyRanks[entry.kanji] ??
          frequencyRanks[entry.kana];
      if (!keepEntry(
        priorityTags: entry.priorityTags,
        isCommon: entry.isCommon,
        frequencyRank: rank,
        jlptLevel: jlptLevel,
        includeUntagged: includeUntagged,
      )) {
        continue;
      }

      final rarity = rarityFor(
        priorityTags: entry.priorityTags,
        isCommon: entry.isCommon,
        frequencyRank: rank,
        jlptLevel: jlptLevel,
      );
      final headline = glossCsv(entry.senses.first.glosses);

      insertCard.execute([
        entry.kanji,
        entry.kana,
        headline,
        rarity.index,
        jlptLevel,
      ]);
      if (db.updatedRows == 0) continue;
      final cardId = db.lastInsertRowId;
      stats.cards++;

      var ordinal = 1;
      for (final s in entry.senses) {
        insertSense.execute([
          cardId,
          ordinal++,
          posCsv(s.pos),
          glossCsv(s.glosses),
          buildDefinition(s),
        ]);
        stats.senses++;
      }

      final capped =
          entry.exampleSentences.take(examplesPerCard).toSet().toList();
      for (final sentence in capped) {
        var exId = exampleIds[sentence];
        if (exId == null) {
          insertExample.execute([sentence]);
          exId = db.lastInsertRowId;
          exampleIds[sentence] = exId;
        }
        linkExample.execute([cardId, exId]);
        stats.examples++;
      }

      if (limit != null && stats.cards >= limit) break;
    }
    db.execute('COMMIT');
  } catch (_) {
    db.execute('ROLLBACK');
    rethrow;
  }

  insertCard.dispose();
  insertSense.dispose();
  insertExample.dispose();
  linkExample.dispose();
  return stats;
}

/// Loads a Tanos JLPT vocab list. Each TSV file should be lines of
/// `<kanji>\t<kana>` (or just `<kana>` for kana-only words). The
/// caller owns scraping tanos.co.uk and writing these files —
/// `tools/_cache/tanos/jlpt-n{1..5}.tsv` is the conventional layout.
///
/// Returns a map keyed by `(kanji, kana)` → JLPT level (1..5).
Future<Map<(String, String), int>> loadTanosJlpt(Directory dir) async {
  final out = <(String, String), int>{};
  if (!dir.existsSync()) return out;
  for (var level = 1; level <= 5; level++) {
    final file = File('${dir.path}/jlpt-n$level.tsv');
    if (!file.existsSync()) continue;
    final lines = await file.readAsLines();
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split('\t');
      final kanji = parts[0].trim();
      final kana = parts.length > 1 ? parts[1].trim() : parts[0].trim();
      if (kanji.isEmpty || kana.isEmpty) continue;
      out[(kanji, kana)] = level;
    }
  }
  return out;
}
