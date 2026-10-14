import 'dart:math';

/// One chat-completions call. [messages] and [tools] are already in the
/// OpenAI wire shape, so any OpenAI-compatible endpoint can take them.
class LlmRequest {
  const LlmRequest({
    required this.model,
    required this.messages,
    this.tools = const [],
    this.maxTokens,
  });

  final String model;
  final List<Map<String, dynamic>> messages;
  final List<Map<String, dynamic>> tools;
  final int? maxTokens;
}

sealed class LlmEvent {
  const LlmEvent();
}

class LlmTextDelta extends LlmEvent {
  const LlmTextDelta(this.text);
  final String text;
}

/// A fragment of one tool call. Fragments sharing an [index] belong to
/// the same call; [arguments] arrive as JSON text split across chunks.
class LlmToolCallDelta extends LlmEvent {
  const LlmToolCallDelta({
    required this.index,
    this.id,
    this.name,
    this.arguments = '',
  });

  final int index;
  final String? id;
  final String? name;
  final String arguments;
}

/// OpenRouter's `reasoning_details` fragments. Reasoning models need
/// them handed back on the assistant message for the rest of a tool
/// loop, so they are folded like tool calls.
class LlmReasoningDelta extends LlmEvent {
  const LlmReasoningDelta(this.details);
  final List<Map<String, dynamic>> details;
}

class LlmUsage extends LlmEvent {
  const LlmUsage({this.promptTokens = 0, this.completionTokens = 0, this.cost});
  final int promptTokens;
  final int completionTokens;
  final double? cost;
}

class LlmFinish extends LlmEvent {
  const LlmFinish(this.reason);
  final String? reason;
}

class LlmException implements Exception {
  const LlmException(this.message, {this.status});

  final String message;
  final int? status;

  /// The line the learner sees.
  String get friendly => switch (status) {
        401 => 'OpenRouter rejected the API key. Check it in Settings.',
        402 => 'Your OpenRouter account is out of credits.',
        429 => 'OpenRouter is rate-limiting requests. Try again in a moment.',
        _ => message,
      };

  @override
  String toString() => status == null ? message : '$message ($status)';
}

abstract class LlmClient {
  Stream<LlmEvent> chat(LlmRequest request);
}

class ToolCallDraft {
  ToolCallDraft(this.index);

  final int index;
  String id = '';
  String name = '';
  final StringBuffer arguments = StringBuffer();
}

/// Folds a stream of [LlmEvent]s into one assistant turn.
class LlmTurn {
  final StringBuffer text = StringBuffer();
  final Map<int, ToolCallDraft> _calls = {};
  final List<_ReasoningDraft> _reasoning = [];
  LlmUsage? usage;
  String? finishReason;

  static final _rand = Random();

  void add(LlmEvent event) {
    switch (event) {
      case LlmTextDelta(:final text):
        this.text.write(text);
      case LlmToolCallDelta():
        final draft = _calls.putIfAbsent(event.index, () => ToolCallDraft(event.index));
        if (event.id != null && event.id!.isNotEmpty) draft.id = event.id!;
        if (event.name != null && event.name!.isNotEmpty) draft.name += event.name!;
        draft.arguments.write(event.arguments);
      case LlmReasoningDelta(:final details):
        for (final d in details) {
          _mergeReasoning(d);
        }
      case LlmUsage():
        usage = event;
      case LlmFinish(:final reason):
        finishReason = reason;
    }
  }

  void _mergeReasoning(Map<String, dynamic> fragment) {
    final index = fragment['index'];
    final type = fragment['type'];
    final existing = index == null
        ? null
        : _reasoning
            .where((r) => r.fields['index'] == index && r.fields['type'] == type)
            .firstOrNull;
    if (existing == null) {
      _reasoning.add(_ReasoningDraft(fragment));
    } else {
      existing.merge(fragment);
    }
  }

  /// Complete tool calls in index order. Providers that omit call ids
  /// in the stream get a synthetic one so results can still be paired.
  List<ToolCallDraft> get toolCalls {
    final ordered = _calls.values.toList()..sort((a, b) => a.index.compareTo(b.index));
    for (final c in ordered) {
      if (c.id.isEmpty) {
        c.id = 'call_${c.index}_${_rand.nextInt(1 << 32).toRadixString(36)}';
      }
    }
    return ordered.where((c) => c.name.isNotEmpty).toList();
  }

  List<Map<String, dynamic>> get reasoningDetails =>
      List.unmodifiable([for (final r in _reasoning) r.toJson()]);
}

/// One `reasoning_details` entry being assembled. Its text arrives a few
/// characters per chunk, so it grows in buffers rather than strings.
class _ReasoningDraft {
  _ReasoningDraft(Map<String, dynamic> first) {
    first.forEach(_set);
  }

  static const _appended = {'text', 'summary', 'data'};

  final Map<String, dynamic> fields = {};
  final Map<String, StringBuffer> _text = {};

  void merge(Map<String, dynamic> fragment) {
    fragment.forEach((key, value) {
      if (value != null) _set(key, value);
    });
  }

  void _set(String key, Object? value) {
    if (value is String && _appended.contains(key)) {
      (_text[key] ??= StringBuffer()).write(value);
    } else {
      _text.remove(key);
      fields[key] = value;
    }
  }

  Map<String, dynamic> toJson() => {
        ...fields,
        for (final e in _text.entries) e.key: e.value.toString(),
      };
}

Future<LlmTurn> collectTurn(Stream<LlmEvent> events) async {
  final turn = LlmTurn();
  await for (final e in events) {
    turn.add(e);
  }
  return turn;
}
