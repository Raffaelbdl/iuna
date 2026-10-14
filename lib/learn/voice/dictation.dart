import 'dart:typed_data';

import '../llm/transcriber.dart';

/// One hold of the mic: the recording as 16 kHz mono WAV, and the
/// loudness trace its waveform is drawn from.
class VoiceClip {
  const VoiceClip({required this.wav, required this.levels, required this.length});

  final Uint8List wav;

  /// 0..1, in the order [VoiceRecorder.levels] reported them.
  final List<double> levels;
  final Duration length;
}

abstract class VoiceRecorder {
  /// Asks for the microphone the first time; false once refused.
  Future<bool> hasPermission();

  /// Loudness while recording, 0..1, a few dozen times a second.
  Stream<double> get levels;

  Future<void> start();

  /// The recording as WAV, or null when nothing was captured.
  Future<Uint8List?> stop();

  /// Stops and throws the recording away.
  Future<void> cancel();
  Future<void> dispose();
}

/// Hold-to-speak in the Learn chats: record on the phone, transcribe
/// through OpenRouter, send only the text.
class Dictation {
  const Dictation({required this.recorder, required this.transcriber});

  /// One recorder per composer, made on its first press.
  final VoiceRecorder Function() recorder;
  final Transcriber transcriber;
}

/// A held-to-speak clip on its way to being the learner's message.
class PendingVoice {
  const PendingVoice(this.clip, {this.text, this.error, this.canRetry = false});

  final VoiceClip clip;

  /// What was heard, shown for a moment before it goes out.
  final String? text;

  /// Why it could not become text.
  final String? error;

  /// On an [error]: whether another try could help, which it cannot when
  /// nothing was heard.
  final bool canRetry;

  bool get transcribing => text == null && error == null;
}
