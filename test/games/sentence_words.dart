import 'package:iuna/core/deck_rules.dart';
import 'package:iuna/learn/words/segmenter.dart';

import '../learn/fake_words.dart';

/// [kTestWords] and what the sentence tests add to it.
final kSentenceWords = [
  ...kTestWords,
  word('猫', 'ねこ', 'cat'),
  word('魚', 'さかな', 'fish'),
  word('本', 'ほん', 'book'),
  word('昨日', 'きのう', 'yesterday', pos: 'n,adv'),
  word('毎日', 'まいにち', 'every day', pos: 'n,adv'),
  word('此の', 'この', 'this', pos: 'adj-pn'),
  word('で', 'で', 'at, in, by', pos: 'prt', rarity: Rarity.superRare),
  word('仕舞う', 'しまう', 'to finish, to do completely', pos: 'v5u,vt'),
  word('図書館', 'としょかん', 'library', rarity: Rarity.rare),
  word('鰻', 'うなぎ', 'eel', rarity: Rarity.ssr),
  word('出来る', 'できる', 'to be able to', pos: 'v1,vi'),
];

WordLexicon sentenceLexicon() => fakeLexicon(kSentenceWords);
