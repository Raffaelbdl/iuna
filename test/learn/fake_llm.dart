import 'dart:convert';

import 'package:iuna/learn/llm/llm.dart';

/// Replays scripted turns and records every request it was sent. A turn
/// is a list of events, or an [Exception] to fail with.
class FakeLlm implements LlmClient {
  FakeLlm(this.script);

  final List<Object> script;
  final requests = <LlmRequest>[];

  @override
  Stream<LlmEvent> chat(LlmRequest request) {
    requests.add(request);
    if (script.isEmpty) return Stream.error(StateError('no scripted turn left'));
    final next = script.removeAt(0);
    if (next is Exception) return Stream.error(next);
    return Stream.fromIterable(next as List<LlmEvent>);
  }
}

List<LlmEvent> say(String text, {double cost = 0.001}) => [
      LlmTextDelta(text),
      const LlmFinish('stop'),
      LlmUsage(promptTokens: 10, completionTokens: 5, cost: cost),
    ];

List<LlmEvent> callTool(
  String name,
  Map<String, dynamic> args, {
  String id = 'call_1',
  String text = '',
  List<Map<String, dynamic>>? reasoning,
}) =>
    [
      if (reasoning != null) LlmReasoningDelta(reasoning),
      if (text.isNotEmpty) LlmTextDelta(text),
      LlmToolCallDelta(index: 0, id: id, name: name, arguments: jsonEncode(args)),
      const LlmFinish('tool_calls'),
    ];
