import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/jmdict_lookup.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/learn/agent/bookmark_tool.dart';
import 'package:iuna/learn/agent/chat_controller.dart';
import 'package:iuna/learn/agent/chat_store.dart';
import 'package:iuna/learn/agent/tools.dart';
import 'package:iuna/learn/agent/tutor_tools.dart';
import 'package:iuna/learn/db/learn_database.dart';
import 'package:iuna/learn/db/learn_repository.dart';
import 'package:iuna/learn/deck_bookmarks.dart';
import 'package:path/path.dart' as p;

import '../helpers/fake_path_provider.dart';
import '../helpers/jmdict_sidecar.dart';
import 'fake_llm.dart';

/// A one-word JMdict sidecar where [DictDownload] would put it.
void _installDictionary(String docs, String kanji, String kana) {
  writeTestSidecar(p.join(docs, kJmdictFileName), [
    SidecarEntry(
      kanji: kanji,
      kana: kana,
      senses: const [
        JmdictSense(pos: 'n,vs', gloss: 'jumping to a hasty conclusion', def: ''),
      ],
      rarity: Rarity.ssr,
      freqRank: 12000,
    ),
  ]);
}

final _noQuiz = ToolRunContext(askQuiz: (_) async => const {});

void main() {
  late AppDatabase deck;
  late IunaRepository repo;
  late DeckBookmarks bookmarks;
  late Directory docs;

  setUp(() async {
    deck = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IunaRepository(deck);
    bookmarks = DeckBookmarks(repo);
    docs = useTempDocumentsDir('iuna_bookmarks_');
  });

  tearDown(() async {
    JmdictLookup.instance.dispose();
    await deck.close();
  });

  Future<int> card(String kanji, String kana) => deck
      .into(deck.cards)
      .insert(CardsCompanion.insert(kanji: kanji, kana: kana, meaning: kanji));

  Future<void> own(int cardId) {
    final now = DateTime(2026, 9, 11);
    return deck.into(deck.userCards).insert(
          UserCardsCompanion.insert(cardId: Value(cardId), nextDue: now, obtainedAt: now),
        );
  }

  group('DeckBookmarks', () {
    test('a deck card goes on the wishlist, once', () async {
      final id = await card('会議', 'かいぎ');
      expect(await bookmarks.bookmark('会議', 'かいぎ'), BookmarkOutcome.bookmarked);
      expect(await repo.wishedCardIds(), [id]);
      expect(await bookmarks.bookmark('会議', 'かいぎ'), BookmarkOutcome.alreadyBookmarked);
      expect(await repo.wishedCardIds(), [id]);
    });

    test('a card already in the collection is left alone', () async {
      await own(await card('行く', 'いく'));
      expect(await bookmarks.bookmark('行く', 'いく'), BookmarkOutcome.owned);
      expect(await repo.wishedCardIds(), isEmpty);
    });

    test('a word the deck lacks comes in from the dictionary', () async {
      _installDictionary(docs.path, '早合点', 'はやがてん');
      expect(await bookmarks.bookmark('早合点', 'はやがてん'), BookmarkOutcome.bookmarked);
      final card = await (deck.select(deck.cards)..where((c) => c.kanji.equals('早合点')))
          .getSingle();
      expect(card.source, CardSource.user);
      expect(await repo.wishedCardIds(), [card.id]);
      expect(await deck.select(deck.userCards).get(), isEmpty,
          reason: 'the reveal loop is the only way to own a card');

      expect(await bookmarks.bookmark('早合点', 'はやかてん'), BookmarkOutcome.notFound);
    });

    test('without the dictionary, a word the deck lacks says so', () async {
      expect(await bookmarks.bookmark('早合点', 'はやがてん'), BookmarkOutcome.noDictionary);
      expect(await deck.select(deck.cards).get(), isEmpty);
    });
  });

  group('bookmark_words', () {
    test('reports every word; the chip names only what it bookmarked', () async {
      await card('会議', 'かいぎ');
      await card('ちょっと', 'ちょっと');
      await own(await card('行く', 'いく'));
      final tool = BookmarkWordsTool(bookmarks);

      final result = await tool.run({
        // As a string, the way some models send nested arrays.
        'words': jsonEncode([
          {'word': '会議（かいぎ）'},
          {'word': '行く', 'reading': 'いく'},
          {'word': 'ちょっと'},
          {'word': '会議', 'reading': 'かいぎ'},
        ]),
      }, _noQuiz);

      expect(jsonDecode(result), {
        'words': [
          {'word': '会議', 'reading': 'かいぎ', 'result': 'bookmarked'},
          {'word': '行く', 'reading': 'いく', 'result': BookmarkOutcome.owned.wire},
          {'word': 'ちょっと', 'reading': 'ちょっと', 'result': 'bookmarked'},
        ],
      });
      expect(tool.activity(const {}, result)?.label, 'Bookmarked · 会議, ちょっと');
    });

    test('nothing bookmarked leaves nothing in the history', () async {
      await own(await card('行く', 'いく'));
      final tool = BookmarkWordsTool(bookmarks);
      final result = await tool.run({
        'words': [
          {'word': '行く', 'reading': 'いく'},
        ],
      }, _noQuiz);
      expect(tool.activity(const {}, result), isNull);
      expect(tool.activity(const {}, 'error: words must be a list'), isNull);
    });

    test('a bad list is refused before any word is bookmarked', () async {
      await card('会議', 'かいぎ');
      final tool = BookmarkWordsTool(bookmarks);
      final bad = <Object?>[
        null,
        const [],
        'not json',
        [
          {'word': '会議', 'reading': 'かいぎ'},
          {'word': '経費'},
        ],
        List.filled(kMaxBookmarkWords + 1, {'word': 'あ', 'reading': 'あ'}),
      ];
      for (final words in bad) {
        await expectLater(tool.run({'words': words}, _noQuiz), throwsA(isA<ToolError>()),
            reason: '$words');
      }
      expect(await repo.wishedCardIds(), isEmpty);
    });

    test('the tutor bookmarks mid-session', () async {
      final learnDb = LearnDatabase.forTesting(NativeDatabase.memory());
      final learn = LearnRepository(learnDb);
      addTearDown(learnDb.close);
      addTearDown(learn.dispose);
      final course = await learn.createCourse(title: 'Business Japanese', goal: '');
      final session = await learn.openSession(course.id, kRoomSessionKey);
      final id = await card('会議', 'かいぎ');
      final llm = FakeLlm([
        callTool('bookmark_words', {
          'words': [
            {'word': '会議', 'reading': 'かいぎ'},
          ],
        }),
        say('会議 is bookmarked.'),
      ]);
      final chat = ChatController(
        llm: llm,
        store: SessionChatStore(learn, session.id),
        systemPrompt: () async => 'SYSTEM',
        model: () async => 'test/model',
        tools: tutorTools(
          TutorScope(repo: learn, courseId: course.id, sessionKey: kRoomSessionKey),
          bookmarks: bookmarks,
        ),
        onUsage: (u, {required model, required kind}) async {},
      );
      addTearDown(chat.dispose);
      await chat.open();
      await chat.send('Keep 会議 for me');

      expect(await repo.wishedCardIds(), [id]);
      expect(llm.requests.first.tools.map((t) => (t['function'] as Map)['name']),
          contains('bookmark_words'));
      final reply = llm.requests.last.messages.singleWhere((m) => m['role'] == 'tool');
      expect(jsonDecode(reply['content'] as String), {
        'words': [
          {'word': '会議', 'reading': 'かいぎ', 'result': 'bookmarked'},
        ],
      });
    });
  });
}
