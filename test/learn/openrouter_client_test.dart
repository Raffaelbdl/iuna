import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iuna/learn/llm/llm.dart';
import 'package:iuna/learn/llm/openrouter_client.dart';
import 'package:iuna/learn/llm/sse.dart';

String _chunk(Map<String, dynamic> json) => 'data: ${jsonEncode(json)}\n\n';

Map<String, dynamic> _delta(Map<String, dynamic> delta, {String? finish}) => {
      'choices': [
        {'index': 0, 'delta': delta, 'finish_reason': finish},
      ],
    };

MockClient _streaming(List<String> pieces, {int status = 200, void Function(http.BaseRequest, String)? onRequest}) {
  return MockClient.streaming((request, body) async {
    onRequest?.call(request, await body.bytesToString());
    return http.StreamedResponse(
      Stream.fromIterable(pieces.map(utf8.encode)),
      status,
    );
  });
}

void main() {
  group('sseData', () {
    test('joins data lines, skips comments, survives split UTF-8', () async {
      final bytes = utf8.encode(': OPENROUTER PROCESSING\n\ndata: {"a":"熊"}\n\n'
          'data: line1\ndata: line2\n\ndata: tail');
      // Cut in the middle of 熊 (3 bytes) and mid-line.
      final cut1 = bytes.indexOf(utf8.encode('熊').first) + 1;
      final chunks = [bytes.sublist(0, 5), bytes.sublist(5, cut1), bytes.sublist(cut1)];
      final out = await sseData(Stream.fromIterable(chunks)).toList();
      expect(out, ['{"a":"熊"}', 'line1\nline2', 'tail']);
    });
  });

  group('OpenRouterClient.chat', () {
    test('streams text, tool calls split across chunks, and usage', () async {
      Map<String, dynamic>? sentBody;
      String? auth;
      final client = _streaming([
        ': OPENROUTER PROCESSING\n\n',
        _chunk(_delta({'role': 'assistant', 'content': 'こん'})),
        _chunk(_delta({'content': 'にちは'})),
        _chunk(_delta({
          'tool_calls': [
            {'index': 0, 'id': 'call_1', 'type': 'function', 'function': {'name': 'save_state', 'arguments': '{"mark'}},
          ],
        })),
        _chunk(_delta({
          'tool_calls': [
            {'index': 0, 'function': {'arguments': 'down":"# s"}'}},
          ],
        }, finish: 'tool_calls')),
        _chunk({'choices': <Object>[], 'usage': {'prompt_tokens': 120, 'completion_tokens': 8, 'cost': 0.00002}}),
        'data: [DONE]\n\n',
      ], onRequest: (req, body) {
        sentBody = jsonDecode(body) as Map<String, dynamic>;
        auth = req.headers['Authorization'];
      });

      final llm = OpenRouterClient(apiKey: () async => 'sk-or-test', client: client);
      final turn = await collectTurn(llm.chat(const LlmRequest(
        model: 'deepseek/deepseek-v4-flash-0731',
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
        tools: [
          {'type': 'function', 'function': {'name': 'save_state'}},
        ],
      )));

      expect(auth, 'Bearer sk-or-test');
      expect(sentBody!['stream'], isTrue);
      expect(sentBody!['model'], 'deepseek/deepseek-v4-flash-0731');
      expect(sentBody!['tools'], hasLength(1));
      expect(sentBody!['usage'], {'include': true});

      expect(turn.text.toString(), 'こんにちは');
      expect(turn.finishReason, 'tool_calls');
      final call = turn.toolCalls.single;
      expect(call.id, 'call_1');
      expect(call.name, 'save_state');
      expect(jsonDecode(call.arguments.toString()), {'markdown': '# s'});
      expect(turn.usage!.promptTokens, 120);
      expect(turn.usage!.cost, closeTo(0.00002, 1e-12));
    });

    test('a non-200 answer becomes an LlmException with the API message', () async {
      final client = MockClient((_) async => http.Response(
            jsonEncode({'error': {'code': 401, 'message': 'No auth credentials found'}}),
            401,
          ));
      final llm = OpenRouterClient(apiKey: () async => 'bad', client: client);
      await expectLater(
        collectTurn(llm.chat(const LlmRequest(model: 'm', messages: []))),
        throwsA(isA<LlmException>()
            .having((e) => e.status, 'status', 401)
            .having((e) => e.message, 'message', 'No auth credentials found')
            .having((e) => e.friendly, 'friendly', contains('Settings'))),
      );
    });

    test('an error event mid-stream aborts the turn', () async {
      final client = _streaming([
        _chunk(_delta({'content': 'partial'})),
        _chunk({'error': {'code': 502, 'message': 'Provider returned error'}, 'choices': [{'delta': {'content': ''}, 'finish_reason': 'error'}]}),
      ]);
      final llm = OpenRouterClient(apiKey: () async => 'k', client: client);
      await expectLater(
        collectTurn(llm.chat(const LlmRequest(model: 'm', messages: []))),
        throwsA(isA<LlmException>().having((e) => e.status, 'status', 502)),
      );
    });

    test('no key fails before touching the network', () async {
      var called = false;
      final client = MockClient((_) async {
        called = true;
        return http.Response('', 200);
      });
      final llm = OpenRouterClient(apiKey: () async => null, client: client);
      await expectLater(
        collectTurn(llm.chat(const LlmRequest(model: 'm', messages: []))),
        throwsA(isA<LlmException>().having((e) => e.status, 'status', 401)),
      );
      expect(called, isFalse);
    });
  });

  test('reasoning fragments merge by index and type', () {
    final turn = LlmTurn()
      ..add(const LlmReasoningDelta([
        {'type': 'reasoning.text', 'text': 'First ', 'index': 0, 'format': 'unknown'},
      ]))
      ..add(const LlmReasoningDelta([
        {'type': 'reasoning.text', 'text': 'thought.', 'index': 0, 'signature': 'sig'},
      ]));
    expect(turn.reasoningDetails, [
      {'type': 'reasoning.text', 'text': 'First thought.', 'index': 0, 'format': 'unknown', 'signature': 'sig'},
    ]);
  });

  group('checkOpenRouterKey', () {
    test('200 is valid, 401 is rejected, anything else is unverified', () async {
      expect(
        await checkOpenRouterKey('k', client: MockClient((_) async => http.Response(jsonEncode({'data': {'label': 'phone'}}), 200))),
        isA<KeyValid>().having((k) => k.label, 'label', 'phone'),
      );
      expect(
        await checkOpenRouterKey('k', client: MockClient((_) async => http.Response('{}', 401))),
        isA<KeyRejected>(),
      );
      expect(
        await checkOpenRouterKey('k', client: MockClient((_) async => throw http.ClientException('offline'))),
        isA<KeyUnverified>(),
      );
    });
  });
}
