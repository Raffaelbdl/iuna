import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iuna/learn/llm/transcriber.dart';
import 'package:iuna/learn/voice/dictation.dart';
import 'package:iuna/learn/widgets/chat_composer.dart';

/// The composer's mic; a voice bubble shows a mic icon too.
final composerMic = find.descendant(
  of: find.byType(ChatComposer),
  matching: find.byIcon(Icons.mic_rounded),
);

/// Presses the composer's mic and lets the recording get going: its
/// clock starts on the frame after.
Future<TestGesture> holdMic(WidgetTester tester) async {
  final hold = await tester.startGesture(tester.getCenter(composerMic));
  await tester.pump();
  await tester.pump();
  return hold;
}

/// A microphone that hears whatever levels a test feeds it.
class FakeRecorder implements VoiceRecorder {
  FakeRecorder({this.permitted = true});

  bool permitted;
  bool recording = false;
  int cancels = 0;
  final _levels = StreamController<double>.broadcast();

  static final wav = Uint8List.fromList(const [0x52, 0x49, 0x46, 0x46]);

  void speak(Iterable<double> levels) {
    for (final l in levels) {
      _levels.add(l);
    }
  }

  @override
  Stream<double> get levels => _levels.stream;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> start() async => recording = true;

  @override
  Future<Uint8List?> stop() async {
    recording = false;
    return wav;
  }

  @override
  Future<void> cancel() async {
    recording = false;
    cancels++;
  }

  @override
  Future<void> dispose() async {}
}

/// Speech-like loudness: syllables rising and falling.
List<double> speechLevels(int n) => [
  for (var i = 0; i < n; i++) 0.12 + 0.8 * (math.sin(i * 0.9) * math.sin(i * 0.21)).abs(),
];

/// Answers each clip from a script: the transcript's text, an [Exception]
/// to fail with, or a [Completer] that holds the answer back.
class FakeTranscriber implements Transcriber {
  FakeTranscriber(this.script);

  final List<Object> script;
  final clips = <Uint8List>[];

  @override
  String get model => 'test/stt';

  @override
  Future<Transcript> transcribe(Uint8List wav) async {
    clips.add(wav);
    final next = script.removeAt(0);
    if (next is Exception) throw next;
    if (next is Completer<Transcript>) return next.future;
    return Transcript(next as String, cost: 0.0004);
  }
}
