import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../db/learn_database.dart';
import '../llm/llm.dart';
import '../llm/transcriber.dart';
import '../photo/photo.dart';
import '../voice/dictation.dart';
import 'chat_models.dart';
import 'chat_store.dart';
import 'compaction.dart';
import 'quiz.dart';
import 'tools.dart';

typedef UsageSink = Future<void> Function(
  LlmUsage usage, {
  required String model,
  required String kind,
});

/// Drives one conversation: guu's `Session._loop` (call the model, run the
/// tools it asked for, repeat), streamed, with the quiz card as the one
/// tool that waits on the learner.
class ChatController extends ChangeNotifier {
  ChatController({
    required this.llm,
    required this.store,
    required this.systemPrompt,
    required this.model,
    this.photoModel,
    this.tools = const [],
    this.onUsage,
    this.usageKind = 'chat',
    this.dictation,
    this.kickoff,
    this.maxSteps = 12,
    this.compactChars = 80000,
    this.keepTail = 10,
    this.voiceSettle = const Duration(milliseconds: 350),
  });

  final LlmClient llm;
  final ChatStore store;

  /// Pinned per open (and rebuilt after compaction): a byte-stable
  /// prefix is what keeps the provider's prompt cache hitting.
  final Future<String> Function() systemPrompt;
  final Future<String> Function() model;

  /// The model for a turn whose history carries a photo: the default
  /// tutor model cannot read one. Without it every turn uses [model].
  final Future<String> Function()? photoModel;
  final List<ChatTool> tools;
  final UsageSink? onUsage;
  final String usageKind;

  /// Hold-to-speak: the composer's recorder, and the transcriber that
  /// turns its clips into the learner's messages.
  final Dictation? dictation;

  /// A system note sent when the conversation is empty on open, so the
  /// tutor speaks first.
  final Future<String?> Function()? kickoff;
  final int maxSteps;
  final int compactChars;
  final int keepTail;

  /// How long a transcript shows in its bubble before it goes out, so
  /// the learner sees what was heard.
  final Duration voiceSettle;

  /// [ChatMessage.kind] of the note [kickoff] produces.
  static const kickoffKind = 'kickoff';

  List<ChatMessage> _messages = const [];
  final Map<int, List<Map<String, dynamic>>> _reasoning = {};
  String? _pinnedPrompt;
  final _streaming = ValueNotifier<String>('');
  String? _status;
  String? _error;
  bool _busy = false;
  bool _loaded = false;
  bool _disposed = false;
  bool _cancelRequested = false;
  PendingQuiz? _quiz;
  PendingVoice? _voice;
  VoidCallback? _abortStream;

  List<ChatMessage> get messages => _messages;

  /// The reply being streamed, empty between replies. Only its first
  /// text goes through the controller's own listeners: the rest would
  /// rebuild the whole conversation once per chunk.
  ValueListenable<String> get streaming => _streaming;

  String? get status => _status;
  String? get error => _error;
  bool get busy => _busy;
  bool get loaded => _loaded;
  PendingQuiz? get pendingQuiz => _quiz;
  PendingVoice? get pendingVoice => _voice;

  ChatTool? toolNamed(String name) {
    for (final t in tools) {
      if (t.name == name) return t;
    }
    return null;
  }

  Future<void> open() async {
    _messages = await store.load();
    await _repairInterrupted();
    _loaded = true;
    _notify();
    if (_messages.isEmpty) {
      final note = await kickoff?.call();
      if (note != null) {
        await _start(ChatMessage(role: MessageRole.note, content: note, kind: kickoffKind));
      }
    } else if (_awaitingReply) {
      // The last turn never got its answer: the call failed and the
      // learner left, or the app died mid-stream. Pick it up again.
      await _run();
    }
  }

  bool get _awaitingReply {
    final active = _messages.where((m) => !m.archived);
    if (active.isEmpty) return false;
    final role = active.last.role;
    return role == MessageRole.user || role == MessageRole.note;
  }

  /// A message from the learner, with the [photo] they attached to it.
  /// A photo alone is a message too: it asks the tutor to read it.
  Future<void> send(String text, {Photo? photo}) async {
    final t = text.trim();
    if ((t.isEmpty && photo == null) || _busy || !_loaded || _voice != null) return;
    await _start(ChatMessage(
      role: MessageRole.user,
      content: t,
      photos: [?photo],
    ));
  }

  Future<void> sendNote(String note, {String? kind}) async {
    if (_busy || !_loaded || _voice != null) return;
    await _start(ChatMessage(role: MessageRole.note, content: note, kind: kind));
  }

  /// Re-runs the loop after an error; the learner's message is already
  /// stored.
  Future<void> retry() async {
    if (_busy || _error == null) return;
    _error = null;
    await _run();
  }

  void answerQuiz(Map<String, dynamic> result) => _quiz?.complete(result);

  /// Transcribes [clip] and sends what was heard as the learner's
  /// message; until then it is the [pendingVoice].
  Future<void> dictate(VoiceClip clip) async {
    if (dictation == null || !_loaded || _voice != null) return;
    _voice = PendingVoice(clip);
    _notify();
    await _transcribe(clip);
  }

  Future<void> retryVoice() async {
    final voice = _voice;
    if (voice == null || !voice.canRetry) return;
    _voice = PendingVoice(voice.clip);
    _notify();
    await _transcribe(voice.clip);
  }

  void discardVoice() {
    if (_voice?.error == null) return;
    _voice = null;
    _notify();
  }

  /// Stops streaming, keeps whatever text already arrived, and answers a
  /// waiting quiz with `cancelled`.
  void cancel() {
    if (!_busy) return;
    _cancelRequested = true;
    _abortStream?.call();
    _quiz?.complete(const {'status': 'cancelled'});
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    _streaming.dispose();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _setStreaming(String text) {
    if (!_disposed) _streaming.value = text;
  }

  Future<void> _start(ChatMessage message, {PendingVoice? replacing}) async {
    _error = null;
    // Reasoning is handed back only within one tool loop; a new learner
    // turn starts clean.
    _reasoning.clear();
    // Busy before the write, so a second tap on an answer button can't
    // send it again while the first is being stored.
    _busy = true;
    _notify();
    try {
      _messages = [..._messages, await store.append(message)];
      if (replacing != null && identical(_voice, replacing)) _voice = null;
    } catch (_) {
      _busy = false;
      _notify();
      rethrow;
    }
    await _run();
  }

  Future<void> _run() async {
    _busy = true;
    _cancelRequested = false;
    _status = null;
    _notify();
    var finished = false;
    try {
      finished = await _loop();
    } on LlmException catch (e) {
      _error = e.friendly;
    } catch (e) {
      _error = 'Something went wrong: $e';
    } finally {
      _busy = false;
      _setStreaming('');
      _status = null;
      _abortStream = null;
      _notify();
    }
    if (finished) await _maybeCompact();
    await _sendVoice();
  }

  Future<void> _transcribe(VoiceClip clip) async {
    final transcriber = dictation!.transcriber;
    final Transcript heard;
    try {
      heard = await transcriber.transcribe(clip.wav);
    } on LlmException catch (e) {
      return _voiceFailed(clip, e.friendly, canRetry: true);
    } catch (e) {
      return _voiceFailed(clip, 'Transcription failed: $e', canRetry: true);
    }
    unawaited(_recordDictation(heard, transcriber.model));
    if (heard.text.isEmpty) {
      return _voiceFailed(clip, 'Nothing heard. Hold the mic while you speak.');
    }
    if (_disposed) return;
    _voice = PendingVoice(clip, text: heard.text);
    _notify();
    await Future<void>.delayed(voiceSettle);
    await _sendVoice();
  }

  Future<void> _recordDictation(Transcript heard, String model) async {
    try {
      await onUsage?.call(LlmUsage(cost: heard.cost), model: model, kind: 'dictation');
    } catch (_) {
      // Bookkeeping only: a failed write must not lose what was said.
    }
  }

  void _voiceFailed(VoiceClip clip, String error, {bool canRetry = false}) {
    if (_disposed) return;
    _voice = PendingVoice(clip, error: error, canRetry: canRetry);
    _notify();
  }

  /// The transcript goes out once nothing else is running, and the
  /// pending voice leaves in the very update that shows the message.
  Future<void> _sendVoice() async {
    final voice = _voice;
    final text = voice?.text;
    if (_disposed || text == null || _busy || !_loaded) return;
    await _start(ChatMessage(role: MessageRole.user, content: text), replacing: voice);
  }

  /// True when the model finished its turn normally.
  Future<bool> _loop() async {
    _pinnedPrompt ??= await systemPrompt();
    // A photo anywhere in the live history means every request in this
    // session carries it, so the whole session goes to a model that can
    // read one — until compaction archives the photo away again.
    final photos = _messages.any((m) => !m.archived && m.photos.isNotEmpty);
    final modelId = await (photos ? photoModel ?? model : model)();
    final specs = [for (final t in tools) t.toApi()];
    for (var step = 0; step < maxSteps; step++) {
      final (turn, cancelled) = await _stream(
        LlmRequest(model: modelId, messages: _apiMessages(), tools: specs),
      );
      final usage = turn.usage;
      if (usage != null) await onUsage?.call(usage, model: modelId, kind: usageKind);

      final text = turn.text.toString();
      final calls = cancelled
          ? const <ChatToolCall>[]
          : [
              for (final c in turn.toolCalls)
                ChatToolCall(id: c.id, name: c.name, arguments: c.arguments.toString()),
            ];
      if (text.trim().isEmpty && calls.isEmpty) {
        if (!cancelled) _error = 'Kuma-sensei sent back an empty reply.';
        return false;
      }
      final stored = await store.append(
        ChatMessage(role: MessageRole.assistant, content: text, toolCalls: calls),
      );
      if (turn.reasoningDetails.isNotEmpty && stored.id != null) {
        _reasoning[stored.id!] = turn.reasoningDetails;
      }
      _messages = [..._messages, stored];
      _setStreaming('');
      _notify();
      if (cancelled) return false;
      if (calls.isEmpty) return true;

      for (final call in calls) {
        final result = await _runTool(call);
        _messages = [
          ..._messages,
          await store.append(ChatMessage(
            role: MessageRole.tool,
            content: result,
            toolCallId: call.id,
            toolName: call.name,
          )),
        ];
        _notify();
      }
      if (_cancelRequested) return false;
    }
    _messages = [
      ..._messages,
      await store.append(ChatMessage(
        role: MessageRole.assistant,
        content: '(I stopped after $maxSteps steps in a row. Say “continue” '
            'if you want me to keep going.)',
      )),
    ];
    return true;
  }

  Future<(LlmTurn, bool)> _stream(LlmRequest request) async {
    final turn = LlmTurn();
    final done = Completer<void>();
    var cancelled = false;
    late final StreamSubscription<LlmEvent> sub;
    sub = llm.chat(request).listen(
      (event) {
        turn.add(event);
        switch (event) {
          case LlmTextDelta():
            final first = _streaming.value.isEmpty;
            _setStreaming(turn.text.toString());
            if (first) _notify();
          case LlmToolCallDelta(:final name) when name != null && name.isNotEmpty:
            _status = toolNamed(name)?.runningLabel ?? 'Working…';
            _notify();
          default:
            break;
        }
      },
      onError: (Object e, StackTrace st) {
        if (!done.isCompleted) done.completeError(e, st);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );
    _abortStream = () {
      cancelled = true;
      unawaited(sub.cancel());
      if (!done.isCompleted) done.complete();
    };
    if (_cancelRequested) _abortStream!();
    await done.future;
    _abortStream = null;
    return (turn, cancelled);
  }

  Future<String> _runTool(ChatToolCall call) async {
    if (_cancelRequested) return toolErrorResult('cancelled — the learner stopped this turn');
    final tool = toolNamed(call.name);
    if (tool == null) return toolErrorResult("unknown tool '${call.name}'");
    final args = call.args;
    if (args == null) return toolErrorResult('tool arguments were not a valid JSON object');
    _status = tool.runningLabel;
    _notify();
    try {
      return await tool.run(args, ToolRunContext(askQuiz: _askQuiz));
    } on ToolError catch (e) {
      return toolErrorResult(e.message);
    } catch (e) {
      return toolErrorResult('$e');
    }
  }

  Future<Map<String, dynamic>> _askQuiz(QuizSpec spec) async {
    final pending = PendingQuiz(spec);
    _quiz = pending;
    _status = null;
    _notify();
    if (_cancelRequested) pending.complete(const {'status': 'cancelled'});
    try {
      return await pending.future;
    } finally {
      if (identical(_quiz, pending)) {
        _quiz = null;
        _notify();
      }
    }
  }

  /// The wire history: archived messages are left out (the summary in the
  /// system prompt stands in for them), and every tool call is paired
  /// with a result so a crash mid-tool can never wedge the conversation.
  List<Map<String, dynamic>> _apiMessages() {
    final active = [for (final m in _messages) if (!m.archived) m];
    final out = <Map<String, dynamic>>[
      {'role': 'system', 'content': _pinnedPrompt ?? ''},
    ];
    var i = 0;
    while (i < active.length) {
      final m = active[i];
      i++;
      if (m.role == MessageRole.tool) continue;
      out.add(m.toApi(reasoning: m.id == null ? null : _reasoning[m.id]));
      if (m.role != MessageRole.assistant || m.toolCalls.isEmpty) continue;
      final ids = {for (final c in m.toolCalls) c.id};
      final answered = <String>{};
      while (i < active.length && active[i].role == MessageRole.tool) {
        final r = active[i];
        final id = r.toolCallId;
        if (id != null && ids.contains(id) && answered.add(id)) out.add(r.toApi());
        i++;
      }
      for (final c in m.toolCalls) {
        if (!answered.contains(c.id)) {
          out.add({
            'role': 'tool',
            'tool_call_id': c.id,
            'content': toolErrorResult('interrupted before it finished'),
          });
        }
      }
    }
    return out;
  }

  /// A tool call left unanswered at the tail means the app died mid-tool
  /// (usually with a quiz on screen). Record it so the tutor and the
  /// learner both see what happened.
  Future<void> _repairInterrupted() async {
    final last = _messages.lastIndexWhere((m) => m.role == MessageRole.assistant);
    if (last < 0 || _messages[last].toolCalls.isEmpty) return;
    final tail = _messages.sublist(last + 1);
    if (tail.any((m) => m.role != MessageRole.tool)) return;
    final answered = {for (final m in tail) m.toolCallId};
    for (final c in _messages[last].toolCalls) {
      if (answered.contains(c.id)) continue;
      final content = toolNamed(c.name)?.interruptedResult ?? ChatTool.interruptedDefault;
      _messages = [
        ..._messages,
        await store.append(ChatMessage(
          role: MessageRole.tool,
          content: content,
          toolCallId: c.id,
          toolName: c.name,
        )),
      ];
    }
  }

  Future<void> _maybeCompact() async {
    if (!store.supportsCompaction) return;
    final active = [for (final m in _messages) if (!m.archived) m];
    final size = active.fold<int>(0, (n, m) => n + m.wireSize);
    if (size <= compactChars) return;
    // Cut at a learner message so the kept tail never starts mid tool
    // exchange.
    var cut = active.length;
    for (var i = math.max(0, active.length - keepTail); i < active.length; i++) {
      final role = active[i].role;
      if (role == MessageRole.user || role == MessageRole.note) {
        cut = i;
        break;
      }
    }
    if (cut == 0) return;
    final old = active.sublist(0, cut);
    _busy = true;
    _status = 'Tidying up older messages…';
    _notify();
    try {
      final modelId = await model();
      final previous = await store.summary();
      final turn = await collectTurn(llm.chat(LlmRequest(model: modelId, messages: [
        {'role': 'system', 'content': kCompactionPrompt},
        {
          'role': 'user',
          'content': 'Conversation:\n'
              '${previous == null ? '' : 'Summary of what came before:\n$previous\n\n'}'
              '${compactionTranscript(old)}',
        },
      ])));
      final usage = turn.usage;
      if (usage != null) await onUsage?.call(usage, model: modelId, kind: 'compact');
      final summary = turn.text.toString().trim();
      if (summary.isEmpty) return;
      await store.compact(through: old.last, summary: summary);
      _messages = await store.load();
      _pinnedPrompt = null;
    } catch (_) {
      // Best effort: an oversized history still works, it only costs more.
    } finally {
      _busy = false;
      _status = null;
      _notify();
    }
  }
}
