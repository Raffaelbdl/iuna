import '../../core/deck_rules.dart';
import '../../db/jmdict_lookup.dart';
import '../../core/japanese_text.dart';
import 'deinflect.dart';

/// Longest stretch tried as one word.
const _maxWordLength = 10;

/// A headword a stretch of text can be, and how the text inflects it.
class WordReading {
  const WordReading(this.entry, this.inflections);

  final JmdictHit entry;

  /// Undone to reach [entry], innermost first: 食べていました gives
  /// `[ongoing, polite, past]`.
  final List<String> inflections;
}

/// A stretch of a run read as one word. Offsets are within the run.
class TextWord {
  const TextWord(this.start, this.end, this.readings);

  final int start;
  final int end;

  /// Best guess first.
  final List<WordReading> readings;
}

/// Looks up every headword written or read as one of [forms].
typedef WordLexicon = List<JmdictHit> Function(Set<String> forms);

/// Each Japanese run of [text] split into dictionary words, keyed by
/// the run. The same run always splits the same way, so markdown
/// that breaks a sentence into styled pieces still finds its words.
Map<String, List<TextWord>> readText(String text, WordLexicon lexicon) {
  final runs = {for (final m in japaneseRun.allMatches(text)) m[0]!};
  if (runs.isEmpty) return const {};
  final deinflected = <String, List<Deinflection>>{};
  for (final run in runs) {
    for (var i = 0; i < run.length; i++) {
      for (var end = i + 1; end <= run.length && end - i <= _maxWordLength; end++) {
        final surface = run.substring(i, end);
        deinflected.putIfAbsent(surface, () => deinflect(surface));
      }
    }
  }
  final forms = {
    for (final all in deinflected.values)
      for (final d in all) d.form,
  };
  final index = <String, List<_Hit>>{};
  for (final entry in lexicon(forms)) {
    final hit = _Hit(entry);
    (index[entry.kanji] ??= []).add(hit);
    if (entry.kana != entry.kanji) (index[entry.kana] ??= []).add(hit);
  }
  final readings = <String, List<(WordReading, double)>>{};
  for (final MapEntry(key: surface, value: all) in deinflected.entries) {
    final found = _readingsOf(surface, all, index);
    if (found.isNotEmpty) readings[surface] = found;
  }
  return {for (final run in runs) run: _segment(run, readings)};
}

/// The cheapest split of [run] into words, by [_cost]. Plain longest
/// match reads 今日は as こんにちは and これはいいですね as はい・いで・すね;
/// pricing words lets short common ones beat one long rare one.
List<TextWord> _segment(String run, Map<String, List<(WordReading, double)>> readings) {
  final n = run.length;
  final best = List<double>.filled(n + 1, double.infinity)..[0] = 0;
  // Where the word ending at each offset starts; null for one character
  // the dictionary lacks.
  final start = List<int?>.filled(n + 1, null);
  for (var i = 0; i < n; i++) {
    if (best[i] + _unknownCost < best[i + 1]) {
      best[i + 1] = best[i] + _unknownCost;
      start[i + 1] = null;
    }
    for (var end = i + 1; end <= n && end - i <= _maxWordLength; end++) {
      final found = readings[run.substring(i, end)];
      if (found == null) continue;
      final cost = best[i] + found.first.$2;
      if (cost < best[end]) {
        best[end] = cost;
        start[end] = i;
      }
    }
  }
  final out = <TextWord>[];
  for (var end = n; end > 0;) {
    final i = start[end];
    if (i == null) {
      end--;
      continue;
    }
    out.add(TextWord(i, end, [for (final r in readings[run.substring(i, end)]!) r.$1]));
    end = i;
  }
  return out.reversed.toList();
}

const _unknownCost = 2.5;

const _glue = {'prt', 'cop', 'aux', 'aux-v', 'aux-adj'};
const _phrase = {'exp', 'int'};
const _finalParticles = 'はがをにでともへやかの';
const _innerParticles = 'はがをにでとへ';

/// A headword with what pricing it needs worked out once, however many
/// substrings reach it.
class _Hit {
  _Hit(this.entry)
    : usuallyKana = entry.senses.any((s) => s.hasMisc('uk')),
      glue = entry.senses.any((s) => s.pos.split(',').any(_glue.contains)),
      types = {for (final s in entry.senses) ...wordTypesOf(s.pos)},
      firstPos = entry.senses.isEmpty ? const [] : entry.senses.first.pos.split(','),
      kanaFirst = entry.senses.isNotEmpty && entry.senses.first.hasMisc('uk'),
      dated =
          entry.senses.isNotEmpty &&
          (entry.senses.first.hasMisc('arch') || entry.senses.first.hasMisc('obs'));

  final JmdictHit entry;
  final bool usuallyKana;
  final bool glue;
  final Set<WordType> types;
  final List<String> firstPos;

  /// Its main sense is usually written in kana (何で); a later sense
  /// being so (行く's auxiliary ていく) doesn't make the kanji rare.
  final bool kanaFirst;
  final bool dated;
}

/// What reading [surface] as [hit] costs; a plain common word is 1.
double _cost(String surface, _Hit hit, {required bool written, required bool kanji}) {
  final rarity = hit.entry.rarity;
  final kanaReading = !written && !hit.usuallyKana;
  // Kana matched against a kanji headword's reading: one homophone
  // among many, and the source of false matches across particles
  // (それはいい → 廃位). Only common words get through.
  if (kanaReading && !kanji && rarity.index > Rarity.rare.index) return double.infinity;
  var cost = written && hit.glue ? 0.6 + 0.1 * rarity.index : 1.0 + 0.15 * rarity.index;
  if (kanaReading) cost += rarity == Rarity.common ? 0.3 : 0.8;
  if (hit.dated) cost += 1;
  // 何で for 何ですか: a kana word spelled in kanji is the rarer reading.
  if (written && kanji && hit.kanaFirst) cost += 0.5;
  final pos = hit.firstPos;
  if (pos.every(_phrase.contains) &&
      kanji &&
      _finalParticles.contains(surface[surface.length - 1])) {
    // A set phrase ending in a particle (今日は, read こんにちは) is far
    // more often the word before it plus that particle (今日・は).
    cost += 1.3;
  } else if (pos.any(_phrase.contains)) {
    cost += 0.3;
  }
  if (pos.contains('exp')) {
    // 雨が降る, 見に行く: the learner is better served by the parts.
    for (var i = 1; i < surface.length - 1; i++) {
      if (_innerParticles.contains(surface[i])) cost += 1;
    }
  }
  return cost;
}

/// Every headword [surface] can be, cheapest first, with its cost.
List<(WordReading, double)> _readingsOf(
  String surface,
  List<Deinflection> deinflected,
  Map<String, List<_Hit>> index,
) {
  final kanji = kanjiChar.hasMatch(surface);
  final found = <(String, String), (WordReading, double)>{};
  for (final d in deinflected) {
    for (final hit in index[d.form] ?? const <_Hit>[]) {
      if (d.type != null && !hit.types.contains(d.type)) continue;
      final cost =
          _cost(surface, hit, written: hit.entry.kanji == d.form, kanji: kanji) +
          0.05 * d.reasons.length;
      if (cost == double.infinity) continue;
      final key = (hit.entry.kanji, hit.entry.kana);
      final prior = found[key];
      if (prior != null && prior.$2 <= cost) continue;
      found[key] = (WordReading(hit.entry, d.reasons), cost);
    }
  }
  // Unranked headwords sort after every ranked one.
  int rank(JmdictHit h) => h.freqRank ?? 1 << 30;

  return found.values.toList()..sort((a, b) {
    final c = a.$2.compareTo(b.$2);
    return c != 0 ? c : rank(a.$1.entry).compareTo(rank(b.$1.entry));
  });
}
