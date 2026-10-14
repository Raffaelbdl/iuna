import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart' show Rarity;
import 'package:iuna/db/jmdict_lookup.dart';
import 'package:path/path.dart' as p;

import 'helpers/fake_path_provider.dart';
import 'helpers/jmdict_sidecar.dart';

void main() {
  late Directory tmpDir;

  setUp(() {
    tmpDir = useTempDocumentsDir('iuna_jmdict_lookup_');
    JmdictLookup.instance.dispose();
  });

  tearDown(JmdictLookup.instance.dispose);

  test('isOpen is false before warmUp and when no sidecar exists',
      () async {
    expect(JmdictLookup.instance.isOpen, isFalse);
    await JmdictLookup.instance.warmUp();
    expect(JmdictLookup.instance.isOpen, isFalse,
        reason: 'no sidecar on disk → warmUp is a no-op');
    expect(await JmdictLookup.instance.search('行'), isEmpty);
  });

  test('search prefix-matches kanji and kana, ordered by freq_rank',
      () async {
    writeTestSidecar(p.join(tmpDir.path, kJmdictFileName), [
      SidecarEntry(
        kanji: '行く',
        kana: 'いく',
        senses: const [JmdictSense(pos: 'v5k-s', gloss: 'to go', def: '')],
        rarity: Rarity.common,
        freqRank: 50,
      ),
      SidecarEntry(
        kanji: '行う',
        kana: 'おこなう',
        senses: const [
          JmdictSense(pos: 'v5u', gloss: 'to perform, to do', def: ''),
        ],
        rarity: Rarity.rare,
        freqRank: 800,
      ),
      SidecarEntry(
        kanji: '幾何',
        kana: 'いか',
        senses: const [JmdictSense(pos: 'n', gloss: 'geometry', def: '')],
        rarity: Rarity.superRare,
        freqRank: 12000,
      ),
      SidecarEntry(
        kanji: '稀少',
        kana: 'きしょう',
        senses: const [
          JmdictSense(pos: 'adj-na', gloss: 'rare, scarce', def: ''),
        ],
        rarity: Rarity.ssr,
        // No freq rank — should sort last.
      ),
    ]);

    final byKanji = await JmdictLookup.instance.search('行');
    expect(byKanji.map((h) => h.kanji), ['行く', '行う'],
        reason: '行く (rank 50) ranked above 行う (rank 800)');

    final byKana = await JmdictLookup.instance.search('い');
    expect(
      byKana.map((h) => '${h.kanji}/${h.kana}'),
      ['行く/いく', '幾何/いか'],
      reason:
          'kana prefix い matches both; freq_rank 50 < 12000 puts 行く first',
    );

    final empty = await JmdictLookup.instance.search('');
    expect(empty, isEmpty);
  });

  test('search returns null freq_rank entries last', () async {
    writeTestSidecar(p.join(tmpDir.path, kJmdictFileName), [
      SidecarEntry(
        kanji: 'aaa',
        kana: 'aaa',
        senses: const [JmdictSense(pos: '', gloss: 'first', def: '')],
        rarity: Rarity.ur,
        // unranked
      ),
      SidecarEntry(
        kanji: 'aab',
        kana: 'aab',
        senses: const [JmdictSense(pos: '', gloss: 'second', def: '')],
        rarity: Rarity.common,
        freqRank: 9999,
      ),
    ]);

    final hits = await JmdictLookup.instance.search('aa');
    expect(hits.map((h) => h.kanji), ['aab', 'aaa'],
        reason: 'ranked entry first, unranked last');
  });

  test('exact returns matching entry only when both kanji and kana hit',
      () async {
    writeTestSidecar(p.join(tmpDir.path, kJmdictFileName), [
      SidecarEntry(
        kanji: '食べる',
        kana: 'たべる',
        senses: const [
          JmdictSense(pos: 'v1,vt', gloss: 'to eat', def: ''),
          JmdictSense(pos: 'v1,vt', gloss: 'to live on', def: 'figurative'),
        ],
        rarity: Rarity.common,
        jlptLevel: 5,
        freqRank: 200,
      ),
    ]);

    final hit = await JmdictLookup.instance.exact('食べる', 'たべる');
    expect(hit, isNotNull);
    expect(hit!.kanji, '食べる');
    expect(hit.kana, 'たべる');
    expect(hit.senses.length, 2);
    expect(hit.senses.first.pos, 'v1,vt');
    expect(hit.senses.first.gloss, 'to eat');
    expect(hit.senses[1].def, 'figurative');
    expect(hit.rarity, Rarity.common);
    expect(hit.jlptLevel, 5);
    expect(hit.freqRank, 200);

    expect(await JmdictLookup.instance.exact('食べる', 'wrong'), isNull);
    expect(await JmdictLookup.instance.exact('wrong', 'たべる'), isNull);
  });

  test('dispose lets the file be deleted and reopens cleanly later',
      () async {
    final path = p.join(tmpDir.path, kJmdictFileName);
    writeTestSidecar(path, [
      SidecarEntry(
        kanji: 'x',
        kana: 'y',
        senses: const [JmdictSense(pos: '', gloss: 'g', def: '')],
        rarity: Rarity.common,
      ),
    ]);

    await JmdictLookup.instance.warmUp();
    expect(JmdictLookup.instance.isOpen, isTrue);

    JmdictLookup.instance.dispose();
    expect(JmdictLookup.instance.isOpen, isFalse);

    File(path).deleteSync();
    await JmdictLookup.instance.warmUp();
    expect(JmdictLookup.instance.isOpen, isFalse,
        reason: 're-warmUp after delete is a no-op');
    expect(await JmdictLookup.instance.search('x'), isEmpty);
  });
}
