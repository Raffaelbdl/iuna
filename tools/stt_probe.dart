// Sends the same voice clips through the app's OpenRouterTranscriber on
// several speech-to-text models, and prints what each one heard, how
// long it took and what it cost — for picking the Learn tab's dictation
// model on real learner speech rather than on benchmarks.
//
// Usage:
//   export OPENROUTER_API_KEY=sk-or-...
//   dart run tools/stt_probe.dart ~/stt-clips/*
//   dart run tools/stt_probe.dart --models microsoft/mai-transcribe-2 a.m4a
//
// Every clip is re-encoded to 16 kHz mono WAV with ffmpeg first, which is
// what the app records.

import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:iuna/learn/llm/llm.dart';
import 'package:iuna/learn/llm/transcriber.dart';

const kDefaultModels = [
  kDictationModel,
  'openai/gpt-transcribe',
  'qwen/qwen3-asr-flash-2026-02-10',
];

const _wavBytesPerSecond = 16000 * 2;

Future<int> main(List<String> argv) async {
  final parser = ArgParser()
    ..addMultiOption(
      'models',
      defaultsTo: kDefaultModels,
      help: 'Comma-separated OpenRouter model ids.',
    )
    ..addFlag('help', abbr: 'h', negatable: false);
  final ArgResults args;
  try {
    args = parser.parse(argv);
  } on FormatException catch (e) {
    stderr.writeln(e.message);
    return 64;
  }
  if (args.flag('help') || args.rest.isEmpty) {
    stdout
      ..writeln('Usage: dart run tools/stt_probe.dart [options] <clip>...')
      ..writeln(parser.usage);
    return args.flag('help') ? 0 : 64;
  }

  final key = Platform.environment['OPENROUTER_API_KEY'] ?? '';
  if (key.isEmpty) {
    stderr.writeln('Set OPENROUTER_API_KEY first.');
    return 1;
  }
  final client = http.Client();
  final transcribers = [
    for (final model in args.multiOption('models'))
      OpenRouterTranscriber(apiKey: () async => key, client: client, model: model),
  ];

  final results = {for (final t in transcribers) t.model: <_Result>[]};
  final tmp = await Directory.systemTemp.createTemp('stt_probe');
  try {
    for (final (i, clip) in args.rest.indexed) {
      final wav = await _toWav(clip, '${tmp.path}/$i.wav');
      if (wav == null) continue;
      final seconds = wav.length / _wavBytesPerSecond;
      stdout.writeln('\n$clip  (${seconds.toStringAsFixed(1)} s)');
      final heard = await Future.wait([for (final t in transcribers) _timed(t, wav)]);
      for (final (j, r) in heard.indexed) {
        final model = transcribers[j].model;
        results[model]!.add(r);
        stdout
          ..writeln('  $model  ${r.latency.inMilliseconds} ms  ${_usd(r.cost)}')
          ..writeln('    ${r.line}');
      }
    }
  } finally {
    client.close();
    await tmp.delete(recursive: true);
  }

  stdout.writeln('\nPer model');
  for (final MapEntry(key: model, value: runs) in results.entries) {
    final ok = runs.where((r) => r.error == null).toList();
    final ms = ok.map((r) => r.latency.inMilliseconds).toList()..sort();
    final cost = ok.fold<double>(0, (sum, r) => sum + (r.cost ?? 0));
    stdout.writeln(
      '  $model  ${ok.length}/${runs.length} ok'
      '${ms.isEmpty ? '' : '  median ${ms[ms.length ~/ 2]} ms'}'
      '  ${_usd(cost)} total',
    );
  }
  return 0;
}

Future<Uint8List?> _toWav(String clip, String out) async {
  final ffmpeg = await Process.run('ffmpeg', [
    '-v', 'error', '-y', '-i', clip, //
    '-ac', '1', '-ar', '16000', '-c:a', 'pcm_s16le', out,
  ]);
  if (ffmpeg.exitCode != 0) {
    stderr.writeln('$clip: ffmpeg failed — ${(ffmpeg.stderr as String).trim()}');
    return null;
  }
  return File(out).readAsBytes();
}

Future<_Result> _timed(Transcriber transcriber, Uint8List wav) async {
  final watch = Stopwatch()..start();
  try {
    final heard = await transcriber.transcribe(wav);
    return _Result(watch.elapsed, text: heard.text, cost: heard.cost);
  } on LlmException catch (e) {
    return _Result(watch.elapsed, error: '$e');
  }
}

String _usd(double? cost) => cost == null ? 'cost n/a' : '\$${cost.toStringAsFixed(6)}';

class _Result {
  _Result(this.latency, {this.text = '', this.cost, this.error});

  final Duration latency;
  final String text;
  final double? cost;
  final String? error;

  String get line => error ?? (text.isEmpty ? '(empty transcript)' : text);
}
