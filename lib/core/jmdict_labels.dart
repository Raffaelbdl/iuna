/// The JMdict misc tags worth showing the learner, and the label each
/// gets in a sense's definition. Most misc values are linguistic
/// shorthand the learner doesn't need to see.
const jmdictMiscLabels = {
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

/// Joins the parts of a sense's definition: its note, then its labels.
const kDefinitionSeparator = ' · ';

/// Plain words for JMdict part-of-speech codes. Unlisted codes show as
/// they are.
const jmdictPosLabels = {
  'n': 'noun',
  'n-adv': 'adverbial noun',
  'n-t': 'time noun',
  'n-suf': 'noun suffix',
  'n-pref': 'noun prefix',
  'n-pr': 'proper noun',
  'pn': 'pronoun',
  'adj-i': 'i-adjective',
  'adj-ix': 'i-adjective',
  'adj-na': 'na-adjective',
  'adj-no': 'takes の',
  'adj-pn': 'pre-noun adjective',
  'adj-t': 'taru adjective',
  'adj-f': 'pre-noun',
  'adj-ku': 'archaic adjective',
  'adj-shiku': 'archaic adjective',
  'adj-nari': 'archaic adjective',
  'adv': 'adverb',
  'adv-to': 'adverb (takes と)',
  'aux': 'auxiliary',
  'aux-v': 'auxiliary verb',
  'aux-adj': 'auxiliary adjective',
  'conj': 'conjunction',
  'cop': 'copula',
  'ctr': 'counter',
  'exp': 'expression',
  'int': 'interjection',
  'num': 'number',
  'pref': 'prefix',
  'suf': 'suffix',
  'prt': 'particle',
  'unc': 'other',
  'v1': 'ichidan verb',
  'v1-s': 'ichidan verb',
  'vk': 'irregular verb (来る)',
  'vs': 'takes する',
  'vs-i': 'する verb',
  'vs-s': 'する verb',
  'vs-c': 'す verb',
  'vz': 'ずる verb',
  'vn': 'irregular verb',
  'vr': 'irregular verb',
  'v-unspec': 'verb',
  'vi': 'intransitive',
  'vt': 'transitive',
};

/// A sense's comma-separated POS codes as short plain words, e.g.
/// `v5k-s,vi` → "godan verb · intransitive".
String posLabel(String codes) {
  final out = <String>[];
  for (final raw in codes.split(',')) {
    final code = raw.trim();
    if (code.isEmpty) continue;
    final label =
        jmdictPosLabels[code] ??
        (code.startsWith('v5')
            ? 'godan verb'
            : code.startsWith('v2') || code.startsWith('v4')
            ? 'archaic verb'
            : code);
    if (!out.contains(label)) out.add(label);
  }
  return out.join(kDefinitionSeparator);
}
