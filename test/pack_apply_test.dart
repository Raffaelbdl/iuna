// Applying a pack writes to the user's live deck, so the property that
// matters most is that it never destroys anything: a headword the deck
// already carries keeps its id, its senses and its scheduling state,
// and re-applying is a no-op.
//
// Runs against the real `packs/science.json`, not a fixture, so a
// parser change that corrupts the shipped pack fails here.

import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/core/pack_format.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/repository.dart';

const _packedKanji = '拡張機能';
const _packedKana = 'かくちょうきのう';
const _version = 'testversion00000';

Map<String, dynamic> _sciencePack() {
  final file = File('packs/science.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  late AppDatabase db;
  late IunaRepository repo;
  late Map<String, dynamic> pack;

  setUpAll(() {
    pack = _sciencePack();
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IunaRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> cardCount() async {
    final count = db.cards.id.count();
    final row =
        await (db.selectOnly(db.cards)..addColumns([count])).getSingle();
    return row.read(count)!;
  }

  test('the shipped pack is a readable format-1 document', () {
    expect(pack['format'], kPackFormatVersion);
    expect(pack['pack'], 'science');
    expect(pack['cards'], isA<List>());
    expect((pack['cards'] as List), hasLength(greaterThan(900)));
    // Credits travel with the payload so they survive offline.
    expect(pack['source'], isA<Map>());
    expect((pack['source'] as Map)['url'], contains('ankiweb.net'));
  });

  test('applying lands the cards and records the pack', () async {
    final result = await repo.applyPack(pack, version: _version);
    expect(result.added, (pack['cards'] as List).length);
    expect(result.tagged, 0);
    expect(await cardCount(), result.added);

    expect(await repo.availablePacks(), ['science']);
    expect(await repo.packLabels(), {'science': 'Science & Programming'});

    final installed = (await repo.installedPacks()).single;
    expect(installed.name, 'science');
    expect(installed.version, _version);
    expect(installed.cardCount, result.added);
    expect(installed.sourceUrl, contains('ankiweb.net'));

    final card = await (db.select(db.cards)
          ..where((c) => c.kanji.equals(_packedKanji)))
        .getSingle();
    expect(card.kana, _packedKana);
    expect(card.pack, 'science');
    expect(card.source, CardSource.user);

    final senses = await (db.select(db.cardSenses)
          ..where((s) => s.cardId.equals(card.id)))
        .get();
    expect(senses, hasLength(1));
  });

  test('re-applying is a no-op', () async {
    await repo.applyPack(pack, version: _version);
    final before = await cardCount();

    final again = await repo.applyPack(pack, version: _version);
    expect(again.added, 0);
    expect(again.tagged, 0, reason: 'already tagged, nothing left to claim');
    expect(await cardCount(), before);
    expect(await repo.installedPacks(), hasLength(1));
  });

  test('an existing headword keeps its id, senses and review state',
      () async {
    final id = await db.into(db.cards).insert(
          CardsCompanion.insert(
            kanji: _packedKanji,
            kana: _packedKana,
            meaning: 'the dictionary wording',
            rarity: const Value(Rarity.rare),
          ),
        );
    await db.into(db.cardSenses).insert(
          CardSensesCompanion.insert(
            cardId: id,
            ordinal: 1,
            gloss: 'the dictionary gloss',
          ),
        );
    final due = DateTime(2026, 8, 7, 9);
    await db.into(db.userCards).insert(
          UserCardsCompanion.insert(
            cardId: Value(id),
            level: const Value(7),
            intervalMinutes: const Value(4320),
            nextDue: due,
            obtainedAt: due,
          ),
        );

    final result = await repo.applyPack(pack, version: _version);
    expect(result.tagged, 1);

    final card = await (db.select(db.cards)
          ..where((c) => c.kanji.equals(_packedKanji)))
        .getSingle();
    expect(card.id, id, reason: 'same row, not a replacement');
    expect(card.meaning, 'the dictionary wording');
    expect(card.rarity, Rarity.rare);
    expect(card.pack, 'science', reason: 'gains the tag and nothing else');

    final senses = await (db.select(db.cardSenses)
          ..where((s) => s.cardId.equals(id)))
        .get();
    expect(senses, hasLength(1));
    expect(senses.single.gloss, 'the dictionary gloss');

    final userCard = await (db.select(db.userCards)
          ..where((u) => u.cardId.equals(id)))
        .getSingle();
    expect(userCard.level, 7);
    expect(userCard.intervalMinutes, 4320);
    expect(userCard.nextDue, due);
  });

  test('a pack from a newer format version is refused', () async {
    final future = {...pack, 'format': kPackFormatVersion + 1};
    await expectLater(
      repo.applyPack(future, version: _version),
      throwsA(isA<PackFormatException>()),
    );
    expect(await cardCount(), 0, reason: 'refused before writing anything');
  });

  test('a malformed pack is refused', () async {
    await expectLater(
      repo.applyPack({'format': 1, 'label': 'nope'}, version: _version),
      throwsA(isA<PackFormatException>()),
    );
  });

  test('a bad card entry aborts the whole apply', () async {
    final broken = {
      ...pack,
      'cards': [
        (pack['cards'] as List).first,
        {'kanji': '素粒子', 'meaning': 'no kana here'},
      ],
    };
    await expectLater(
      repo.applyPack(broken, version: _version),
      throwsA(isA<PackFormatException>()),
    );
    expect(await cardCount(), 0,
        reason: 'the transaction rolls back the cards written before it');
    expect(await repo.installedPacks(), isEmpty);
  });

  test('headwords are keyed unambiguously', () async {
    // "20 hp"+"x" and "20"+"hp x" must not collide on the dedup key.
    final collide = {
      ...pack,
      'cards': [
        {'kanji': '20 hp', 'kana': 'x', 'meaning': 'one', 'senses': []},
        {'kanji': '20', 'kana': 'hp x', 'meaning': 'two', 'senses': []},
      ],
    };
    final result = await repo.applyPack(collide, version: _version);
    expect(result.added, 2);
  });
}
