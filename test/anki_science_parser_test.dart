// Tests for the "Science Terms" notetype parser. The interesting part
// is field 1: Anki ruby syntax with pitch-accent markers and "no ruby"
// markers interleaved, which have to be told apart from real readings.

import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/core/deck_rules.dart';
import 'package:sqlite3/sqlite3.dart';

import '../tools/anki/science_parser.dart';

void main() {
  group('ruby scanner', () {
    test('drops trailing pitch accent', () {
      final r = parseScienceRuby('連想[れんそう][0] 配列[はいれつ][0]');
      expect(r.kanji, '連想配列');
      expect(r.kana, 'れんそうはいれつ');
      expect(r.furigana, '連想[れんそう] 配列[はいれつ]');
    });

    test('keeps okurigana between ruby segments', () {
      final r = parseScienceRuby('繰[く]り 返[かえ]し[ ][0]');
      expect(r.kanji, '繰り返し');
      expect(r.kana, 'くりかえし');
    });

    test('a whitespace ruby means "this segment has no reading"', () {
      final r = parseScienceRuby('ルクス[ ][1]');
      expect(r.kanji, 'ルクス');
      expect(r.kana, 'ルクス');
      expect(r.furigana, 'ルクス');
    });

    test('katakana prefixes are literal text, not ruby bases', () {
      final r = parseScienceRuby('サブ 名[な]前[まえ][?] 空間[くうかん][0]の 宣言[せんげん][3]');
      expect(r.kanji, 'サブ名前空間の宣言');
      expect(r.kana, 'サブなまえくうかんのせんげん');
    });

    test('&nbsp; inside a marker is whitespace', () {
      final r = parseScienceRuby('20 馬[ば]力[りき][?]のエンジン[&nbsp; ][1]');
      expect(r.kanji, '20馬力のエンジン');
      expect(r.kana, '20ばりきのエンジン');
    });

    test('a dangling dash left by a stripped marker is trimmed', () {
      final r = parseScienceRuby('雌[し]雄[ゆう]同株[どうしゅ][1] - [0]');
      expect(r.kanji, '雌雄同株');
      expect(r.kana, 'しゆうどうしゅ');
    });

    test('a trailing ー survives after katakana but not after kanji', () {
      expect(parseScienceRuby('サーバー[ ][1]').kana, 'サーバー');
      expect(parseScienceRuby('第四紀[だいよんき]ー[ ][0]').kanji, '第四紀');
    });
  });

  group('alternatives', () {
    test('・ / ； / <br> all cut the entry down to its first form', () {
      expect(scienceFirstAlternative('ソフト・ソフトウェア'), 'ソフト');
      expect(scienceFirstAlternative('キーと値の組；名前と値のペア'), 'キーと値の組');
      expect(scienceFirstAlternative('コンテンツ管理システム<br>CMS'), 'コンテンツ管理システム');
    });

    test('markup around the expression is stripped', () {
      expect(scienceFirstAlternative('<div>彗星</div>'), '彗星');
    });
  });

  test('parses a synthetic Science Terms note end-to-end', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    db.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, mid INTEGER, '
        'flds TEXT NOT NULL)');

    const sep = '\x1f';
    final flds = [
      '拡張機能',
      '拡[かく]張[ちょう][0] 機[き]能[のう][1]',
      'Extension / Addon',
      'a package that adds capability to an existing program',
      '',
      'computer science',
    ].join(sep);

    db.execute('INSERT INTO notes (id, mid, flds) VALUES (7, 1, ?)', [flds]);

    final parser = ScienceParser(
      db,
      modelId: 1,
      rarityResolver: (kanji, kana) => (rarity: Rarity.ssr.index, jlptLevel: 2),
    );
    final entries = parser.parseAll();

    expect(entries, hasLength(1));
    final e = entries.single;
    expect(e.kanji, '拡張機能');
    expect(e.kana, 'かくちょうきのう');
    expect(e.furigana, '拡[かく]張[ちょう] 機[き]能[のう]');
    expect(e.meaning, 'Extension / Addon');
    expect(e.rarity, Rarity.ssr.index);
    expect(e.jlpt, 2);

    expect(e.senses, hasLength(1));
    expect(e.senses.single.pos, 'computer science');
    expect(e.senses.single.gloss, 'Extension / Addon');
    expect(
      e.senses.single.definition,
      'a package that adds capability to an existing program',
    );
    expect(parser.stats.kept, 1);
    expect(parser.stats.dropped, 0);
  });

  test('a note with no translation is dropped', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    db.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, mid INTEGER, '
        'flds TEXT NOT NULL)');
    db.execute(
      'INSERT INTO notes (id, mid, flds) VALUES (1, 1, ?)',
      ['素粒子\x1f素粒子[そりゅうし][0]\x1f\x1f\x1f\x1f'],
    );

    final parser = ScienceParser(db, modelId: 1);
    expect(parser.parseAll(), isEmpty);
    expect(parser.stats.dropped, 1);
  });

  test('expression wins when the reading describes a different headword',
      () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    db.execute('CREATE TABLE notes (id INTEGER PRIMARY KEY, mid INTEGER, '
        'flds TEXT NOT NULL)');
    db.execute(
      'INSERT INTO notes (id, mid, flds) VALUES (1, 1, ?)',
      ['x^n\x1fエックスのエヌ 乗[じょう][0]\x1fx to the power n\x1f\x1f\x1f'],
    );

    final parser = ScienceParser(db, modelId: 1);
    final e = parser.parseAll().single;
    expect(e.kanji, 'x^n');
    expect(e.kana, 'エックスのエヌじょう');
    // Ruby can't be trusted against a headword it doesn't describe.
    expect(e.furigana, isNull);
    expect(parser.stats.headwordMismatch, 1);
  });
}
