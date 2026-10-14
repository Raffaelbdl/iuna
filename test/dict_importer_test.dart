// End-to-end test for the JMdict importer (`tools/dict_importer.dart`).
//
// We feed a hand-rolled JMdict-shaped XML fragment through the streaming
// parser, write the result into a temp sqlite file with the canonical
// schema, then mount it as a Drift `AppDatabase` and verify that the
// repo's `ownedCards`, `sensesForCard`, and `examplesForCard` round-trip
// the imported data correctly.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/core/deck_rules.dart';
import 'package:iuna/db/database.dart' as iuna;
import 'package:iuna/db/repository.dart';
import 'package:sqlite3/sqlite3.dart';

import '../tools/dict_importer.dart';
import '../tools/seed_schema.dart';

// Two real JMdict-style entries plus a third with no priority tag (to
// confirm the keep-filter works). DOCTYPE is included so XmlEntityMapping
// gets exercised on the `&v1;` / `&n;` / `&uk;` references.
const _fixture = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE JMdict [
  <!ENTITY n "noun (common)">
  <!ENTITY v1 "Ichidan verb">
  <!ENTITY vt "transitive verb">
  <!ENTITY uk "word usually written using kana alone">
]>
<JMdict>
  <entry>
    <ent_seq>1582920</ent_seq>
    <k_ele>
      <keb>食べる</keb>
      <ke_pri>ichi1</ke_pri>
      <ke_pri>news1</ke_pri>
      <ke_pri>nf04</ke_pri>
    </k_ele>
    <r_ele>
      <reb>たべる</reb>
      <re_pri>ichi1</re_pri>
      <re_pri>news1</re_pri>
      <re_pri>nf04</re_pri>
    </r_ele>
    <sense>
      <pos>&v1;</pos>
      <pos>&vt;</pos>
      <gloss>to eat</gloss>
    </sense>
    <sense>
      <pos>&v1;</pos>
      <pos>&vt;</pos>
      <gloss>to live on</gloss>
      <gloss>to subsist on</gloss>
      <s_inf>figurative</s_inf>
    </sense>
    <sense>
      <pos>&v1;</pos>
      <gloss xml:lang="fre">manger</gloss>
    </sense>
  </entry>
  <entry>
    <ent_seq>1000000</ent_seq>
    <r_ele>
      <reb>ありがとう</reb>
      <re_pri>spec1</re_pri>
    </r_ele>
    <sense>
      <pos>&n;</pos>
      <misc>&uk;</misc>
      <gloss>thank you</gloss>
      <example>
        <ex_srce exsrc_type="tat">42</ex_srce>
        <ex_text>ありがとう</ex_text>
        <ex_sent xml:lang="jpn">本当にありがとう。</ex_sent>
        <ex_sent xml:lang="eng">Thank you very much.</ex_sent>
      </example>
    </sense>
  </entry>
  <entry>
    <ent_seq>9999999</ent_seq>
    <k_ele><keb>無位無冠</keb></k_ele>
    <r_ele><reb>むいむかん</reb></r_ele>
    <sense>
      <pos>&n;</pos>
      <gloss>without rank or title</gloss>
    </sense>
  </entry>
</JMdict>
''';

Stream<List<int>> _bytes(String xml) =>
    Stream.value(utf8.encode(xml));

void main() {
  test('parseJmdictXml yields one entry per <entry>', () async {
    final entries = await parseJmdictXml(_bytes(_fixture), gzipped: false)
        .toList();

    expect(entries.length, 3);

    final taberu = entries[0];
    expect(taberu.kanji, '食べる');
    expect(taberu.kana, 'たべる');
    expect(taberu.priorityTags, containsAll({'ichi1', 'news1', 'nf04'}));
    expect(taberu.senses.length, 2,
        reason: 'non-English glosses are dropped, leaving 2 senses');
    expect(taberu.senses.first.pos, ['v1', 'vt'],
        reason: 'JMdict POS entities preserved as their names');
    expect(taberu.senses.first.glosses, ['to eat']);
    expect(taberu.senses[1].note, 'figurative');

    final arigatou = entries[1];
    expect(arigatou.kanji, 'ありがとう',
        reason: 'kana-only entries fall back to kana for the kanji slot');
    expect(arigatou.kana, 'ありがとう');
    expect(arigatou.senses.first.misc, ['uk']);
    expect(arigatou.exampleSentences, ['本当にありがとう。']);
  });

  test('rarityFor honours priority precedence', () {
    expect(
      rarityFor(priorityTags: {'ichi1', 'news1', 'nf04'}),
      Rarity.common,
    );
    expect(rarityFor(priorityTags: {'spec1'}), Rarity.superRare);
    expect(rarityFor(priorityTags: {'nf12'}), Rarity.ssr);
    expect(rarityFor(priorityTags: {'nf30'}), Rarity.ur);
    expect(rarityFor(priorityTags: const {}, jlptLevel: 5), Rarity.common);
    expect(rarityFor(priorityTags: const {}, jlptLevel: 1), Rarity.ur);
    expect(rarityFor(priorityTags: const {}), Rarity.ur);
  });

  test('keepEntry drops entries with no priority and no JLPT', () {
    expect(
      keepEntry(priorityTags: const {}, jlptLevel: null),
      isFalse,
    );
    expect(
      keepEntry(priorityTags: const {'spec1'}, jlptLevel: null),
      isTrue,
    );
    expect(
      keepEntry(priorityTags: const {}, jlptLevel: 3),
      isTrue,
    );
    expect(
      keepEntry(
        priorityTags: const {},
        jlptLevel: null,
        includeUntagged: true,
      ),
      isTrue,
    );
  });

  test(
    'importInto round-trips through the Drift repo',
    () async {
      // Write through the importer into a real sqlite file, then mount
      // it via Drift's NativeDatabase so we can exercise the production
      // repository methods against importer-shaped data.
      final tmp = await Directory.systemTemp.createTemp('iuna_dict_');
      addTearDown(() async {
        if (tmp.existsSync()) await tmp.delete(recursive: true);
      });
      final dbPath = '${tmp.path}/seed.sqlite';

      final native = sqlite3.open(dbPath);
      createSchema(native);
      final stats = await importInto(
        native,
        parseJmdictXml(_bytes(_fixture), gzipped: false),
        jlpt: const {('食べる', 'たべる'): 5},
      );
      native.dispose();

      expect(stats.cards, 2,
          reason: 'untagged 無位無冠 should be dropped');
      expect(stats.senses, 3,
          reason: '2 senses for 食べる + 1 for ありがとう');
      expect(stats.examples, 1);

      final db =
          iuna.AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      addTearDown(db.close);
      final repo = IunaRepository(db);

      final taberu = await (db.select(db.cards)
            ..where((c) => c.kanji.equals('食べる')))
          .getSingle();

      // Mark 食べる as owned so ownedCards picks it up.
      await db.into(db.userCards).insert(iuna.UserCardsCompanion.insert(
            cardId: Value(taberu.id),
            nextDue: DateTime.now(),
            obtainedAt: DateTime.now(),
          ));

      final owned = await repo.ownedCards();
      expect(owned.length, 1);
      expect(owned.first.card.kanji, '食べる');
      expect(owned.first.card.rarity, iuna.Rarity.common,
          reason: 'ichi1+news1+nf04 → Common');
      expect(owned.first.card.jlptLevel, 5,
          reason: 'Tanos overlay should set N5');

      final senses = await repo.sensesForCard(taberu.id);
      expect(senses.map((s) => s.ordinal).toList(), [1, 2]);
      expect(senses.first.pos, 'v1,vt');
      expect(senses.first.gloss, 'to eat');
      expect(senses[1].definition, 'figurative');

      final arigatou = await (db.select(db.cards)
            ..where((c) => c.kanji.equals('ありがとう')))
          .getSingle();
      expect(arigatou.rarity, iuna.Rarity.superRare);
      final examples = await repo.examplesForCard(arigatou.id);
      expect(examples.map((e) => e.sentence).toList(), ['本当にありがとう。']);
    },
  );
}
