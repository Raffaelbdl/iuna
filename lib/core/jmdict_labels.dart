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
