import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Wrapper around `flutter_tts` configured for Japanese pronunciation.
///
/// Initialisation is lazy — the first [speak] call configures the
/// engine, every subsequent call just queues an utterance. All calls
/// are guarded with try/catch so a missing engine (e.g. desktop
/// without TTS, widget tests without platform channels) degrades to a
/// silent no-op rather than crashing the host screen.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  FlutterTts? _engine;
  bool _configured = false;

  Future<void> _ensureReady() async {
    if (_configured) return;
    try {
      final engine = FlutterTts();
      await engine.setLanguage('ja-JP');
      await engine.setSpeechRate(0.45);
      await engine.setPitch(1.0);
      _engine = engine;
      _configured = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TtsService: failed to initialise: $e');
      }
    }
  }

  /// Speaks [text] with the configured Japanese voice. Best-effort —
  /// errors are swallowed so the calling UI stays responsive.
  Future<void> speak(String text) async {
    await _ensureReady();
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.stop();
      await engine.speak(text);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('TtsService: failed to speak "$text": $e');
      }
    }
  }
}
