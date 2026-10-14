import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/learn/agent/chat_controller.dart';
import 'package:iuna/learn/agent/chat_store.dart';
import 'package:iuna/learn/agent/tutor_prompt.dart';
import 'package:iuna/learn/learn_settings.dart';
import 'package:iuna/learn/llm/llm.dart';
import 'package:iuna/learn/llm/transcriber.dart';
import 'package:iuna/learn/screens/ask_screen.dart';
import 'package:iuna/learn/screens/learn_screen.dart';
import 'package:iuna/learn/voice/dictation.dart';
import 'package:iuna/learn/widgets/chat_view.dart';

import 'fake_llm.dart';
import 'fake_voice.dart';
import 'test_env.dart';

void main() {
  // Asset reads are real I/O; warm the prompt cache outside FakeAsync.
  setUpAll(() async {
    await TutorAssets.load();
  });

  setUp(() => LearnSettings.instance = LearnSettings(MemorySecretStore()));
  tearDown(() => LearnSettings.instance = LearnSettings(const KeystoreSecretStore()));

  /// A chat dictated into with [recorder] and [stt]; returns what it
  /// logged as spent.
  Future<List<String>> pumpChat(
    WidgetTester tester, {
    required FakeLlm llm,
    required FakeRecorder recorder,
    required FakeTranscriber stt,
  }) async {
    final spent = <String>[];
    final chat = ChatController(
      llm: llm,
      store: MemoryChatStore(),
      systemPrompt: () async => 'SYSTEM',
      model: () async => 'test/model',
      onUsage: (u, {required model, required kind}) async => spent.add('$kind $model ${u.cost}'),
      dictation: Dictation(recorder: () => recorder, transcriber: stt),
    );
    addTearDown(chat.dispose);
    await chat.open();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatView(controller: chat),
        ),
      ),
    );
    return spent;
  }

  testWidgets('a held clip shows as a waveform, turns into text, and only the text is sent', (
    tester,
  ) async {
    final llm = FakeLlm([say('いい自己紹介ですね。')]);
    final recorder = FakeRecorder();
    final answer = Completer<Transcript>();
    final stt = FakeTranscriber([answer]);
    final spent = await pumpChat(tester, llm: llm, recorder: recorder, stt: stt);

    expect(find.byTooltip('Send'), findsNothing, reason: 'an empty field offers the mic instead');
    final hold = await holdMic(tester);
    expect(recorder.recording, isTrue);
    recorder.speak(speechLevels(40));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('0:02'), findsOneWidget);
    expect(find.text('‹ Slide to cancel'), findsOneWidget);

    await hold.up();
    await tester.pump();
    expect(recorder.recording, isFalse);
    expect(find.text('Transcribing…'), findsOneWidget);
    expect(find.text('0:02'), findsOneWidget, reason: 'the bubble gives the clip length');
    expect(llm.requests, isEmpty);

    answer.complete(const Transcript('お忙しいところ失礼いたします。', cost: 0.0004));
    await tester.pump();
    expect(find.text('お忙しいところ失礼いたします。'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(
      find.text('Transcribing…'),
      findsNothing,
      reason: 'the waveform has faded into the text',
    );
    expect(llm.requests, isEmpty, reason: 'the bubble turns into text before it goes out');

    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(stt.clips.single, FakeRecorder.wav);
    expect(llm.requests.single.messages.last, {'role': 'user', 'content': 'お忙しいところ失礼いたします。'});
    expect(
      find.text('お忙しいところ失礼いたします。'),
      findsOneWidget,
      reason: 'the message took the voice bubble’s place',
    );
    expect(spent, ['dictation test/stt 0.0004', 'chat test/model 0.001']);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sliding away cancels, a tap is not speech, and typing brings back send', (
    tester,
  ) async {
    final llm = FakeLlm([]);
    final recorder = FakeRecorder();
    final stt = FakeTranscriber([]);
    await pumpChat(tester, llm: llm, recorder: recorder, stt: stt);

    final hold = await holdMic(tester);
    await tester.pump(const Duration(seconds: 1));
    await hold.moveBy(const Offset(-150, 0));
    await tester.pump();
    expect(find.text('Release to cancel'), findsOneWidget);
    await hold.up();
    await tester.pump();
    expect(recorder.cancels, 1);
    expect(find.text('Transcribing…'), findsNothing);

    await tester.tap(composerMic);
    await tester.pump();
    expect(find.text('Hold the mic while you speak'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Hold the mic while you speak'), findsNothing);

    await tester.enterText(find.byType(TextField), 'はい');
    await tester.pump();
    expect(composerMic, findsNothing);
    expect(find.byTooltip('Send'), findsOneWidget);

    expect(stt.clips, isEmpty);
    expect(llm.requests, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('sliding up locks the recording, which then sends or cancels by button', (
    tester,
  ) async {
    final llm = FakeLlm([say('よく言えました。')]);
    final recorder = FakeRecorder();
    final stt = FakeTranscriber(['もしもし、田中と申します。']);
    await pumpChat(tester, llm: llm, recorder: recorder, stt: stt);

    var hold = await holdMic(tester);
    await hold.moveBy(const Offset(0, -80));
    await tester.pump();
    await hold.up();
    await tester.pump(const Duration(seconds: 2));
    expect(recorder.recording, isTrue, reason: 'the lock keeps it going without the finger');
    expect(find.text('0:02'), findsOneWidget);
    expect(find.text('‹ Slide to cancel'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(composerMic, findsNothing, reason: 'the mic became the send button');

    recorder.speak(speechLevels(30));
    await tester.pump();
    await tester.tap(find.byTooltip('Send'));
    await tester.pump();
    expect(recorder.recording, isFalse);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(stt.clips, hasLength(1));
    expect(llm.requests.single.messages.last, {'role': 'user', 'content': 'もしもし、田中と申します。'});

    hold = await holdMic(tester);
    await hold.moveBy(const Offset(0, -80));
    await tester.pump();
    await hold.up();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(recorder.cancels, 1);
    expect(recorder.recording, isFalse);
    expect(find.text('Transcribing…'), findsNothing);
    expect(composerMic, findsOneWidget, reason: 'back to hold-to-speak');
    expect(stt.clips, hasLength(1));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed transcription can be retried; nothing heard can only be discarded', (
    tester,
  ) async {
    final llm = FakeLlm([say('はい、どうぞ。')]);
    final recorder = FakeRecorder();
    final stt = FakeTranscriber([
      const LlmException('Insufficient credits', status: 402),
      'もう一度お願いします。',
      '',
    ]);
    await pumpChat(tester, llm: llm, recorder: recorder, stt: stt);

    Future<void> speak() async {
      final hold = await holdMic(tester);
      recorder.speak(speechLevels(20));
      await tester.pump(const Duration(seconds: 1));
      await hold.up();
      await tester.pump();
    }

    await speak();
    expect(find.text('Your OpenRouter account is out of credits.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(llm.requests.single.messages.last, {'role': 'user', 'content': 'もう一度お願いします。'});

    await speak();
    expect(find.text('Nothing heard. Hold the mic while you speak.'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    await tester.tap(find.text('Discard'));
    await tester.pump();
    expect(find.text('Nothing heard. Hold the mic while you speak.'), findsNothing);
    expect(llm.requests, hasLength(1));

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('without the microphone permission, a press explains instead of recording', (
    tester,
  ) async {
    final recorder = FakeRecorder(permitted: false);
    await pumpChat(tester, llm: FakeLlm([]), recorder: recorder, stt: FakeTranscriber([]));

    final hold = await tester.startGesture(tester.getCenter(composerMic));
    await tester.pump();
    await hold.up();
    await tester.pump();
    expect(recorder.recording, isFalse);
    expect(
      find.text('Iuna needs the microphone for dictation. Allow it in Android settings.'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('holding the hub mic opens an Ask chat that sends the transcript', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final llm = FakeLlm([say('「失礼いたします」は、とても丁寧な言い方です。')]);
    final recorder = FakeRecorder();
    final stt = FakeTranscriber(['失礼いたしますってどういう意味？']);
    final env = testLearnEnv(
      llm,
      dictation: Dictation(recorder: () => recorder, transcriber: stt),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LearnScreen(db: db, env: env, kumaSeed: 0),
      ),
    );
    await tester.pump();

    final hold = await holdMic(tester);
    recorder.speak(speechLevels(30));
    await tester.pump(const Duration(seconds: 2));
    await hold.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();

    expect(find.byType(AskScreen), findsOneWidget);
    expect(stt.clips, hasLength(1));
    expect(
      [
        for (final m in llm.requests.single.messages)
          if (m['role'] != 'system') m['content'],
      ],
      ['失礼いたしますってどういう意味？'],
    );
    expect(await env.repo.totalCost(), closeTo(0.0004 + 0.001, 1e-9));

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
