import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'llm.dart';
import 'openrouter_client.dart';

final Uri kOpenRouterTranscriptionsEndpoint = Uri.parse(
  'https://openrouter.ai/api/v1/audio/transcriptions',
);

/// Tried on the learner's own accented Japanese against GPT Transcribe
/// and Qwen3-ASR-Flash (tools/stt_probe.dart): as accurate, and the
/// cheapest of the three.
const String kDictationModel = 'microsoft/mai-transcribe-2';

class Transcript {
  const Transcript(this.text, {this.cost});

  final String text;

  /// USD as reported by OpenRouter; null when the provider didn't say.
  final double? cost;
}

abstract class Transcriber {
  String get model;
  Future<Transcript> transcribe(Uint8List wav);
}

/// Speech to text through OpenRouter, on the tutor's key. No language
/// hint: dictation mixes Japanese and English.
class OpenRouterTranscriber implements Transcriber {
  OpenRouterTranscriber({
    required Future<String?> Function() apiKey,
    http.Client? client,
    this.model = kDictationModel,
  }) : _apiKey = apiKey,
       _client = client;

  final Future<String?> Function() _apiKey;
  final http.Client? _client;

  @override
  final String model;

  @override
  Future<Transcript> transcribe(Uint8List wav) async {
    final key = await openRouterKey(_apiKey);
    final body = await _encodeRequest(model, wav);
    final client = _client ?? http.Client();
    try {
      final resp = await openRouterSend(
        () => client.post(
          kOpenRouterTranscriptionsEndpoint,
          headers: openRouterHeaders(key),
          body: body,
        ),
      ).timeout(const Duration(seconds: 60));
      final text = utf8.decode(resp.bodyBytes, allowMalformed: true);
      if (resp.statusCode != 200) {
        throw openRouterHttpError(resp.statusCode, text);
      }
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic>) throw const FormatException();
      final usage = json['usage'];
      return Transcript(
        (json['text'] as String? ?? '').trim(),
        cost: usage is Map ? (usage['cost'] as num?)?.toDouble() : null,
      );
    } on TimeoutException {
      throw const LlmException('Transcription took too long. Try again.');
    } on FormatException {
      throw const LlmException('OpenRouter sent back something other than a transcript.');
    } finally {
      if (_client == null) client.close();
    }
  }
}

/// A minute of audio is ~2.5 MB of base64: built off the UI isolate, from
/// a scope that holds nothing but what it sends.
Future<Uint8List> _encodeRequest(String model, Uint8List wav) => Isolate.run(
  () => utf8.encode(
    jsonEncode({
      'model': model,
      'input_audio': {'data': base64Encode(wav), 'format': 'wav'},
    }),
  ),
);
