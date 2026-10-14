// Renders selected scenes to PNG files in test/screenshots/. Run with:
//   flutter test --update-goldens test/screenshots_test.dart
//
// The fonts under test/fonts/ are *not* shipped with the app — they
// only exist so widget tests render Japanese glyphs instead of the
// default test boxes (tools/setup_test_fonts.sh links them). Every face
// is aliased to the "Roboto" family so the entire UI uses them.
@Tags(['golden'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/learn/agent/tutor_prompt.dart';
import 'package:iuna/learn/db/learn_database.dart';
import 'package:iuna/learn/db/learn_repository.dart';
import 'package:iuna/learn/learn.dart';
import 'package:iuna/learn/learn_settings.dart';
import 'package:iuna/learn/llm/llm.dart';
import 'package:iuna/learn/llm/transcriber.dart';
import 'package:iuna/learn/screens/ask_screen.dart';
import 'package:iuna/learn/screens/course_screen.dart';
import 'package:iuna/learn/screens/learn_screen.dart';
import 'package:iuna/learn/screens/tutor_chat_screen.dart';
import 'package:iuna/learn/voice/dictation.dart';
import 'package:iuna/screens/booster_reveal_screen.dart';
import 'package:iuna/screens/card_detail_screen.dart';
import 'package:iuna/screens/collection_screen.dart';
import 'package:iuna/screens/home_screen.dart';
import 'package:iuna/screens/pack_intro_screen.dart';
import 'package:iuna/screens/review_done_screen.dart';
import 'package:iuna/screens/review_screen.dart';
import 'package:iuna/screens/settings_screen.dart';
import 'package:iuna/screens/stats_screen.dart';
import 'package:iuna/theme/iuna_theme.dart';

import 'helpers/fake_path_provider.dart';
import 'learn/fake_llm.dart';
import 'learn/fake_photos.dart';
import 'learn/fake_voice.dart';

/// The Flutter SDK's cache: from FLUTTER_ROOT when set, else from the
/// test runner itself (`<sdk>/bin/cache/artifacts/engine/<host>/flutter_tester`).
String _sdkArtifacts() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) return '$root/bin/cache/artifacts';
  return File(Platform.resolvedExecutable).parent.parent.parent.path;
}

Future<void> _loadFonts() async {
  for (final entry in [
    ('Roboto', 'test/fonts/NotoSansCJK-JP-Regular.otf'),
    ('Roboto', 'test/fonts/NotoSansCJK-JP-Bold.otf'),
    (
      'MaterialIcons',
      '${_sdkArtifacts()}/material_fonts/MaterialIcons-Regular.otf',
    ),
    ('Roboto', 'test/fonts/NotoColorEmoji.ttf'),
  ]) {
    final loader = FontLoader(entry.$1);
    final bytes = await File(entry.$2).readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  }
}

Future<int> _seedCard(
  AppDatabase db, {
  required String kanji,
  required String kana,
  required String meaning,
  required Rarity rarity,
}) {
  return db
      .into(db.cards)
      .insert(
        CardsCompanion.insert(
          kanji: kanji,
          kana: kana,
          meaning: meaning,
          rarity: Value(rarity),
        ),
      );
}

Future<AppDatabase> _emptyDb() async {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

/// Registers an installed pack so the filter dropdown and the stats
/// chart render its label rather than falling back to the raw name.
Future<void> _seedInstalledPack(AppDatabase db, {required int cards}) {
  return db
      .into(db.packs)
      .insert(
        PacksCompanion.insert(
          name: 'science',
          label: 'Science & Programming',
          description: const Value(
            'Japanese for programming, mathematics and the sciences.',
          ),
          sourceTitle: const Value(
            'Japanese Programming, Math and Science Terms',
          ),
          sourceUrl: const Value('https://ankiweb.net/shared/info/433387608'),
          version: 'goldenversion0000',
          cardCount: Value(cards),
          installedAt: DateTime(2026, 4, 26, 12),
        ),
      );
}

/// Seeds a single rich card with multiple senses + examples and,
/// when [owned] is true (the default), a non-trivial review state
/// so the detail screen has every panel populated. With
/// `owned: false` we skip the user_cards row to capture the
/// dictionary-style detail view (no stats panel).
Future<int> _seedDetailCard(AppDatabase db, {bool owned = true}) async {
  final cardId = await db
      .into(db.cards)
      .insert(
        CardsCompanion.insert(
          kanji: '行く',
          kana: 'いく',
          meaning: 'to go',
          rarity: const Value(Rarity.common),
          jlptLevel: const Value(5),
        ),
      );
  for (final sense in const [
    (
      1,
      'v5k-s,vi',
      'to go, to move',
      'Godan verb of motion towards a destination.',
    ),
    (
      2,
      'v5k-s,vi',
      'to proceed, to take place',
      'Of an event or process — to unfold, to happen.',
    ),
    (
      3,
      'aux-v',
      '...continues to, ...keeps -ing',
      'Auxiliary after the te-form to show ongoing change.',
    ),
  ]) {
    await db
        .into(db.cardSenses)
        .insert(
          CardSensesCompanion.insert(
            cardId: cardId,
            ordinal: sense.$1,
            pos: Value(sense.$2),
            gloss: sense.$3,
            definition: Value(sense.$4),
          ),
        );
  }
  for (final sentence in const ['明日学校へ行く。', '会議は順調に行く。']) {
    final exId = await db
        .into(db.examples)
        .insert(ExamplesCompanion.insert(sentence: sentence));
    await db
        .into(db.cardExamples)
        .insert(CardExamplesCompanion.insert(cardId: cardId, exampleId: exId));
  }
  if (owned) {
    final now = DateTime(2026, 4, 26, 9, 30);
    await db
        .into(db.userCards)
        .insert(
          UserCardsCompanion.insert(
            cardId: Value(cardId),
            level: const Value(4),
            ease: const Value(2.4),
            intervalMinutes: const Value(60 * 24 * 5), // 5 days
            lastReviewed: Value(now.subtract(const Duration(days: 1))),
            nextDue: now.add(const Duration(days: 5)),
            obtainedAt: now.subtract(const Duration(days: 12)),
            isNew: const Value(false),
          ),
        );
  }
  return cardId;
}

/// Four due cards for the review loop; 魔法, which `Random(1)` deals
/// first, carries three senses so the back has a full list. Returns the
/// card ids.
Future<List<int>> _seedReviewDeck(AppDatabase db) async {
  final now = DateTime.now();
  final ids = <int>[];
  for (final c in const [
    ('本', 'ほん', 'book', Rarity.common),
    ('食べる', 'たべる', 'to eat', Rarity.common),
    ('魔法', 'まほう', 'magic', Rarity.superRare),
    ('一瞥', 'いちべつ', 'a glance', Rarity.ur),
  ]) {
    final id = await _seedCard(
      db,
      kanji: c.$1,
      kana: c.$2,
      meaning: c.$3,
      rarity: c.$4,
    );
    ids.add(id);
    await db
        .into(db.userCards)
        .insert(
          UserCardsCompanion.insert(
            cardId: Value(id),
            nextDue: now.subtract(const Duration(hours: 1)),
            obtainedAt: now.subtract(const Duration(days: 3)),
            isNew: const Value(false),
          ),
        );
  }
  for (final sense in const [
    (1, 'n', 'magic, witchcraft, sorcery', ''),
    (2, 'n', 'spell', 'A formula of words believed to have magical power.'),
    (
      3,
      'adj-no',
      'magical',
      'Of or relating to magic, as in 魔法の杖 (magic wand).',
    ),
  ]) {
    await db
        .into(db.cardSenses)
        .insert(
          CardSensesCompanion.insert(
            cardId: ids[2],
            ordinal: sense.$1,
            pos: Value(sense.$2),
            gloss: sense.$3,
            definition: Value(sense.$4),
          ),
        );
  }
  return ids;
}

/// Seeds a representative collection: every rarity gets a few entries,
/// most are owned (with non-zero levels so the level chip shows up),
/// and a couple of unowned cards keep the per-rarity totals honest.
Future<void> _seedCollection(AppDatabase db) async {
  // (kanji, kana, meaning, rarity, owned, level)
  final rows = <(String, String, String, Rarity, bool, int)>[
    ('猫', 'ねこ', 'cat', Rarity.common, true, 7),
    ('犬', 'いぬ', 'dog', Rarity.common, true, 4),
    ('林檎', 'りんご', 'apple', Rarity.common, true, 2),
    ('水', 'みず', 'water', Rarity.common, false, 0),
    ('蜂蜜', 'はちみつ', 'honey', Rarity.rare, true, 3),
    ('森', 'もり', 'forest', Rarity.rare, true, 5),
    ('地図', 'ちず', 'map', Rarity.rare, false, 0),
    ('魔法', 'まほう', 'magic', Rarity.superRare, true, 1),
    ('召喚', 'しょうかん', 'summoning', Rarity.superRare, true, 0),
    ('盗賊', 'とうぞく', 'thief, bandit', Rarity.superRare, false, 0),
    ('結界', 'けっかい', 'magic barrier', Rarity.ssr, true, 2),
    ('討伐', 'とうばつ', 'subjugation', Rarity.ssr, false, 0),
    ('一瞥', 'いちべつ', 'a glance', Rarity.ur, true, 0),
    ('熾烈', 'しれつ', 'fierce; severe', Rarity.ur, false, 0),
  ];
  final now = DateTime.now();
  for (final r in rows) {
    final id = await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            kanji: r.$1,
            kana: r.$2,
            meaning: r.$3,
            rarity: Value(r.$4),
          ),
        );
    if (r.$5) {
      await db
          .into(db.userCards)
          .insert(
            UserCardsCompanion.insert(
              cardId: Value(id),
              level: Value(r.$6),
              nextDue: now.add(const Duration(hours: 6)),
              obtainedAt: now.subtract(const Duration(days: 2)),
            ),
          );
    }
  }
}

/// Populates a stats scene: a mix of reviews across rarities, a few
/// retention bins worth of log rows, varied maturity intervals,
/// forecast load over the next few days, and a couple of leeches.
/// Targets `2026-04-26` as "today" — matches the rest of the goldens.
Future<void> _seedStatsScene(AppDatabase db) async {
  final today = DateTime(2026, 4, 26, 12);

  // Cards across the rarity spectrum so the per-rarity columns of
  // daily_stats are non-trivial.
  final cardSpecs = <(String, String, String, Rarity)>[
    ('猫', 'ねこ', 'cat', Rarity.common),
    ('犬', 'いぬ', 'dog', Rarity.common),
    ('森', 'もり', 'forest', Rarity.rare),
    ('魔法', 'まほう', 'magic', Rarity.superRare),
    ('結界', 'けっかい', 'magic barrier', Rarity.ssr),
    ('一瞥', 'いちべつ', 'a glance', Rarity.ur),
    ('熾烈', 'しれつ', 'fierce', Rarity.ur),
  ];
  final ids = <int>[];
  for (final s in cardSpecs) {
    ids.add(
      await db
          .into(db.cards)
          .insert(
            CardsCompanion.insert(
              kanji: s.$1,
              kana: s.$2,
              meaning: s.$3,
              rarity: Value(s.$4),
            ),
          ),
    );
  }

  // A themed pack, partly collected, so the pack progress card renders
  // a bar rather than hiding itself.
  final packSpecs = <(String, String, String)>[
    ('連想配列', 'れんそうはいれつ', 'associative array'),
    ('浮動小数点数', 'ふどうしょうすうてんすう', 'floating point number'),
    ('回折', 'かいせつ', 'diffraction'),
  ];
  for (final s in packSpecs) {
    ids.add(
      await db
          .into(db.cards)
          .insert(
            CardsCompanion.insert(
              kanji: s.$1,
              kana: s.$2,
              meaning: s.$3,
              rarity: const Value(Rarity.ssr),
              pack: const Value('science'),
            ),
          ),
    );
  }
  await _seedInstalledPack(db, cards: packSpecs.length);

  // Owned cards with varied intervals → maturity histogram + forecast.
  final ownedSpecs = <(int, int, Duration, int)>[
    (ids[0], 60 * 24, const Duration(hours: 8), 0), // <1d
    (ids[1], 60 * 24 * 2, const Duration(days: 1), 1), // 1-3d
    (ids[2], 60 * 24 * 5, const Duration(days: 2), 0), // 4-7d
    (ids[3], 60 * 24 * 10, const Duration(days: 3), 0), // 1-2w
    (ids[4], 60 * 24 * 21, const Duration(days: 5), 2), // 2-4w
    (ids[5], 60 * 24 * 60, const Duration(days: 10), 4), // 1-3mo
    (ids[6], 60 * 24 * 200, const Duration(days: 12), 0), // 6mo+
    (ids[7], 60 * 24 * 3, const Duration(days: 2), 0), // 1 of 3 packed
  ];
  for (final spec in ownedSpecs) {
    await db
        .into(db.userCards)
        .insert(
          UserCardsCompanion.insert(
            cardId: Value(spec.$1),
            intervalMinutes: Value(spec.$2),
            lastReviewed: Value(today.subtract(const Duration(days: 1))),
            nextDue: today.add(spec.$3),
            obtainedAt: today.subtract(const Duration(days: 30)),
            isNew: const Value(false),
            failCount: Value(spec.$4),
          ),
        );
  }

  // Daily activity rows — last ~8 days, varying volume + accuracy.
  final activity =
      <(String, int, int, int, int, int, int, int, int, int, int, int)>[
        // (date, c_total, c_correct, r_total, r_correct, sr_total, sr_correct,
        //  ssr_total, ssr_correct, ur_total, ur_correct, new_cards)
        ('2026-04-19', 8, 7, 3, 2, 1, 1, 0, 0, 0, 0, 4),
        ('2026-04-20', 12, 10, 4, 4, 2, 1, 1, 1, 0, 0, 5),
        ('2026-04-21', 9, 7, 5, 3, 3, 2, 1, 0, 1, 0, 3),
        ('2026-04-22', 14, 13, 6, 5, 2, 1, 0, 0, 0, 0, 2),
        ('2026-04-23', 11, 8, 4, 3, 4, 3, 2, 1, 1, 1, 1),
        ('2026-04-24', 7, 7, 3, 3, 2, 1, 1, 1, 0, 0, 0),
        ('2026-04-25', 16, 13, 6, 5, 3, 2, 1, 0, 1, 1, 2),
        ('2026-04-26', 10, 9, 5, 4, 4, 3, 2, 2, 1, 1, 1),
      ];
  for (final a in activity) {
    await db
        .into(db.dailyStats)
        .insert(
          DailyStatsCompanion.insert(
            date: a.$1,
            cTotal: Value(a.$2),
            cCorrect: Value(a.$3),
            rTotal: Value(a.$4),
            rCorrect: Value(a.$5),
            srTotal: Value(a.$6),
            srCorrect: Value(a.$7),
            ssrTotal: Value(a.$8),
            ssrCorrect: Value(a.$9),
            urTotal: Value(a.$10),
            urCorrect: Value(a.$11),
            newCards: Value(a.$12),
          ),
        );
  }

  // Review-log rows that hit several retention bins. Mix of correct
  // and wrong so the curve isn't a flat 100%.
  final logSpecs = <(int, bool, Rarity)>[
    // <1d (interval 0 — first reviews)
    for (var i = 0; i < 10; i++) (0, i < 9, Rarity.common),
    // 1-3d (1440..4320)
    for (var i = 0; i < 8; i++) (60 * 24, i < 7, Rarity.common),
    // 4-7d (4320..10080)
    for (var i = 0; i < 6; i++) (60 * 24 * 5, i < 5, Rarity.rare),
    // 1-2w (10080..20160)
    for (var i = 0; i < 5; i++) (60 * 24 * 10, i < 4, Rarity.rare),
    // 2-4w (20160..43200)
    for (var i = 0; i < 4; i++) (60 * 24 * 21, i < 3, Rarity.superRare),
    // 1-3mo (43200..129600)
    for (var i = 0; i < 3; i++) (60 * 24 * 60, i < 2, Rarity.ssr),
    // 6mo+ (>= 259200)
    for (var i = 0; i < 2; i++) (60 * 24 * 200, i < 1, Rarity.ur),
  ];
  for (var i = 0; i < logSpecs.length; i++) {
    final s = logSpecs[i];
    await db
        .into(db.reviewLog)
        .insert(
          ReviewLogCompanion.insert(
            reviewedAt: today.subtract(Duration(hours: i + 1)),
            prevIntervalMinutes: s.$1,
            correct: s.$2,
            rarity: s.$3.index,
          ),
        );
  }
}

/// Pumps a widget at phone-like dimensions and writes the result as a
/// PNG to `test/screenshots/<name>.png`.
Future<void> _shoot(
  WidgetTester tester,
  String name,
  Widget child, {
  Size logical = const Size(360, 780),
  double pixelRatio = 2.0,
  Duration settle = const Duration(milliseconds: 200),
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = Size(
    logical.width * pixelRatio,
    logical.height * pixelRatio,
  );
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildIunaTheme(),
      home: child,
    ),
  );
  // Pump once to apply the initial layout, then advance time through the
  // animation. We can't `pumpAndSettle` because the HexBg Ticker
  // never settles, so we fire a single late frame at `settle`.
  await tester.pump();
  await tester.pump(settle);
  await act?.call();

  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('screenshots/$name.png'),
  );
}

/// In-memory tutor stack. The clock ticks a second per read so course
/// ordering (by last activity) is deterministic.
Future<(LearnEnv, AppDatabase, LearnDatabase)> _learnEnv(
  LlmClient llm, {
  FakeRecorder? recorder,
  FakeTranscriber? stt,
}) async {
  final deckDb = await _emptyDb();
  final learnDb = LearnDatabase.forTesting(NativeDatabase.memory());
  var t = DateTime(2026, 9, 10, 9);
  final repo = LearnRepository(
    learnDb,
    clock: () => t = t.add(const Duration(seconds: 1)),
  );
  return (
    LearnEnv(
      repo: repo,
      llm: llm,
      settings: LearnSettings(MemorySecretStore()),
      dictation: Dictation(
        recorder: recorder == null ? FakeRecorder.new : () => recorder,
        transcriber: stt ?? FakeTranscriber([]),
      ),
      photos: FakePhotoPicker(),
      vision: textOnlyVisionModels(),
    ),
    deckDb,
    learnDb,
  );
}

/// Two courses: N1 planned with its first chapter passed, Business
/// Japanese still unplanned. Returns the N1 course id.
Future<int> _seedLearnCourses(LearnRepository repo) async {
  await repo.createCourse(
    title: 'Business Japanese',
    goal: 'Write polite emails to clients.',
  );
  final n1 = await repo.createCourse(
    title: 'JLPT N1',
    goal: 'Pass N1 in December — long reading passages are my weak spot.',
  );
  await repo.applyPlan(n1.id, const [
    ChapterDraft(
      key: 'n1-reading',
      title: 'Reading long passages',
      summary: 'Find the structure before the details.',
    ),
    ChapterDraft(
      key: 'n1-formal-grammar',
      title: 'Formal written grammar',
      summary: '～に即して, ～をもって, ～いかんによらず',
    ),
    ChapterDraft(
      key: 'n1-kango',
      title: 'Kango in editorials',
      summary: 'The Sino-Japanese vocabulary of opinion pieces.',
    ),
    ChapterDraft(key: 'n1-listening', title: 'Listening for intent'),
    ChapterDraft(key: 'n1-mock', title: 'Mock exam'),
  ]);
  await repo.appendChapterDoc(n1.id, 'n1-reading', '''
## Read the frame first

Editorials announce their shape. Before reading closely, find:

| Marker | Signals |
|---|---|
| しかし・ところが | the real point follows |
| つまり・要するに | a restatement |
| 確かに…が | a concession before the claim |

> Skim the first and last paragraph, then the sentence after every しかし.''');
  await repo.appendChapterDoc(n1.id, 'n1-reading', '''
## Paraphrase before you pick

N1 answer options rarely copy the text. Say the paragraph's claim in
your own words first, then look for the option that means the same.''');
  await repo.passChapter(n1.id, 'n1-reading');
  await repo.recordUsage(
    courseId: n1.id,
    kind: 'chat',
    model: 'm',
    cost: 0.042,
  );
  return n1.id;
}

/// Business Japanese's room, where Kuma-sensei has asked for a spoken
/// self-introduction. Returns the course id.
Future<int> _seedIntroductionRoom(LearnRepository repo) async {
  final business = (await repo.courseSummaries())
      .firstWhere((s) => s.course.title == 'Business Japanese')
      .course
      .id;
  final room = await repo.openSession(business, kRoomSessionKey);
  await repo.addMessage(
    room.id,
    role: MessageRole.user,
    content: 'I have to call a company to follow up on my application.',
  );
  await repo.addMessage(
    room.id,
    role: MessageRole.assistant,
    content:
        'Let’s rehearse the opening of that call. Say it the way you '
        'would on the phone: the greeting, who you are, why you’re calling. '
        'Hold the mic and just speak — mistakes are welcome.',
  );
  return business;
}

/// That room with the mic held over [levels] of speech for [hold]; with
/// [release], let go into a transcription that never answers, so the
/// shot catches the clip's bubble, and with [lock], slide up first so
/// the recording goes on without the finger.
Future<void> _shootDictation(
  WidgetTester tester,
  String name, {
  required int levels,
  required Duration hold,
  bool release = false,
  bool lock = false,
}) async {
  final recorder = FakeRecorder();
  final (env, deckDb, learnDb) = await _learnEnv(
    FakeLlm([]),
    recorder: recorder,
    stt: FakeTranscriber([if (release) Completer<Transcript>()]),
  );
  addTearDown(deckDb.close);
  addTearDown(learnDb.close);
  await _seedLearnCourses(env.repo);
  final id = await _seedIntroductionRoom(env.repo);
  late TestGesture gesture;
  await _shoot(
    tester,
    name,
    TutorChatScreen(env: env, courseId: id),
    settle: const Duration(milliseconds: 500),
    act: () async {
      gesture = await holdMic(tester);
      if (lock) {
        await gesture.moveBy(const Offset(0, -80));
        await tester.pump();
        await gesture.up();
      }
      recorder.speak(speechLevels(levels));
      await tester.pump(hold);
      if (release) {
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }
    },
  );
  if (!release && !lock) await gesture.cancel();
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

/// Swaps the Keystore for memory (no platform channel in tests); with
/// [apiKey] the Learn tab shows in the nav.
Future<void> _withLearnSettings({String? apiKey}) async {
  LearnSettings.instance = LearnSettings(
    MemorySecretStore({'openrouter_api_key': ?apiKey}),
  );
  await LearnSettings.instance.load();
  addTearDown(
    () => LearnSettings.instance = LearnSettings(const KeystoreSecretStore()),
  );
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    // Asset reads are real I/O; warm the prompt cache outside FakeAsync.
    await TutorAssets.load();
  });

  // The JMdict probe (Collection, Settings) reads the documents directory.
  setUp(() => useTempDocumentsDir('iuna_shots_'));

  testWidgets('home — pack available, no cards yet', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    for (var i = 0; i < 8; i++) {
      await _seedCard(
        db,
        kanji: 'k$i',
        kana: 'kana$i',
        meaning: 'word $i',
        rarity: Rarity.common,
      );
    }
    // Pin the Kuma variant — production randomizes between black and
    // white per app launch, but goldens need a stable bear.
    await _shoot(
      tester,
      'home_pack_available',
      HomeScreen(db: db, kumaSeed: 0),
    );
  });

  testWidgets('home — pack opened, cards due', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);

    final ids = <int>[];
    for (final pair in const [
      ('猫', 'ねこ', 'cat', Rarity.common),
      ('犬', 'いぬ', 'dog', Rarity.common),
      ('熊', 'くま', 'bear', Rarity.common),
      ('蜂蜜', 'はちみつ', 'honey', Rarity.rare),
      ('魔法', 'まほう', 'magic', Rarity.superRare),
    ]) {
      ids.add(
        await _seedCard(
          db,
          kanji: pair.$1,
          kana: pair.$2,
          meaning: pair.$3,
          rarity: pair.$4,
        ),
      );
    }
    final now = DateTime.now();
    for (final id in ids) {
      await db
          .into(db.userCards)
          .insert(
            UserCardsCompanion.insert(
              cardId: Value(id),
              nextDue: now.subtract(const Duration(hours: 1)),
              obtainedAt: now.subtract(const Duration(days: 1)),
            ),
          );
    }
    await db
        .into(db.meta)
        .insert(
          MetaCompanion.insert(
            key: 'last_booster_date',
            value:
                '${now.year.toString().padLeft(4, '0')}-'
                '${now.month.toString().padLeft(2, '0')}-'
                '${now.day.toString().padLeft(2, '0')}',
          ),
        );
    await db
        .into(db.meta)
        .insert(
          MetaCompanion.insert(key: 'boosters_claimed_today', value: '1'),
        );

    await _shoot(tester, 'home_pack_opened', HomeScreen(db: db, kumaSeed: 1));
  });

  testWidgets('settings — sound toggle and JMdict notice', (tester) async {
    await _withLearnSettings();
    useTempDocumentsDir('iuna_settings_shot_');
    final db = await _emptyDb();
    addTearDown(db.close);
    // One installed pack so both the draw filter and the "Card packs"
    // section have something to render; both hide when empty.
    await db
        .into(db.cards)
        .insert(
          CardsCompanion.insert(
            kanji: '拡張機能',
            kana: 'かくちょうきのう',
            meaning: 'extension',
            pack: const Value('science'),
          ),
        );
    await _seedInstalledPack(db, cards: 931);
    // Tall enough to reach "Card packs".
    await _shoot(
      tester,
      'settings',
      SettingsScreen(db: db),
      logical: const Size(360, 1700),
      settle: const Duration(seconds: 3),
    );
  });

  testWidgets('stats — full redesigned screen', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    await _seedStatsScene(db);
    await _shoot(
      tester,
      'stats_screen',
      StatsScreen(db: db, now: DateTime(2026, 4, 26, 12)),
      logical: const Size(360, 3400),
      settle: const Duration(milliseconds: 500),
    );
  });

  testWidgets('preview — deck list with full word info', (tester) async {
    await _shoot(
      tester,
      'deck_list_preview',
      const _DeckListPreview(),
      logical: const Size(360, 900),
    );
  });

  testWidgets('collection — full grid', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    await _seedCollection(db);
    await _shoot(
      tester,
      'collection_preview',
      CollectionScreen(db: db),
      logical: const Size(360, 900),
      // The golden was taken at this point of the hex background's drift.
      settle: const Duration(seconds: 3),
    );
  });

  testWidgets('collection — Show missing (silhouettes for unowned)', (
    tester,
  ) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    await _seedCollection(db);

    tester.view.physicalSize = const Size(360 * 2, 900 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildIunaTheme(),
        home: CollectionScreen(db: db),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    // Toggle the "Show missing" chip — picks up unowned cards as silhouettes.
    // The chip sits at the right end of a horizontal scroll row and is
    // typically offscreen-right at the default device width, so we
    // ensureVisible before tapping.
    final chip = find.text('Show missing');
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('screenshots/collection_show_missing.png'),
    );
  });

  testWidgets('card detail — multi-sense card with examples', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    final cardId = await _seedDetailCard(db);
    await _shoot(
      tester,
      'card_detail',
      CardDetailScreen(db: db, cardId: cardId),
      logical: const Size(360, 900),
      settle: const Duration(milliseconds: 500),
    );
  });

  testWidgets('card detail — unowned (dictionary view)', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    final cardId = await _seedDetailCard(db, owned: false);
    await _shoot(
      tester,
      'card_detail_unowned',
      CardDetailScreen(db: db, cardId: cardId),
      logical: const Size(360, 900),
      settle: const Duration(milliseconds: 500),
    );
  });

  testWidgets('review — front of card', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    await _seedReviewDeck(db);
    await _shoot(
      tester,
      'review_front',
      ReviewScreen(db: db, random: Random(1)),
      settle: const Duration(milliseconds: 500),
    );
  });

  testWidgets('review — back of card with multiple senses', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    await _seedReviewDeck(db);
    await _shoot(
      tester,
      'review_back',
      ReviewScreen(db: db, random: Random(1)),
      settle: const Duration(milliseconds: 500),
      act: () async {
        await tester.tap(find.text('魔法'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      },
    );
  });

  testWidgets('review — done', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    final ids = await _seedReviewDeck(db);
    await _shoot(
      tester,
      'review_done',
      ReviewDoneScreen(db: db, correct: 3, total: 4, doneCardIds: ids),
      logical: const Size(360, 900),
      settle: const Duration(seconds: 5),
    );
  });

  testWidgets('booster — pack intro', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    await _shoot(
      tester,
      'pack_intro',
      PackIntroScreen(db: db, kumaSeed: 0),
      settle: const Duration(milliseconds: 500),
    );
  });

  testWidgets('booster — card reveal', (tester) async {
    final db = await _emptyDb();
    addTearDown(db.close);
    for (final c in const [
      ('一瞥', 'いちべつ', 'a glance', Rarity.ur),
      ('魔法', 'まほう', 'magic', Rarity.superRare),
      ('結界', 'けっかい', 'magic barrier', Rarity.ssr),
      ('森', 'もり', 'forest', Rarity.rare),
      ('猫', 'ねこ', 'cat', Rarity.common),
    ]) {
      await _seedCard(db, kanji: c.$1, kana: c.$2, meaning: c.$3, rarity: c.$4);
    }
    await _shoot(
      tester,
      'booster_reveal',
      BoosterRevealScreen(db: db, random: Random(1)),
      settle: const Duration(milliseconds: 500),
    );
  });

  testWidgets('learn — hub with courses', (tester) async {
    await _withLearnSettings(apiKey: 'sk-or-v1-golden');
    final (env, deckDb, learnDb) = await _learnEnv(FakeLlm([]));
    addTearDown(deckDb.close);
    addTearDown(learnDb.close);
    await _seedLearnCourses(env.repo);
    await _shoot(
      tester,
      'learn_hub',
      LearnScreen(db: deckDb, env: env, kumaSeed: 0),
    );
  });

  testWidgets('learn — course with chapters', (tester) async {
    final (env, deckDb, learnDb) = await _learnEnv(FakeLlm([]));
    addTearDown(deckDb.close);
    addTearDown(learnDb.close);
    final id = await _seedLearnCourses(env.repo);
    await _shoot(tester, 'learn_course', CourseScreen(env: env, courseId: id));
  });

  testWidgets('learn — lesson waiting on a quiz card', (tester) async {
    final llm = FakeLlm([
      callTool(
        'course_write',
        {
          'chapter': 'n1-formal-grammar',
          'markdown': '## ～に即して\nIn accordance with a rule or fact.',
        },
        text:
            'First pattern: **～に即して** — acting *in accordance with* '
            'a rule or a fact, as in 法律に即して（ほうりつにそくして）. '
            'It is in your Theory tab.',
      ),
      callTool(
        'ask_quiz',
        {
          'title': 'Quick check',
          'questions': [
            {
              'prompt': 'Pick the natural fit: 規則＿＿処分を決める。',
              'options': ['に即して', 'にかけて', 'をもとで'],
              'answer': 'に即して',
            },
            {'prompt': 'Rewrite with ～に即して: 事実に基づいて判断してください。'},
          ],
        },
        id: 'call_2',
        text: 'Two quick checks before we go on.',
      ),
    ]);
    final (env, deckDb, learnDb) = await _learnEnv(llm);
    addTearDown(deckDb.close);
    addTearDown(learnDb.close);
    final id = await _seedLearnCourses(env.repo);
    await _shoot(
      tester,
      'learn_lesson_quiz',
      TutorChatScreen(env: env, courseId: id, chapterKey: 'n1-formal-grammar'),
      logical: const Size(360, 900),
      settle: const Duration(milliseconds: 500),
    );
    // Let the controller wind down (the quiz is cancelled) before the
    // databases close.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('learn — room probing with multiple-choice questions', (
    tester,
  ) async {
    final (env, deckDb, learnDb) = await _learnEnv(FakeLlm([]));
    addTearDown(deckDb.close);
    addTearDown(learnDb.close);
    final id = await _seedLearnCourses(env.repo);
    final room = await env.repo.openSession(id, kRoomSessionKey);
    Future<void> add(MessageRole role, String content) =>
        env.repo.addMessage(room.id, role: role, content: content);
    await add(
      MessageRole.assistant,
      'Let’s find your edge in formal written grammar. Which one means '
      '*in line with the facts*?\n\n'
      '```choices\n事実に即して\n事実にひきかえ\n事実をよそに\n```',
    );
    await add(MessageRole.user, '事実をよそに');
    await add(
      MessageRole.assistant,
      'Not quite: **をよそに** means *ignoring*. One step back, then. Which '
      'one means *based on the facts*?\n\n'
      '```choices\n事実に基づいて\n事実に限って\n事実にかかわらず\n```',
    );
    await _shoot(
      tester,
      'learn_room_choices',
      TutorChatScreen(env: env, courseId: id),
      settle: const Duration(milliseconds: 500),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('learn — frozen theory of a passed chapter', (tester) async {
    final (env, deckDb, learnDb) = await _learnEnv(FakeLlm([]));
    addTearDown(deckDb.close);
    addTearDown(learnDb.close);
    final id = await _seedLearnCourses(env.repo);
    await _shoot(
      tester,
      'learn_theory',
      TutorChatScreen(env: env, courseId: id, chapterKey: 'n1-reading'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('learn — ask, opened from the hub chat bar', (tester) async {
    final (env, deckDb, learnDb) = await _learnEnv(
      FakeLlm([
        say(
          '**～わけではない** softens a statement into “it’s not that…”: it '
          'denies a conclusion the listener might jump to.\n\n'
          '- 嫌いなわけではない。 — It’s not that I dislike it.\n'
          '- 毎日行くわけではない。 — I don’t go *every* day.',
        ),
      ]),
    );
    addTearDown(deckDb.close);
    addTearDown(learnDb.close);
    await _shoot(
      tester,
      'learn_ask',
      AskScreen(env: env, question: 'What does ～わけではない mean?'),
      settle: const Duration(milliseconds: 500),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('learn — reading a photo the learner sent', (tester) async {
    final (env, deckDb, learnDb) = await _learnEnv(
      FakeLlm([
        say(
          'The sign reads **非常口（ひじょうぐち）** — “emergency exit”.\n\n'
          'Underneath, 開ける（あける）ときは押す（おす） tells you to *push* to '
          'open it. 非常 on its own means “emergency”, and you will see it on '
          '非常階段（ひじょうかいだん）, the emergency stairs, too.',
        ),
      ]),
    );
    addTearDown(deckDb.close);
    addTearDown(learnDb.close);
    await _shoot(
      tester,
      'learn_photo',
      AskScreen(
        env: env,
        question: 'What does this sign say?',
        photo: testPhoto(),
      ),
      settle: const Duration(milliseconds: 500),
      // Decoding a photo is real async work: without this the bubble
      // would be shot before its image exists.
      act: () async {
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(kTestPhotoBytes),
            tester.element(find.byType(MaterialApp)),
          ),
        );
        await tester.pump();
      },
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('learn — holding the mic to answer', (tester) async {
    await _shootDictation(
      tester,
      'learn_dictation_recording',
      levels: 70,
      hold: const Duration(milliseconds: 3400),
    );
  });

  testWidgets('learn — a locked recording going on hands-free', (tester) async {
    await _shootDictation(
      tester,
      'learn_dictation_locked',
      levels: 80,
      hold: const Duration(milliseconds: 5200),
      lock: true,
    );
  });

  testWidgets('learn — a dictated answer turning into text', (tester) async {
    await _shootDictation(
      tester,
      'learn_dictation_transcribing',
      levels: 90,
      hold: const Duration(milliseconds: 4600),
      release: true,
    );
  });
}

// Sample data shared across previews so both views show the same
// (kanji, kana, meaning, rarity, level, jlptLevel) rows.
class _Sample {
  const _Sample(
    this.kanji,
    this.kana,
    this.meaning,
    this.rarity,
    this.level,
    this.jlpt,
  );
  final String kanji;
  final String kana;
  final String meaning;
  final Rarity rarity;
  final int level;
  final int? jlpt;
}

const _samples = <_Sample>[
  _Sample('食べる', 'たべる', 'to eat', Rarity.common, 7, 5),
  _Sample('猫', 'ねこ', 'cat', Rarity.common, 4, 5),
  _Sample('林檎', 'りんご', 'apple', Rarity.common, 2, 5),
  _Sample('蜂蜜', 'はちみつ', 'honey', Rarity.rare, 3, 4),
  _Sample('森', 'もり', 'forest', Rarity.rare, 5, 4),
  _Sample('魔法', 'まほう', 'magic', Rarity.superRare, 1, 3),
  _Sample('召喚', 'しょうかん', 'summoning', Rarity.superRare, 0, 3),
  _Sample('結界', 'けっかい', 'magic barrier', Rarity.ssr, 2, 2),
  _Sample('一瞥', 'いちべつ', 'a glance', Rarity.ur, 0, 1),
];

class _DeckListPreview extends StatelessWidget {
  const _DeckListPreview();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deck')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        itemCount: _samples.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _DeckListTile(sample: _samples[i]),
      ),
    );
  }
}

class _DeckListTile extends StatelessWidget {
  const _DeckListTile({required this.sample});
  final _Sample sample;

  @override
  Widget build(BuildContext context) {
    final tint = rarityColor(sample.rarity);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: IunaPalette.pawBrown.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Vertical rarity stripe.
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            sample.kanji,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: IunaPalette.pawBrown,
                            ),
                          ),
                        ),
                        _MockRarityBadge(rarity: sample.rarity),
                        const SizedBox(width: 8),
                        _LevelBadge(level: sample.level),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sample.kana,
                      style: TextStyle(
                        fontSize: 14,
                        color: IunaPalette.pawBrown.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sample.meaning,
                      style: const TextStyle(
                        fontSize: 14,
                        color: IunaPalette.pawBrown,
                      ),
                    ),
                    if (sample.jlpt != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: IunaPalette.pawBrown.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'JLPT N${sample.jlpt}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: IunaPalette.pawBrown.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final muted = level == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted
            ? IunaPalette.pawBrown.withValues(alpha: 0.1)
            : IunaPalette.pawBrown,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt_rounded,
            size: 12,
            color: muted
                ? IunaPalette.pawBrown.withValues(alpha: 0.7)
                : IunaPalette.cream,
          ),
          const SizedBox(width: 2),
          Text(
            'Lv $level',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: muted
                  ? IunaPalette.pawBrown.withValues(alpha: 0.7)
                  : IunaPalette.cream,
            ),
          ),
        ],
      ),
    );
  }
}

/// The pre-redesign rarity badge, kept only for the deck-list mockup.
class _MockRarityBadge extends StatelessWidget {
  const _MockRarityBadge({required this.rarity});

  final Rarity rarity;

  @override
  Widget build(BuildContext context) {
    final color = rarityColor(rarity);
    final stars = rarityStars(rarity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: stars >= 4
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rarityCode(rarity),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: IunaPalette.pawBrown,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 5),
          for (var i = 0; i < stars; i++)
            Icon(
              Icons.star_rounded,
              size: 11,
              color: IunaPalette.pawBrown.withValues(alpha: 0.85),
            ),
        ],
      ),
    );
  }
}
