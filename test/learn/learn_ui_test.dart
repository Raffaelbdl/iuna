import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/learn/agent/chat_controller.dart';
import 'package:iuna/learn/agent/chat_store.dart';
import 'package:iuna/learn/agent/tutor_prompt.dart';
import 'package:iuna/learn/deck_bookmarks.dart';
import 'package:iuna/learn/learn_settings.dart';
import 'package:iuna/learn/llm/model_vision.dart';
import 'package:iuna/learn/photo/photo_picker.dart';
import 'package:iuna/learn/screens/ask_screen.dart';
import 'package:iuna/learn/screens/learn_screen.dart';
import 'package:iuna/learn/widgets/chat_view.dart';
import 'package:iuna/learn/widgets/choice_buttons.dart';
import 'package:iuna/screens/app_nav.dart';
import 'package:iuna/screens/settings_screen.dart';
import 'package:iuna/widgets/iuna_bottom_nav.dart';

import '../helpers/fake_package_info.dart';
import 'fake_llm.dart';
import 'fake_photos.dart';
import 'test_env.dart';

void main() {
  late MemorySecretStore store;
  late LearnSettings settings;

  // Asset reads are real I/O; warm the prompt cache outside FakeAsync.
  setUpAll(() async {
    await TutorAssets.load();
  });

  setUp(() {
    useFakePackageInfo();
    store = MemorySecretStore();
    settings = LearnSettings(store);
    LearnSettings.instance = settings;
  });

  tearDown(() {
    LearnSettings.instance = LearnSettings(const KeystoreSecretStore());
  });

  test('model ids lose a litellm-style openrouter/ prefix; blank means default', () {
    expect(normalizeModelId('openrouter/deepseek/deepseek-v4-flash-0731'),
        'deepseek/deepseek-v4-flash-0731');
    expect(normalizeModelId('  anthropic/claude-sonnet-5 '), 'anthropic/claude-sonnet-5');
    expect(normalizeModelId(''), kDefaultLearnModel);
    expect(normalizeModelId(null), kDefaultLearnModel);
  });

  test('choosing the default model clears the setting instead of pinning it', () async {
    await settings.setModel('openrouter/anthropic/claude-sonnet-5');
    expect(await settings.model(), 'anthropic/claude-sonnet-5');
    expect(await store.read('openrouter_model'), 'anthropic/claude-sonnet-5');

    await settings.setModel(kDefaultLearnModel);
    expect(await store.read('openrouter_model'), isNull);

    await settings.setModel('x/y');
    await settings.setModel(null);
    expect(await store.read('openrouter_model'), isNull);
    expect(await settings.model(), kDefaultLearnModel);
  });

  testWidgets('the Learn tab exists only while an API key is stored', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await settings.load();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: AppBottomNav(db: db, active: IunaNavTab.home),
        ),
      ),
    ));
    expect(find.text('Learn'), findsNothing);
    expect(find.text('Collection'), findsOneWidget);

    await settings.setApiKey('sk-or-v1-abc');
    await tester.pump();
    expect(find.text('Learn'), findsOneWidget);

    await settings.clearApiKey();
    await tester.pump();
    expect(find.text('Learn'), findsNothing);
  });

  testWidgets('the nav reports a tap on the Learn tab', (tester) async {
    IunaNavTab? tapped;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: IunaBottomNav(
          active: IunaNavTab.home,
          showLearn: true,
          onTap: (t) => tapped = t,
        ),
      ),
    ));
    await tester.tap(find.text('Learn'));
    expect(tapped, IunaNavTab.learn);
  });

  testWidgets('each question from the hub chat bar opens a fresh Ask chat', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final llm = FakeLlm([say('First answer.'), say('Second answer.')]);
    final env = testLearnEnv(llm, settings: settings);

    await tester.pumpWidget(MaterialApp(home: LearnScreen(db: db, env: env, kumaSeed: 0)));
    await tester.pump();

    // What the model saw besides the system prompt.
    Future<List<Object?>> ask(String question) async {
      await tester.enterText(find.byType(TextField), question);
      await tester.pump(); // Send enables on the next frame.
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AskScreen), findsOneWidget);
      return [
        for (final m in llm.requests.last.messages)
          if (m['role'] != 'system') m['content'],
      ];
    }

    expect(await ask('は or が?'), ['は or が?']);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AskScreen), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

    expect(await ask('What is 敬語?'), ['What is 敬語?']);
    expect(llm.requests, hasLength(2));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a word from an Ask chat can be bookmarked into the deck', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final deck = IunaRepository(db);
    final id = await db
        .into(db.cards)
        .insert(CardsCompanion.insert(kanji: '会議', kana: 'かいぎ', meaning: 'meeting'));
    final llm = FakeLlm([
      callTool('bookmark_words', {
        'words': [
          {'word': '会議', 'reading': 'かいぎ'},
        ],
      }),
      say('Done: 会議 will turn up in one of your next packs.'),
    ]);
    final env = testLearnEnv(llm, settings: settings, bookmarks: DeckBookmarks(deck));

    await tester.pumpWidget(MaterialApp(
      home: AskScreen(env: env, question: 'What is 会議? Keep it for me.'),
    ));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(llm.requests.first.tools.map((t) => (t['function'] as Map)['name']), ['bookmark_words']);
    expect(find.text('Bookmarked · 会議'), findsOneWidget);
    expect(await deck.wishedCardIds(), [id]);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a photo attached in a chat is sent with the message', (tester) async {
    final llm = FakeLlm([say('It reads 非常口（ひじょうぐち）— emergency exit.')]);
    final picker = FakePhotoPicker();
    final env = testLearnEnv(
      llm,
      settings: settings,
      photos: picker,
      vision: textOnlyVisionModels(),
    );

    await tester.pumpWidget(MaterialApp(home: AskScreen(env: env, question: 'Hi')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byTooltip('Attach a photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(picker.asked, [PhotoSource.gallery]);
    expect(find.text('Photo attached'), findsOneWidget);

    llm.script.add(say('It reads 非常口（ひじょうぐち）— emergency exit.'));
    await tester.enterText(find.byType(TextField), 'what does this say?');
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // The composer is empty again and the photo is in the conversation.
    expect(find.text('Photo attached'), findsNothing);
    final sent = llm.requests.last.messages.last;
    expect(sent['role'], 'user');
    expect((sent['content'] as List).map((p) => (p as Map)['type']),
        ['text', 'image_url']);
    expect(llm.requests.last.model, kPhotoFallbackModel);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a photo from the hub bar opens an Ask chat on its own', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final llm = FakeLlm([say('A ramen menu. 醤油（しょうゆ）ラーメン is the first line.')]);
    final env = testLearnEnv(
      llm,
      settings: settings,
      photos: FakePhotoPicker(),
      vision: textOnlyVisionModels(),
    );

    await tester.pumpWidget(MaterialApp(home: LearnScreen(db: db, env: env, kumaSeed: 0)));
    await tester.pump();

    // No pumpAndSettle on the hub: its background tickers never settle.
    await tester.tap(find.byTooltip('Attach a photo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Take a photo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Photo attached'), findsOneWidget);

    // Nothing typed: the photo alone is the question.
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(AskScreen), findsOneWidget);
    final content = llm.requests.single.messages.last['content'] as List;
    expect(content.single['type'], 'image_url');

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Photo attached'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('a multiple-choice question is answered with a tap', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final llm = FakeLlm([
      say('Which particle marks the topic?\n\n```choices\nは\nが\nを\n```'),
      say('Right. And the plain form of です?\n\n```choices\nだ\nである\n```'),
      say('No problem: it is だ.'),
    ]);
    final chat = ChatController(
      llm: llm,
      store: MemoryChatStore(),
      systemPrompt: () async => 'SYSTEM',
      model: () async => 'test/model',
    );
    addTearDown(chat.dispose);
    await chat.open();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ChatView(controller: chat))));
    await chat.send('quiz me');
    await tester.pump();

    Finder option(String label) =>
        find.descendant(of: find.byType(ChoiceButtons), matching: find.text(label));
    Map<String, dynamic> lastSent() => llm.requests.last.messages.last;

    expect(option('が'), findsOneWidget);
    expect(option("I don't know"), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue,
        reason: 'typing an answer instead stays possible');

    await tester.tap(option('は'));
    await tester.pumpAndSettle();
    expect(lastSent(), {'role': 'user', 'content': 'は'});
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.tap(option('が'));
    await tester.pumpAndSettle();
    expect(llm.requests, hasLength(2), reason: 'an answered question takes no second answer');

    final second = find.ancestor(of: find.text('だ'), matching: find.byType(ChoiceButtons));
    await tester.tap(find.descendant(of: second, matching: find.text("I don't know")));
    await tester.pumpAndSettle();
    expect(lastSent(), {'role': 'user', 'content': "I don't know"});
    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings: the tutor model is editable, normalized and resettable',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(MaterialApp(home: SettingsScreen(db: db)));
    await tester.pumpAndSettle();

    final model = find.text('Tutor model');
    await tester.ensureVisible(model);
    await tester.pumpAndSettle();
    expect(find.text('Not set. The Learn tab appears once a key is saved.'), findsOneWidget);
    expect(find.text(kDefaultLearnModel), findsOneWidget);

    await tester.tap(model);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'openrouter/anthropic/claude-sonnet-5');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await settings.model(), 'anthropic/claude-sonnet-5');
    expect(find.text('anthropic/claude-sonnet-5'), findsOneWidget);

    await tester.ensureVisible(model);
    await tester.pumpAndSettle();
    await tester.tap(model);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(await store.read('openrouter_model'), isNull);
    expect(find.text(kDefaultLearnModel), findsOneWidget);
  });
}
