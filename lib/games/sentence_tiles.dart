import '../core/deck_rules.dart';
import '../core/japanese_text.dart';
import '../db/jmdict_lookup.dart';
import '../learn/words/segmenter.dart';

/// Tiles per Sentence builder puzzle. Fewer is no puzzle; more, and
/// Japanese's free word order makes several answers right.
const kMinTiles = 3;
const kMaxTiles = 5;

/// Whether [t] makes a Sentence builder puzzle.
bool fitsOrder(SentenceTiles t) =>
    t.tiles.length >= kMinTiles && t.tiles.length <= kMaxTiles;

/// Parts of speech glued onto the tile before: the segmenter's glue
/// (particles, the copula, auxiliaries) and suffixes. 猫が, not 猫 and が.
const _gluePos = {...kGluePos, 'suf', 'n-suf'};

/// Particles by spelling too: in kana the dictionary can read の as 野.
const _particles = {
  'は', 'が', 'を', 'に', 'で', 'と', 'も', 'へ', 'の', 'や', 'か', 'な', //
  'ね', 'よ', 'わ', 'さ', 'ぞ', 'ぜ', 'し', 'ば', 'から', 'まで', 'より', //
  'けど', 'けれど', 'けれども', 'って', 'だけ', 'しか', 'ばかり', 'ほど', //
  'など', 'なら', 'ので', 'のに', 'ながら', 'たり', 'だり', 'には', 'では', //
  'とは', 'にも', 'へは', 'へと', 'かな', 'かしら', 'よね', 'のは', 'のが', //
  'でも', 'さえ', 'こそ', 'すら', 'だって', //
};

/// Particles that never follow another case particle (をが, にを).
const _caseAfterCase = {'が', 'を'};

/// Verbs that work as postpositions after に: この点について.
const _afterNi = [
  'ついて', 'つき', 'つれて', 'よって', 'より', 'よる', 'よれば', 'とって', //
  '対して', '関して', '関する', 'おいて', 'おける', '沿って', '向かって', //
];

/// The particles that close an argument: a phrase ending in one can
/// move among the others before the verb (私は昨日 / 昨日私は).
const _argumentEnds = {
  'は', 'が', 'を', 'に', 'で', 'へ', 'と', 'も', 'から', 'まで', 'より', //
  'には', 'では', 'にも', 'とは', 'へは', 'でも', //
};

/// Set phrases that open with a particle or the copula (について,
/// によって, のです, でしょう, だろう) belong to the word before.
const _particleHeads = 'にでとをがはのへもだ';

/// Verbs that follow a te-form as helpers: 落としてしまった, 来ている.
const _teHelpers = {
  'いる', 'おる', 'くる', 'いく', 'ある', 'おく', 'みる', 'しまう', //
  'くれる', 'もらう', 'あげる', 'くださる', 'ください', 'いただく', //
};

/// Verbs a bare noun takes on as one verb: 参加する, 表現できる.
const _verbNouns = {'する', 'できる'};

/// Glued onto the word after: prefixes (お茶) and pre-noun words
/// (この本, 大きな犬).
const _glueAheadPos = {'pref', 'adj-pn'};

/// Sentence-final marks, kept off the tiles and shown after them.
final _endMarks = RegExp(r'[。！？!?]+$');

/// Japanese and the comma between clauses: anything else (digits,
/// Latin, quotes, brackets) makes a sentence unfit.
final _fit = RegExp('^(?:${japaneseRun.pattern}|、)+\$');

/// A content word of a tiled sentence, as its headword.
typedef TileWord = ({String kanji, String kana, Rarity rarity});

/// A sentence cut into tiles, in order.
class SentenceTiles {
  const SentenceTiles({
    required this.tiles,
    required this.closes,
    required this.end,
    required this.words,
    this.particles = const [],
  });

  final List<String> tiles;

  /// Per tile, the particle it ends in (猫が → が), or null when its last
  /// glued word isn't one.
  final List<String?> particles;

  /// Per tile, whether it closes a phrase that can move as a whole: an
  /// argument (a noun closed by a case or topic particle) or a time word
  /// (昨日), with every tile since the last such close, which modifies
  /// it (法の前に, 古い本を). The tiles after the last close are the
  /// predicate and stay last.
  final List<bool> closes;

  /// The final mark (。, ？), shown after the last tile.
  final String end;

  /// The content words read in it (not particles), so the caller can
  /// tell which the learner knows.
  final List<TileWord> words;

  String get text => tiles.join() + end;

  /// The movable phrases, in order, then the predicate.
  ({List<String> phrases, String predicate}) get _parts {
    final phrases = <String>[];
    var open = '';
    for (var i = 0; i < tiles.length; i++) {
      open += tiles[i];
      if (closes[i]) {
        phrases.add(open);
        open = '';
      }
    }
    return (phrases: phrases, predicate: open);
  }

  /// Whether [order] (indices into [tiles]) reads as the sentence: its
  /// phrases in any order, then its predicate. 私は昨日 or 昨日私は;
  /// 法の前にすべての人は or すべての人は法の前に.
  bool accepts(List<int> order) {
    if (order.length != tiles.length || order.toSet().length != tiles.length) {
      return false;
    }
    final answer = [for (final i in order) tiles[i]].join();
    final (:phrases, :predicate) = _parts;
    return _orders(phrases).any((p) => p.join() + predicate == answer);
  }
}

/// Every order of [items]; there are at most four phrases.
Iterable<List<String>> _orders(List<String> items) sync* {
  if (items.length <= 1) {
    yield items;
    return;
  }
  for (var i = 0; i < items.length; i++) {
    final rest = [...items]..removeAt(i);
    for (final tail in _orders(rest)) {
      yield [items[i], ...tail];
    }
  }
}

/// A tile while the sentence is read: its text and what the next word
/// needs to know about it.
class _Tile {
  _Tile(
    this.text, {
    required this.head,
    required this.bare,
    required this.teForm,
  });

  String text;

  /// The first sense's parts of speech of its content word.
  final List<String> head;

  /// One uninflected word, nothing glued on: a noun that can take する.
  bool bare;

  /// Ends in a te-form, so a helper verb can follow (落として・しまう).
  bool teForm;

  /// The last thing glued on, if any.
  String? glued;

  /// [glued] is a particle.
  bool particle = false;

  void glue(String surface, {bool teForm = false, bool particle = false}) {
    text += surface;
    glued = surface;
    bare = false;
    this.teForm = teForm;
    this.particle = particle;
  }

  /// Closes a phrase that can move (see [SentenceTiles.closes]).
  bool get closesPhrase =>
      (_argumentEnds.contains(glued) &&
          head.any((p) => p == 'pn' || p.startsWith('n'))) ||
      (bare && head.contains('n') && head.contains('adv'));
}

bool _endsInTeForm(WordReading r) =>
    r.inflections.isNotEmpty && r.inflections.last == 'te-form';

/// [sentence] cut into tiles of one content word each, with what
/// leans on it glued on: particles, the copula and auxiliaries after
/// it, する or できる after a bare noun (参加した), helper verbs after a te-form
/// (落としてしまった), and a prefix or pre-noun word before it (お茶,
/// この本). Null when a part isn't Japanese or the dictionary misses a
/// stretch: such a puzzle would have tiles nobody could place.
SentenceTiles? tileSentence(String sentence, WordLexicon lexicon) {
  final trimmed = sentence.trim();
  final end = _endMarks.firstMatch(trimmed)?[0] ?? '';
  final body = trimmed.substring(0, trimmed.length - end.length);
  if (body.isEmpty || !_fit.hasMatch(body)) return null;

  final read = readText(body, lexicon);
  final tiles = <_Tile>[];
  final words = <TileWord>[];
  var ahead = '';
  var at = 0;
  for (final m in japaneseRun.allMatches(body)) {
    // Between runs only 、 can sit, and it closes the tile before it.
    final between = body.substring(at, m.start);
    if (between.isNotEmpty) {
      if (tiles.isEmpty || ahead.isNotEmpty) return null;
      tiles.last.glue(between);
    }
    at = m.end;
    final run = m[0]!;
    var covered = 0;
    for (final w in read[run] ?? const <TextWord>[]) {
      if (w.start != covered) return null;
      covered = w.end;
      final surface = run.substring(w.start, w.end);
      final reading = w.readings.first;
      final entry = reading.entry;
      final pos = entry.senses.isEmpty
          ? const <String>[]
          : entry.senses.first.pos.split(',');
      final last = tiles.lastOrNull;
      final glues =
          last != null &&
          ahead.isEmpty &&
          !last.text.endsWith('、') &&
          ((pos.isNotEmpty && pos.every(_gluePos.contains)) ||
              _particles.contains(surface) ||
              (pos.contains('exp') &&
                  _particleHeads.contains(surface[0]) &&
                  surface.length > 1) ||
              surface.startsWith('ん') ||
              (last.text.endsWith('に') && _afterNi.any(surface.startsWith)) ||
              (last.bare && _verbNouns.contains(entry.kana)) ||
              (last.teForm && _teHelpers.contains(entry.kana)));
      if (pos.any(_glueAheadPos.contains)) {
        ahead += surface;
      } else if (glues) {
        final particle =
            _particles.contains(surface) ||
            (pos.isNotEmpty && pos.every((p) => p == 'prt'));
        // が or を right after another case particle is never Japanese:
        // a misread (がつがつ as が・つがつ), whose tiles would mislead.
        if (particle &&
            last.particle &&
            _caseAfterCase.contains(surface) &&
            _argumentEnds.contains(last.glued)) {
          return null;
        }
        last.glue(surface, teForm: _endsInTeForm(reading), particle: particle);
      } else {
        tiles.add(
          _Tile(
            ahead + surface,
            head: pos,
            bare: reading.inflections.isEmpty,
            teForm: _endsInTeForm(reading),
          ),
        );
        ahead = '';
        words.add((kanji: entry.kanji, kana: entry.kana, rarity: entry.rarity));
      }
    }
    if (covered != run.length) return null;
  }
  if (ahead.isNotEmpty || tiles.isEmpty) return null;
  return SentenceTiles(
    tiles: [for (final t in tiles) t.text],
    closes: [
      for (var i = 0; i < tiles.length; i++)
        i < tiles.length - 1 &&
            (tiles[i].closesPhrase || tiles[i].text.endsWith('、')),
    ],
    end: end,
    words: words,
    particles: [for (final t in tiles) t.particle ? t.glued : null],
  );
}

/// [sentences] tiled against the dictionary at [dictionaryPath], with a
/// handle of its own: meant for `Isolate.run`, where the shared
/// [JmdictLookup.instance] can't reach the documents directory.
List<SentenceTiles?> tileSentencesWith(
  String dictionaryPath,
  List<String> sentences,
) {
  final lookup = JmdictLookup.openFile(dictionaryPath);
  try {
    final lexicon = _cached(lookup.byForms);
    return [for (final s in sentences) tileSentence(s, lexicon)];
  } finally {
    lookup.dispose();
  }
}

/// [lexicon] remembering each form's headwords, so a batch fetches and
/// decodes the forms its sentences share (の, に, か…) once.
WordLexicon _cached(WordLexicon lexicon) {
  final byForm = <String, List<JmdictHit>>{};
  return (forms) {
    final missing = forms.where((f) => !byForm.containsKey(f)).toSet();
    if (missing.isNotEmpty) {
      for (final f in missing) {
        byForm[f] = [];
      }
      for (final hit in lexicon(missing)) {
        if (missing.contains(hit.kanji)) byForm[hit.kanji]!.add(hit);
        if (hit.kana != hit.kanji && missing.contains(hit.kana)) {
          byForm[hit.kana]!.add(hit);
        }
      }
    }
    // A hit can answer two forms (its kanji and its kana); once is enough.
    return {for (final f in forms) ...byForm[f]!}.toList();
  };
}
