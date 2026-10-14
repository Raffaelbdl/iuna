// The card-pack transfer format, read by the app and written by the
// pack tools. Pure Dart — no Flutter import.
//
// Deliberately *not* a mirror of Iuna's schema. Packs are published
// once and downloaded for as long as they exist, so a file written
// today has to keep importing after any number of schema bumps; the
// importer maps this document onto whatever the tables currently look
// like. Bump the version only on a breaking change to the shape.

import 'deck_rules.dart';

const int kPackFormatVersion = 1;

class PackFormatException implements Exception {
  const PackFormatException(this.message);
  final String message;

  @override
  String toString() => 'PackFormatException: $message';
}

class PackSense {
  const PackSense({
    required this.ordinal,
    required this.pos,
    required this.gloss,
    required this.definition,
  });

  final int ordinal;
  final String pos;
  final String gloss;
  final String definition;

  Map<String, dynamic> toJson() => {
    'ordinal': ordinal,
    if (pos.isNotEmpty) 'pos': pos,
    'gloss': gloss,
    if (definition.isNotEmpty) 'definition': definition,
  };
}

class PackCard {
  const PackCard({
    required this.kanji,
    required this.kana,
    required this.meaning,
    this.furigana,
    required this.rarity,
    this.jlpt,
    required this.senses,
  });

  final String kanji;
  final String kana;
  final String meaning;
  final String? furigana;

  /// Rarity enum index, clamped into range by the reader.
  final int rarity;
  final int? jlpt;
  final List<PackSense> senses;

  /// The wire shape [PackDocument.parse] reads back; empty optional
  /// fields are left out.
  Map<String, dynamic> toJson() => {
    'kanji': kanji,
    'kana': kana,
    if (furigana != null) 'furigana': furigana,
    'meaning': meaning,
    'rarity': rarity,
    if (jlpt != null) 'jlpt': jlpt,
    'senses': [for (final s in senses) s.toJson()],
  };
}

/// A parsed pack document. [parse] validates everything up front, so a
/// malformed pack is refused before anything is written.
class PackDocument {
  const PackDocument({
    required this.name,
    required this.label,
    required this.description,
    this.sourceTitle,
    this.sourceUrl,
    this.sourceAuthor,
    this.license,
    required this.cards,
  });

  final String name;
  final String label;
  final String description;

  /// Attribution for the upstream deck. Absent fields stay null rather
  /// than being guessed at — an unknown licence is not "public domain".
  final String? sourceTitle;
  final String? sourceUrl;
  final String? sourceAuthor;
  final String? license;
  final List<PackCard> cards;

  /// Throws [PackFormatException] if [json] is not a pack this app can
  /// read.
  static PackDocument parse(Map<String, dynamic> json) {
    final format = json['format'];
    if (format is! int || format > kPackFormatVersion) {
      throw PackFormatException(
        'pack format $format is newer than this app understands '
        '(max $kPackFormatVersion) — update Iuna',
      );
    }
    final name = json['pack'];
    final entries = json['cards'];
    if (name is! String || name.isEmpty || entries is! List) {
      throw const PackFormatException('pack is missing "pack" or "cards"');
    }
    final source = json['source'] as Map<String, dynamic>?;
    return PackDocument(
      name: name,
      label: json['label'] as String? ?? name,
      description: json['description'] as String? ?? '',
      sourceTitle: source?['title'] as String?,
      sourceUrl: source?['url'] as String?,
      sourceAuthor: source?['author'] as String?,
      license: source?['license'] as String?,
      cards: [for (final (i, raw) in entries.indexed) _card(i, raw)],
    );
  }

  static PackCard _card(int i, Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw PackFormatException('card $i is not an object');
    }
    final kanji = raw['kanji'];
    final kana = raw['kana'];
    final meaning = raw['meaning'];
    if (kanji is! String ||
        kana is! String ||
        meaning is! String ||
        kanji.isEmpty ||
        kana.isEmpty) {
      throw PackFormatException(
        'card $i needs non-empty kanji, kana and meaning',
      );
    }
    final senses = raw['senses'] as List<dynamic>? ?? const [];
    return PackCard(
      kanji: kanji,
      kana: kana,
      meaning: meaning,
      furigana: raw['furigana'] as String?,
      rarity: (raw['rarity'] as int? ?? 0).clamp(0, Rarity.values.length - 1),
      jlpt: raw['jlpt'] as int?,
      senses: [
        for (final s in senses.cast<Map<String, dynamic>>())
          PackSense(
            ordinal: s['ordinal'] as int? ?? 1,
            pos: s['pos'] as String? ?? '',
            gloss: s['gloss'] as String? ?? '',
            definition: s['definition'] as String? ?? '',
          ),
      ],
    );
  }
}
