/// What a dictionary form can be: the conjugation classes a rule turns
/// a form into, plus [polite] (the ます family), an intermediate no
/// headword carries.
enum WordType { v1, v5, vk, vs, adjI, copula, polite }

/// The classes a JMdict `pos` list conjugates as. Plain `vs` (a noun
/// that takes する) is not one: the noun doesn't inflect, する does.
Set<WordType> wordTypesOf(String posCsv) => {
  for (final p in posCsv.split(','))
    ?switch (p.trim()) {
      'v1' || 'v1-s' => WordType.v1,
      'vk' => WordType.vk,
      'vs-i' || 'vs-s' => WordType.vs,
      'adj-i' || 'adj-ix' => WordType.adjI,
      'cop' => WordType.copula,
      final p when p.startsWith('v5') => WordType.v5,
      _ => null,
    },
};

/// One way to read a surface form back to a dictionary form.
class Deinflection {
  const Deinflection(this.form, this.type, this.reasons);

  final String form;

  /// What [form] must conjugate as; null for the surface itself,
  /// which any headword may match.
  final WordType? type;

  /// The inflections undone, innermost first: 食べました gives
  /// `[polite, past]`.
  final List<String> reasons;
}

class _Rule {
  const _Rule(this.from, this.to, this.inTypes, this.out, this.reason);

  final String from;
  final String to;

  /// What the inflected form must be when it is itself the result of a
  /// rule. Empty: the rule only applies to the text as written.
  final Set<WordType> inTypes;
  final WordType out;
  final String reason;
}

const _none = <WordType>{};
const _asV1 = {WordType.v1};
const _asV5 = {WordType.v5};
const _asAdj = {WordType.adjI};
const _asPolite = {WordType.polite};

/// Godan rows: dictionary ending, then its a-, i-, e- and o-stems, the
/// te-form and the past. The bare imperative (読め) is left out: one
/// e-row kana turns too many pronouns into verbs (それ → 剃る).
const _godanRows = [
  ('う', 'わ', 'い', 'え', 'お', 'って', 'った'),
  ('く', 'か', 'き', 'け', 'こ', 'いて', 'いた'),
  ('ぐ', 'が', 'ぎ', 'げ', 'ご', 'いで', 'いだ'),
  ('す', 'さ', 'し', 'せ', 'そ', 'して', 'した'),
  ('つ', 'た', 'ち', 'て', 'と', 'って', 'った'),
  ('ぬ', 'な', 'に', 'ね', 'の', 'んで', 'んだ'),
  ('ぶ', 'ば', 'び', 'べ', 'ぼ', 'んで', 'んだ'),
  ('む', 'ま', 'み', 'め', 'も', 'んで', 'んだ'),
  ('る', 'ら', 'り', 'れ', 'ろ', 'って', 'った'),
];

/// The endings every verb class shares once its stems are known.
Iterable<_Rule> _verb(
  String base,
  WordType out, {
  required String neg,
  required String masu,
  required String te,
  required String ta,
  required String cond,
  required String vol,
  String? imp,
  required String passive,
  required String causative,
  String? potential,
}) sync* {
  _Rule r(String from, Set<WordType> inTypes, String reason) =>
      _Rule(from, base, inTypes, out, reason);
  final chau = '${te.substring(0, te.length - 1)}${te.endsWith('で') ? 'じゃう' : 'ちゃう'}';
  yield r('$negない', _asAdj, 'negative');
  yield r('$negず', _none, 'negative');
  yield r('$masuます', _asPolite, 'polite');
  yield r('$masuたい', _asAdj, 'want to');
  yield r('$masuながら', _none, 'while');
  yield r('$masuなさい', _none, 'polite command');
  yield r('$masuそう', _none, 'looks like');
  yield r('$masuすぎる', _asV1, 'too much');
  yield r(te, _none, 'te-form');
  yield r('$teいる', _asV1, 'ongoing');
  yield r('$teる', _asV1, 'ongoing');
  yield r(chau, _asV5, 'done');
  yield r(ta, _none, 'past');
  yield r('$taら', _none, 'if / when');
  yield r('$taり', _none, 'and so on');
  yield r(cond, _none, 'if');
  yield r(vol, _none, "let's");
  if (imp != null) yield r(imp, _none, 'command');
  yield r(passive, _asV1, 'passive');
  yield r(causative, _asV1, 'causative');
  if (potential != null) yield r(potential, _asV1, 'can');
}

final List<_Rule> _rules = [
  for (final (u, a, i, e, o, te, ta) in _godanRows)
    ..._verb(
      u,
      WordType.v5,
      neg: a,
      masu: i,
      te: te,
      ta: ta,
      cond: '$eば',
      vol: '$oう',
      passive: '$aれる',
      causative: '$aせる',
      potential: '$eる',
    ),
  // 行く is the one godan verb whose te-form breaks its row.
  for (final stem in ['行', 'い'])
    ..._verb(
      '$stemく',
      WordType.v5,
      neg: '$stemか',
      masu: '$stemき',
      te: '$stemって',
      ta: '$stemった',
      cond: '$stemけば',
      vol: '$stemこう',
      passive: '$stemかれる',
      causative: '$stemかせる',
    ),
  ..._verb(
    'る',
    WordType.v1,
    neg: '',
    masu: '',
    te: 'て',
    ta: 'た',
    cond: 'れば',
    vol: 'よう',
    imp: 'ろ',
    passive: 'られる',
    causative: 'させる',
    potential: 'れる',
  ),
  ..._verb(
    'する',
    WordType.vs,
    neg: 'し',
    masu: 'し',
    te: 'して',
    ta: 'した',
    cond: 'すれば',
    vol: 'しよう',
    imp: 'しろ',
    passive: 'される',
    causative: 'させる',
  ),
  for (final (base, ko, ki, ku) in [('くる', 'こ', 'き', 'く'), ('来る', '来', '来', '来')])
    ..._verb(
      base,
      WordType.vk,
      neg: ko,
      masu: ki,
      te: '$kiて',
      ta: '$kiた',
      cond: '$kuれば',
      vol: '$koよう',
      imp: '$koい',
      passive: '$koられる',
      causative: '$koさせる',
    ),
  // The honorific -aru verbs (ござる, くださる, なさる, いらっしゃる,
  // おっしゃる) drop the り of their stem before ます.
  const _Rule('います', 'る', _asPolite, WordType.v5, 'polite'),
  for (final (from, inTypes, reason) in const [
    ('かった', _none, 'past'),
    ('くない', _asAdj, 'negative'),
    ('くて', _none, 'te-form'),
    ('く', _none, 'adverb'),
    ('ければ', _none, 'if'),
    ('かったら', _none, 'if / when'),
    ('さ', _none, 'noun'),
    ('そう', _none, 'looks like'),
    ('すぎる', _asV1, 'too much'),
  ])
    _Rule(from, 'い', inTypes, WordType.adjI, reason),
  for (final (from, reason) in const [
    ('ました', 'past'),
    ('ません', 'negative'),
    ('ませんでした', 'negative past'),
    ('ましょう', "let's"),
    ('まして', 'te-form'),
  ])
    _Rule(from, 'ます', _none, WordType.polite, reason),
  for (final (from, to, reason) in const [
    ('でした', 'です', 'past'),
    ('でしょう', 'です', 'probably'),
    ('だった', 'だ', 'past'),
    ('だろう', 'だ', 'probably'),
  ])
    _Rule(from, to, _none, WordType.copula, reason),
];

final Map<String, List<_Rule>> _byLastChar = () {
  final out = <String, List<_Rule>>{};
  for (final r in _rules) {
    (out[r.from.substring(r.from.length - 1)] ??= []).add(r);
  }
  return out;
}();

/// Every dictionary form [surface] could be an inflection of, the
/// surface itself first.
List<Deinflection> deinflect(String surface) {
  final out = [Deinflection(surface, null, const [])];
  // Rules never lengthen a form by more than a kana, so this only
  // guards against a pathological chain.
  for (var i = 0; i < out.length && out.length < 64; i++) {
    final d = out[i];
    final rules = _byLastChar[d.form.substring(d.form.length - 1)];
    if (rules == null) continue;
    for (final r in rules) {
      if (d.type != null && !r.inTypes.contains(d.type)) continue;
      if (d.form.length <= r.from.length && r.to.length < 2) continue;
      if (!d.form.endsWith(r.from)) continue;
      final form = d.form.substring(0, d.form.length - r.from.length) + r.to;
      out.add(Deinflection(form, r.out, [r.reason, ...d.reasons]));
    }
  }
  return out;
}
