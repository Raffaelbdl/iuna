import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'dictation.dart';

/// The phone's microphone, through `record`. WAV because MAI-Transcribe
/// (Azure) takes WAV, MP3 or FLAC, not the AAC recorders usually write.
class MicRecorder implements VoiceRecorder {
  final _recorder = AudioRecorder();
  late final Future<String> _path = getTemporaryDirectory().then(
    (dir) => '${dir.path}/dictation.wav',
  );

  /// `record` shares one amplitude stream per recorder and closes it on
  /// [dispose].
  @override
  Stream<double> get levels =>
      _recorder.onAmplitudeChanged(const Duration(milliseconds: 50)).map((a) => _level(a.current));

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<void> start() async => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.wav,
      sampleRate: 16000,
      numChannels: 1,
      androidConfig: AndroidRecordConfig(audioSource: AndroidAudioSource.voiceRecognition),
    ),
    path: await _path,
  );

  @override
  Future<Uint8List?> stop() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final file = File(path);
    try {
      return await file.readAsBytes();
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> cancel() => _recorder.cancel();

  @override
  Future<void> dispose() => _recorder.dispose();
}

/// Speech sits roughly between -50 dBFS (quiet) and -10 (loud).
double _level(double dbfs) => ((dbfs + 50) / 40).clamp(0.0, 1.0);
