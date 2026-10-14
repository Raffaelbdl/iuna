import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/learn/agent/chat_controller.dart';
import 'package:iuna/learn/agent/chat_models.dart';
import 'package:iuna/learn/agent/chat_store.dart';
import 'package:iuna/learn/agent/compaction.dart';
import 'package:iuna/learn/agent/tutor_tools.dart';
import 'package:iuna/learn/db/learn_database.dart';
import 'package:iuna/learn/db/learn_repository.dart';
import 'package:iuna/learn/llm/llm.dart';
import 'package:iuna/learn/llm/transcriber.dart';
import 'package:iuna/learn/voice/dictation.dart';

import 'fake_llm.dart';
import 'fake_voice.dart';

Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 200 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue, reason: 'condition never became true');
}

void main() {
  late LearnDatabase db;
  late LearnRepository repo;
  late CourseRow course;

  setUp(() async {
    db = LearnDatabase.forTesting(NativeDatabase.memory());
    repo = LearnRepository(db);
    course = await repo.createCourse(title: 'JLPT N1', goal: 'pass in December');
  });

  tearDown(() async {
    await repo.dispose();
    await db.close();
  });

  Future<(ChatController, FakeLlm, int)> make(
    List<Object> script, {
    String sessionKey = kRoomSessionKey,
    Future<String?> Function()? kickoff,
    int compactChars = 80000,
    int keepTail = 10,
    List<int>? promptBuilds,
  }) async {
    final session = await repo.openSession(course.id, sessionKey);
    final llm = FakeLlm(script);
    final c = ChatController(
      llm: llm,
      store: SessionChatStore(repo, session.id),
      systemPrompt: () async {
        promptBuilds?.add(1);
        return 'SYSTEM';
      },
      model: () async => 'test/model',
      tools: tutorTools(TutorScope(repo: repo, courseId: course.id, sessionKey: sessionKey)),
      onUsage: (u, {required model, required kind}) => repo.recordUsage(
        courseId: course.id,
        kind: kind,
        model: model,
        cost: u.cost,
      ),
      kickoff: kickoff,
      compactChars: compactChars,
      keepTail: keepTail,
    );
    await c.open();
    return (c, llm, session.id);
  }

  test('a plain turn stores the reply and records its cost', () async {
    final (c, llm, _) = await make([say('はじめまして！')]);
    await c.send('hello');

    expect(c.messages.map((m) => (m.role, m.content)), [
      (MessageRole.user, 'hello'),
      (MessageRole.assistant, 'はじめまして！'),
    ]);
    final sent = llm.requests.single;
    expect(sent.model, 'test/model');
    expect(sent.messages.first, {'role': 'system', 'content': 'SYSTEM'});
    expect(sent.messages.last, {'role': 'user', 'content': 'hello'});
    expect(sent.tools.map((t) => (t['function'] as Map)['name']),
        containsAll(['course_plan', 'ask_quiz', 'save_state']));
    expect(await repo.totalCost(courseId: course.id), closeTo(0.001, 1e-9));
    expect(c.busy, isFalse);
  });

  test('a second send while the first is still being stored is dropped', () async {
    final (c, llm, _) = await make([say('は, yes.')]);
    await Future.wait([c.send('は'), c.send('が')]);
    expect(c.messages.where((m) => m.role == MessageRole.user).map((m) => m.content), ['は']);
    expect(llm.requests, hasLength(1));
  });

  test('the tool loop registers a plan and pairs the call with its result',
      () async {
    final (c, llm, _) = await make([
      callTool('course_plan', {
        'chapters': [
          {'id': 'keigo-basics', 'title': 'Keigo basics', 'status': 'passed'},
          {'id': 'kenjougo', 'title': 'Humble speech'},
        ],
      }, text: 'Here is the plan.'),
      say('Open chapter 1 from the course screen.'),
    ]);
    await c.send('Sounds good, register it.');

    final chapters = await repo.chapters(course.id);
    expect(chapters.map((ch) => (ch.key, ch.status)), [
      ('keigo-basics', ChapterStatus.unlocked),
      ('kenjougo', ChapterStatus.locked),
    ], reason: "a status the model attached is ignored");

    final second = llm.requests[1].messages;
    final assistant = second[second.length - 2];
    expect(assistant['role'], 'assistant');
    expect(assistant['content'], 'Here is the plan.');
    expect((assistant['tool_calls'] as List).single['id'], 'call_1');
    expect(second.last['role'], 'tool');
    expect(second.last['tool_call_id'], 'call_1');
    expect(second.last['content'], startsWith('course registered'));
    expect(c.messages.last.content, 'Open chapter 1 from the course screen.');
  });

  test('a refused tool call reaches the model as an error, not a crash',
      () async {
    final (c, llm, _) = await make([
      callTool('course_write', {'chapter': 'x', 'markdown': 'theory'}),
      say('Right — theory belongs in the lesson.'),
    ]);
    await c.send('teach me');
    final result = llm.requests[1].messages.last;
    expect(result['role'], 'tool');
    expect(result['content'], startsWith("error: theory is written in the chapter's own lesson"));
    expect(c.error, isNull);
  });

  test('a quiz waits for the learner and returns labels, never the key',
      () async {
    final (c, llm, _) = await make([
      callTool('ask_quiz', {
        'title': 'Quick check',
        'questions': [
          {'prompt': '食べる → て-form?', 'options': ['食べて', '食べって'], 'answer': '食べて'},
          {'prompt': 'Translate: I went.'},
        ],
      }),
      say('Both right!'),
    ]);
    final sending = c.send('quiz me');
    await until(() => c.pendingQuiz != null);

    final spec = c.pendingQuiz!.spec;
    expect(spec.title, 'Quick check');
    expect(spec.questions.first.options!.map((o) => o.label), ['食べて', '食べって']);
    expect(spec.skipLabel, "I don't know");

    c.answerQuiz(spec.result(
      selected: {'q0': {'o0'}},
      text: {'q1': '行きました'},
      skipped: {},
    ));
    await sending;

    final toolResult = jsonDecode(llm.requests[1].messages.last['content'] as String);
    expect(toolResult, {
      'status': 'answered',
      'values': {'q0': ['食べて'], 'q1': '行きました'},
      'skipped': <String>[],
    });
    expect(c.pendingQuiz, isNull);
  });

  test('cancelling during a quiz records it and stops the loop', () async {
    final (c, llm, _) = await make([
      callTool('ask_quiz', {
        'questions': [
          {'prompt': 'q'},
        ],
      }),
    ]);
    final sending = c.send('quiz me');
    await until(() => c.pendingQuiz != null);
    c.cancel();
    await sending;

    expect(llm.requests, hasLength(1), reason: 'no model call after a cancel');
    expect(jsonDecode(c.messages.last.content), {'status': 'cancelled'});
    expect(c.busy, isFalse);
  });

  test('reopening after the app died mid-quiz closes the dangling call',
      () async {
    final session = await repo.openSession(course.id, kRoomSessionKey);
    await repo.addMessage(session.id, role: MessageRole.user, content: 'quiz me');
    await repo.addMessage(
      session.id,
      role: MessageRole.assistant,
      toolCalls: ChatToolCall.encodeList([
        ChatToolCall(id: 'call_9', name: 'ask_quiz', arguments: '{"questions":[{"prompt":"q"}]}'),
      ]),
    );
    final (c, llm, _) = await make([say('No problem, we can do it later.')]);

    expect(c.messages.last.role, MessageRole.tool);
    expect(c.messages.last.toolCallId, 'call_9');
    expect(jsonDecode(c.messages.last.content)['status'], 'cancelled');

    await c.send('sorry, I left');
    final wire = llm.requests.single.messages;
    expect(wire.map((m) => m['role']),
        ['system', 'user', 'assistant', 'tool', 'user']);
  });

  test('an empty session opens with the kickoff note', () async {
    final (c, llm, _) = await make(
      [say('こんにちは！ What does passing N1 mean to you?')],
      kickoff: () async => '(system note: first session)',
    );
    await until(() => !c.busy && c.messages.length == 2);
    expect(llm.requests.single.messages.last,
        {'role': 'user', 'content': '(system note: first session)'});
    expect(c.messages.first.role, MessageRole.note);
  });

  test('an API error shows a friendly line; retry reuses the stored message',
      () async {
    final (c, llm, _) = await make([
      const LlmException('No auth credentials found', status: 401),
      say('Back online.'),
    ]);
    await c.send('hello');
    expect(c.error, contains('Settings'));
    expect(c.messages.map((m) => m.role), [MessageRole.user]);

    await c.retry();
    expect(c.error, isNull);
    expect(c.messages.map((m) => m.role), [MessageRole.user, MessageRole.assistant]);
    expect(llm.requests[1].messages.where((m) => m['role'] == 'user'), hasLength(1));
  });

  test('reasoning is handed back inside a tool loop, not across turns',
      () async {
    final reasoning = [
      {'type': 'reasoning.text', 'text': 'plan it', 'index': 0},
    ];
    final (c, llm, _) = await make([
      callTool('save_state', {'markdown': '# state'}, reasoning: reasoning),
      say('Saved.'),
      say('Next turn.'),
    ]);
    await c.send('save');
    final inLoop = llm.requests[1].messages
        .firstWhere((m) => m['role'] == 'assistant' && m['tool_calls'] != null);
    expect(inLoop['reasoning_details'], reasoning);

    await c.send('again');
    final later = llm.requests[2].messages
        .firstWhere((m) => m['role'] == 'assistant' && m['tool_calls'] != null);
    expect(later.containsKey('reasoning_details'), isFalse);
    expect((await repo.course(course.id))!.stateMarkdown, '# state');
  });

  test('a long session is compacted: archived rows, summary, fresh prompt',
      () async {
    final builds = <int>[];
    final (c, llm, sessionId) = await make([
      say('A' * 300),
      say('B' * 300),
      say('## Context\n- summary of A'),
    ], compactChars: 500, keepTail: 2, promptBuilds: builds);

    await c.send('first');
    expect(llm.requests, hasLength(1), reason: 'still under the threshold');
    await c.send('second');

    final compaction = llm.requests[2];
    expect(compaction.messages.first['content'], kCompactionPrompt);
    expect(compaction.messages.last['content'], contains('learner: first'));
    expect(compaction.tools, isEmpty);

    final session = await repo.sessionById(sessionId);
    expect(session!.summary, '## Context\n- summary of A');
    expect(c.messages.map((m) => m.archived), [true, true, false, false]);
    expect(builds, hasLength(1));

    // The next turn re-pins the prompt so the summary is in it.
    llm.script.add(say('ok'));
    await c.send('third');
    expect(builds, hasLength(2));
    expect(llm.requests.last.messages.where((m) => m['role'] == 'user').first['content'],
        'second', reason: 'archived messages are not re-sent');
  });

  test('stop keeps the text that already streamed', () async {
    final controller = StreamController<LlmEvent>();
    final llm = _ControlledLlm(controller.stream);
    final session = await repo.openSession(course.id, kRoomSessionKey);
    final c = ChatController(
      llm: llm,
      store: SessionChatStore(repo, session.id),
      systemPrompt: () async => 'S',
      model: () async => 'm',
    );
    await c.open();
    final sending = c.send('explain は vs が');
    controller.add(const LlmTextDelta('は marks the topic'));
    await until(() => c.streaming.value.isNotEmpty);
    c.cancel();
    await sending;
    expect(c.messages.last.content, 'は marks the topic');
    expect(c.busy, isFalse);
    await controller.close();
  });

  test('a first message that failed is sent again the next time the chat opens',
      () async {
    final (first, _, _) = await make(
      [const LlmException('Network error: offline')],
      kickoff: () async => '(system note: first session)',
    );
    await until(() => !first.busy && first.error != null);
    expect(first.messages.single.kind, ChatController.kickoffKind);
    first.dispose();

    final (again, llm, _) = await make(
      [say('こんにちは！')],
      kickoff: () async => 'never sent twice',
    );
    await until(() => !again.busy && again.messages.length == 2);
    expect(llm.requests.single.messages.last['content'], '(system note: first session)');
    expect(again.messages.last.content, 'こんにちは！');
    expect(again.error, isNull);
  });

  test('a message left unanswered by an app kill is answered on reopen', () async {
    final session = await repo.openSession(course.id, kRoomSessionKey);
    await repo.addMessage(session.id, role: MessageRole.user, content: 'still there?');
    final (c, llm, _) = await make([say('Yes — where were we?')]);
    await until(() => !c.busy && c.messages.length == 2);
    expect(llm.requests.single.messages.last, {'role': 'user', 'content': 'still there?'});
    expect(c.messages.last.content, 'Yes — where were we?');
  });

  test('notes keep their kind so the view can caption them', () async {
    final (c, _, sessionId) = await make([say('Summary: …')]);
    await c.sendNote('(system note: wrap up)', kind: 'wrap_up');
    final stored = await repo.messages(sessionId);
    expect(stored.first.kind, 'wrap_up');
    expect(c.messages.first.kind, 'wrap_up');
  });

  test('a dictated clip holds off other sends, and its transcript replaces it in one update',
      () async {
    final llm = FakeLlm([say('はい、聞こえます。')]);
    final heard = Completer<Transcript>();
    final chat = ChatController(
      llm: llm,
      store: MemoryChatStore(),
      systemPrompt: () async => 'SYSTEM',
      model: () async => 'test/model',
      dictation: Dictation(recorder: FakeRecorder.new, transcriber: FakeTranscriber([heard])),
      voiceSettle: Duration.zero,
    );
    addTearDown(chat.dispose);
    await chat.open();
    // Each update: is the clip still shown, and has the message landed?
    final updates = <(bool, bool)>[];
    chat.addListener(() => updates.add((
          chat.pendingVoice != null,
          chat.messages.any((m) => m.role == MessageRole.user),
        )));

    final dictating = chat.dictate(
      VoiceClip(wav: FakeRecorder.wav, levels: const [], length: const Duration(seconds: 2)),
    );
    await chat.send('typed meanwhile');
    await chat.sendNote('a note meanwhile');
    expect(chat.pendingVoice!.transcribing, isTrue);
    expect(llm.requests, isEmpty);

    heard.complete(const Transcript('聞こえますか'));
    await dictating;

    expect(chat.pendingVoice, isNull);
    expect([for (final m in chat.messages) if (m.role != MessageRole.assistant) m.content],
        ['聞こえますか']);
    expect(llm.requests, hasLength(1));
    expect(updates.where((u) => !u.$1 && !u.$2), isEmpty,
        reason: 'the clip gives way in the very update that shows the message');
  });
}

class _ControlledLlm implements LlmClient {
  _ControlledLlm(this.stream);
  final Stream<LlmEvent> stream;

  @override
  Stream<LlmEvent> chat(LlmRequest request) => stream;
}
