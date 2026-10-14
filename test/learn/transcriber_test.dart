import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iuna/learn/llm/llm.dart';
import 'package:iuna/learn/llm/transcriber.dart';

void main() {
  final wav = Uint8List.fromList(utf8.encode('RIFF....WAVE'));

  test('posts the clip as base64 WAV to MAI-Transcribe and reads text and cost', () async {
    late http.Request sent;
    final client = MockClient((req) async {
      sent = req;
      return http.Response.bytes(
        utf8.encode(
          jsonEncode({
            'text': ' お忙しいところ失礼いたします。 ',
            'usage': {'cost': 0.000444, 'seconds': 15.4},
          }),
        ),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final stt = OpenRouterTranscriber(apiKey: () async => 'sk-or-test', client: client);

    final transcript = await stt.transcribe(wav);

    expect(sent.url, kOpenRouterTranscriptionsEndpoint);
    expect(sent.headers['Authorization'], 'Bearer sk-or-test');
    expect(jsonDecode(sent.body), {
      'model': kDictationModel,
      'input_audio': {'data': base64Encode(wav), 'format': 'wav'},
    });
    expect(transcript.text, 'お忙しいところ失礼いたします。');
    expect(transcript.cost, 0.000444);
  });

  test('an OpenRouter error surfaces as an LlmException with its status', () async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'error': {'message': 'Insufficient credits', 'code': 402},
        }),
        402,
      ),
    );
    final stt = OpenRouterTranscriber(apiKey: () async => 'sk-or-test', client: client);

    await expectLater(
      stt.transcribe(wav),
      throwsA(
        isA<LlmException>()
            .having((e) => e.status, 'status', 402)
            .having((e) => e.friendly, 'friendly', 'Your OpenRouter account is out of credits.'),
      ),
    );
  });

  test('no saved key fails before any request', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('{}', 200);
    });
    final stt = OpenRouterTranscriber(apiKey: () async => null, client: client);

    await expectLater(
      stt.transcribe(wav),
      throwsA(isA<LlmException>().having((e) => e.status, 'status', 401)),
    );
    expect(calls, 0);
  });
}
