import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'llm.dart';
import 'sse.dart';

final Uri kOpenRouterChatEndpoint =
    Uri.parse('https://openrouter.ai/api/v1/chat/completions');
final Uri kOpenRouterKeyEndpoint = Uri.parse('https://openrouter.ai/api/v1/key');

Map<String, String> openRouterHeaders(String key) => {
      'Authorization': 'Bearer $key',
      'Content-Type': 'application/json',
      'HTTP-Referer': 'https://github.com/Raffaelbdl/iuna',
      'X-Title': 'Iuna',
    };

/// The saved key, or the 401 that sends the learner to Settings.
Future<String> openRouterKey(Future<String?> Function() apiKey) async {
  final key = await apiKey();
  if (key == null || key.isEmpty) {
    throw const LlmException('No OpenRouter API key saved.', status: 401);
  }
  return key;
}

/// Runs [request], turning a dropped connection into an [LlmException].
Future<T> openRouterSend<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on http.ClientException catch (e) {
    throw LlmException('Network error: ${e.message}');
  } on IOException catch (e) {
    throw LlmException('Network error: $e');
  }
}

/// A non-200 answer, as the learner reads it.
LlmException openRouterHttpError(int status, String body) => LlmException(
      OpenRouterClient.errorMessage(body) ?? 'OpenRouter answered HTTP $status',
      status: status,
    );

/// Streaming chat completions straight from the phone to OpenRouter —
/// there is no Iuna server in between.
class OpenRouterClient implements LlmClient {
  OpenRouterClient({
    required Future<String?> Function() apiKey,
    http.Client? client,
    Uri? endpoint,
  })  : _apiKey = apiKey,
        _client = client,
        _endpoint = endpoint ?? kOpenRouterChatEndpoint;

  final Future<String?> Function() _apiKey;
  final http.Client? _client;
  final Uri _endpoint;

  @override
  Stream<LlmEvent> chat(LlmRequest request) async* {
    final key = await openRouterKey(_apiKey);
    // A client per call when none is injected: closing it is what aborts
    // the connection when the learner taps stop.
    final client = _client ?? http.Client();
    try {
      final req = http.Request('POST', _endpoint)
        ..headers.addAll(openRouterHeaders(key))
        ..bodyBytes = await _encodeBody(request);
      final resp = await openRouterSend(() => client.send(req));
      if (resp.statusCode != 200) {
        throw openRouterHttpError(resp.statusCode, await resp.stream.bytesToString());
      }
      await for (final data in sseData(resp.stream)) {
        if (data.trim() == '[DONE]') break;
        final Object? json;
        try {
          json = jsonDecode(data);
        } on FormatException {
          continue;
        }
        if (json is! Map<String, dynamic>) continue;
        final error = json['error'];
        if (error != null) {
          throw LlmException(
            _describeError(error),
            status: error is Map ? (error['code'] as num?)?.toInt() : null,
          );
        }
        yield* Stream.fromIterable(parseChunk(json));
      }
    } finally {
      if (_client == null) client.close();
    }
  }

  /// A history carrying photos is megabytes of base64: encoding it on the
  /// UI isolate at every step of the tool loop stalls the chat.
  static Future<Uint8List> _encodeBody(LlmRequest request) {
    final body = {
      'model': request.model,
      'messages': request.messages,
      if (request.tools.isNotEmpty) 'tools': request.tools,
      if (request.maxTokens != null) 'max_tokens': request.maxTokens,
      'stream': true,
      'usage': {'include': true},
    };
    Uint8List encode() => utf8.encode(jsonEncode(body));
    final photos = request.messages.any((m) => m['content'] is List);
    return photos ? Isolate.run(encode) : Future.value(encode());
  }

  static Iterable<LlmEvent> parseChunk(Map<String, dynamic> json) sync* {
    final choices = json['choices'];
    if (choices is List && choices.isNotEmpty && choices.first is Map) {
      final choice = choices.first as Map;
      final delta = choice['delta'];
      if (delta is Map) {
        final content = delta['content'];
        if (content is String && content.isNotEmpty) yield LlmTextDelta(content);
        final reasoning = delta['reasoning_details'];
        if (reasoning is List && reasoning.isNotEmpty) {
          yield LlmReasoningDelta([
            for (final d in reasoning)
              if (d is Map) Map<String, dynamic>.from(d),
          ]);
        }
        final calls = delta['tool_calls'];
        if (calls is List) {
          for (final c in calls) {
            if (c is! Map) continue;
            final fn = c['function'];
            yield LlmToolCallDelta(
              index: (c['index'] as num?)?.toInt() ?? 0,
              id: c['id'] as String?,
              name: fn is Map ? fn['name'] as String? : null,
              arguments: fn is Map ? (fn['arguments'] as String? ?? '') : '',
            );
          }
        }
      }
      final finish = choice['finish_reason'];
      if (finish is String) yield LlmFinish(finish);
    }
    final usage = json['usage'];
    if (usage is Map) {
      yield LlmUsage(
        promptTokens: (usage['prompt_tokens'] as num?)?.toInt() ?? 0,
        completionTokens: (usage['completion_tokens'] as num?)?.toInt() ?? 0,
        cost: (usage['cost'] as num?)?.toDouble(),
      );
    }
  }

  static String? errorMessage(String body) {
    try {
      final json = jsonDecode(body);
      if (json is Map && json['error'] != null) return _describeError(json['error']);
    } on FormatException {
      // Not JSON; fall through to the status line.
    }
    return null;
  }

  static String _describeError(Object error) {
    if (error is Map) {
      final msg = error['message'];
      final raw = (error['metadata'] is Map) ? (error['metadata'] as Map)['raw'] : null;
      if (msg is String && raw is String && raw.isNotEmpty) return '$msg: $raw';
      if (msg is String) return msg;
    }
    return error.toString();
  }
}

sealed class KeyCheck {
  const KeyCheck();
}

class KeyValid extends KeyCheck {
  const KeyValid({this.label});
  final String? label;
}

class KeyRejected extends KeyCheck {
  const KeyRejected();
}

class KeyUnverified extends KeyCheck {
  const KeyUnverified(this.reason);
  final String reason;
}

/// Asks OpenRouter whether [key] is live, without spending anything.
Future<KeyCheck> checkOpenRouterKey(String key, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final resp = await c
        .get(kOpenRouterKeyEndpoint, headers: {'Authorization': 'Bearer $key'})
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body);
      final data = json is Map ? json['data'] : null;
      return KeyValid(label: data is Map ? data['label'] as String? : null);
    }
    if (resp.statusCode == 401 || resp.statusCode == 403) return const KeyRejected();
    return KeyUnverified('HTTP ${resp.statusCode}');
  } catch (e) {
    return KeyUnverified(e.toString());
  } finally {
    if (client == null) c.close();
  }
}
