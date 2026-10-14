// Parses the shared "Science Terms" Anki deck (Japanese programming,
// math and science vocabulary) into [PackCard] values.
//
// This deck ships in the legacy apkg schema and carries no review
// history at all — every card sits in queue 0. It is therefore imported
// as a *pack*: a bundle of card definitions the booster sampler can
// draw from, never as scheduling state.
//
// Six fields, separator `\x1f`:
//
// | ord | name                 | mapping                                 |
// |-----|----------------------|-----------------------------------------|
// | 0   | Expression           | `kanji` (first `・` alternative)         |
// | 1   | Reading              | `furigana` + `kana`, Anki ruby syntax   |
// | 2   | Translation          | `meaning` / sense gloss                 |
// | 3   | Short Description    | sense definition                        |
// | 4   | Explanation          | sense definition (when 3 is empty)      |
// | 5   | Other Names / Field  | domain tag, e.g. "computer science"     |
//
// Field 1 is Anki's `漢字[かんじ]` ruby syntax with pitch-accent
// markers interleaved as bracket groups holding a bare digit or `?`
// (`拡[かく]張[ちょう][0]`), and "no ruby" markers holding whitespace
// (`ルクス[ ][1]`). Both are stripped; what survives is Iuna's own
// furigana format.

import 'package:sqlite3/sqlite3.dart';

import 'package:iuna/core/deck_rules.dart';
import 'package:iuna/core/pack_format.dart';


const kScienceModelName = 'Science Terms';

class ScienceParseStats {
  int total = 0;
  int kept = 0;
  int dropped = 0;
  int senses = 0;

  /// Notes whose reading field reconstructs to a different headword
  /// than the expression field — `x^n` vs `エックスのエヌ乗`, `論理値`
  /// vs `真理値`. The expression wins (it is the side the deck author
  /// curated), but the ruby can no longer be trusted against it, so
  /// `furigana` is dropped for these.
  int headwordMismatch = 0;
  final List<String> mismatches = [];
  final Map<int, int> byRarity = {
    for (var i = 0; i < 5; i++) i: 0,
  };
}

/// Resolves the rarity (and optional JLPT level) for a headword. The
/// deck carries no frequency signal of its own, so the pack builder
/// supplies one backed by the JMdict sidecar.
typedef RarityResolver = ({int rarity, int? jlptLevel}) Function(
  String kanji,
  String kana,
);

class ScienceParser {
  ScienceParser(
    this.anki, {
    required this.modelId,
    RarityResolver? rarityResolver,
  }) : _resolveRarity = rarityResolver ?? _defaultRarity;

  final Database anki;

  /// Notetype id of [kScienceModelName], resolved by the caller through
  /// `ApkgReader.noteTypeIdByName` (which handles both the modern
  /// `notetypes` table and the legacy `col.models` blob).
  final int modelId;
  final RarityResolver _resolveRarity;
  final stats = ScienceParseStats();

  static ({int rarity, int? jlptLevel}) _defaultRarity(String _, String _) =>
      (rarity: Rarity.superRare.index, jlptLevel: null);

  List<PackCard> parseAll() {
    final out = <PackCard>[];
    for (final row in anki.select(
      'SELECT flds FROM notes WHERE mid = ?',
      [modelId],
    )) {
      stats.total++;
      final entry = _parseNote(row['flds'] as String);
      if (entry == null) {
        stats.dropped++;
        continue;
      }
      stats.kept++;
      stats.senses += entry.senses.length;
      stats.byRarity[entry.rarity] = (stats.byRarity[entry.rarity] ?? 0) + 1;
      out.add(entry);
    }
    return out;
  }

  PackCard? _parseNote(String flds) {
    final fields = flds.split('\x1f');
    if (fields.length < 3) return null;

    // The expression field is not always plain text — some notes carry
    // ruby or pitch markers in it too — so it goes through the same
    // scanner as the reading field.
    final expression = _parseRuby(_firstAlternative(fields[0])).kanji;
    final reading = _parseRuby(_firstAlternative(fields[1]));
    final meaning = _collapse(_stripHtml(fields[2]));
    if (meaning.isEmpty) return null;

    final kanji = expression.isNotEmpty ? expression : reading.kanji;
    final kana = reading.kana.isNotEmpty ? reading.kana : kanji;
    String? furigana = reading.furigana;
    if (kanji.isEmpty || kana.isEmpty) return null;

    if (reading.kanji.isNotEmpty && reading.kanji != kanji) {
      stats.headwordMismatch++;
      stats.mismatches.add('$kanji ≠ ${reading.kanji} ($kana)');
      furigana = null;
    }
    if (furigana != null && !furigana.contains('[')) furigana = null;

    final domain = fields.length > 5 ? _collapse(_stripHtml(fields[5])) : '';
    final shortDesc = fields.length > 3 ? _collapse(_stripHtml(fields[3])) : '';
    final explanation =
        fields.length > 4 ? _collapse(_stripHtml(fields[4])) : '';

    final resolved = _resolveRarity(kanji, kana);
    return PackCard(
      kanji: kanji,
      kana: kana,
      furigana: furigana,
      meaning: meaning,
      rarity: resolved.rarity,
      jlpt: resolved.jlptLevel,
      senses: [
        PackSense(
          ordinal: 1,
          pos: domain,
          gloss: meaning,
          definition: shortDesc.isNotEmpty ? shortDesc : explanation,
        ),
      ],
    );
  }
}

/// A headword split three ways: the bare surface form, its reading, and
/// the positional-furigana string that pairs them.
typedef RubyReading = ({String kanji, String kana, String furigana});

/// Exposed for tests.
RubyReading parseScienceRuby(String raw) => _parseRuby(_firstAlternative(raw));

/// Exposed for tests.
String scienceFirstAlternative(String raw) => _firstAlternative(raw);

/// Several notes list synonyms separated by `・` / `；` / `;`, or stack
/// them on `<br>` lines. Iuna stores one headword per card, so only the
/// first survives.
String _firstAlternative(String raw) {
  final text = _stripHtml(raw);
  final line = text.split('\n').firstWhere(
        (l) => l.trim().isNotEmpty,
        orElse: () => '',
      );
  return line.split(RegExp(r'[・；;]')).first.trim();
}

/// Strips tags, turns `<br>` into a newline and normalises `&nbsp;` to a
/// plain space so the ruby scanner sees uniform whitespace.
String _stripHtml(String raw) {
  var s = raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</?(div|p)[^>]*>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]*>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll(' ', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return s;
}

String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

/// A bracket group is a pitch-accent annotation (`[0]`, `[?]`) or an
/// explicit "this segment has no ruby" marker (`[ ]`) rather than a
/// real reading.
bool _isNotReading(String ruby) {
  final t = ruby.trim();
  return t.isEmpty || t == '?' || RegExp(r'^\d+$').hasMatch(t);
}

RubyReading _parseRuby(String raw) {
  final kanji = StringBuffer();
  final kana = StringBuffer();
  final furigana = StringBuffer();

  var i = 0;
  while (i < raw.length) {
    final open = raw.indexOf('[', i);
    final close = open < 0 ? -1 : raw.indexOf(']', open);
    if (open < 0 || close < 0) {
      final tail = raw.substring(i);
      kanji.write(tail);
      kana.write(tail);
      furigana.write(tail);
      break;
    }

    final pending = raw.substring(i, open);
    final ruby = raw.substring(open + 1, close);
    i = close + 1;

    if (_isNotReading(ruby)) {
      kanji.write(pending);
      kana.write(pending);
      furigana.write(pending);
      continue;
    }

    // Anki separates ruby segments with a space that is not part of the
    // headword: `サブ 名[な]前[まえ]` reads as サブなまえ. Everything up
    // to that separator is literal text; what follows is the base the
    // ruby annotates.
    final sep = pending.lastIndexOf(' ');
    final lead = sep >= 0 ? pending.substring(0, sep) : '';
    final base = sep >= 0 ? pending.substring(sep + 1) : pending;

    kanji
      ..write(lead)
      ..write(base);
    kana
      ..write(lead)
      ..write(ruby);
    // Keep the original spacing so the stored furigana stays valid
    // positional syntax rather than a reconstruction of it.
    furigana
      ..write(pending)
      ..write('[')
      ..write(ruby)
      ..write(']');
  }

  return (
    kanji: _tidy(kanji.toString()),
    kana: _tidy(kana.toString()),
    furigana: _collapse(furigana.toString()),
  );
}

/// Leftover whitespace inside a headword is always a ruby-segment
/// separator or stray markup — no entry in this deck contains a real
/// space. Dangling dashes and separators are the tail of a stripped
/// pitch annotation (`同株[どうしゅ][1] - [0]`), as is a trailing `ー`
/// that doesn't follow katakana (`雌雄異株ー`, but not `サーバー`).
String _tidy(String s) {
  var out = s.replaceAll(RegExp(r'\s+'), '');
  out = out.replaceAll(RegExp(r'^[-‐–—ー・；;、]+|[-‐–—・；;、]+$'), '');
  while (out.length > 1 && out.endsWith('ー') && !_isKatakana(out[out.length - 2])) {
    out = out.substring(0, out.length - 1);
  }
  return out;
}

bool _isKatakana(String ch) {
  final c = ch.codeUnitAt(0);
  return c >= 0x30A0 && c <= 0x30FF;
}
