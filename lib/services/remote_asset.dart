import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/deck_rules.dart';

/// Everything Iuna downloads lives in the public `Raffaelbdl/iuna-data`
/// repo and is served over `raw.githubusercontent.com`.
const String kIunaDataBase =
    'https://raw.githubusercontent.com/Raffaelbdl/iuna-data/main';

enum RemotePhase {
  fetchingVersion,
  downloading,
  verifying,
  applying,
  done,
  failed,
}

class RemoteProgress {
  const RemoteProgress({
    required this.phase,
    this.bytesReceived = 0,
    this.bytesTotal,
    this.error,
  });

  final RemotePhase phase;
  final int bytesReceived;
  final int? bytesTotal;
  final String? error;

  double? get fraction {
    final total = bytesTotal;
    if (total == null || total <= 0) return null;
    return (bytesReceived / total).clamp(0.0, 1.0);
  }
}

/// One running download. It belongs to the service that started it, not
/// to a screen: leaving Settings mid-download neither aborts it nor lets
/// a second one start over it, and a section built later picks its
/// progress back up.
class RemoteInstall extends ValueNotifier<RemoteProgress> {
  RemoteInstall._(super.value);

  final Completer<String?> _outcome = Completer<String?>();

  /// Completes once the install ends: null on success, else why it
  /// failed. Never throws.
  Future<String?> get result => _outcome.future;
}

/// Shared download pipeline: stream the body with progress, then check
/// it against the expected hash, gunzip it and [decode] it in one hop
/// off the UI isolate, so the payload crosses an isolate boundary once.
///
/// The dictionary sidecar and card packs both fetch through [install];
/// the sidecar's [decode] writes the database to disk, a pack's parses
/// the JSON.
class RemoteAsset {
  RemoteAsset._();

  /// Downloads [url], verifies it against [hash] (or the one [fetchHash]
  /// returns, reported as `fetchingVersion`), runs [decode] on the
  /// gunzipped bytes in a background isolate, and passes its result to
  /// [apply], announced as `applying` when [reportsApplying]. [decode]
  /// must be sendable to an isolate: a top-level function, or a closure
  /// over plain values only. [onEnd] runs when it finishes either way.
  static RemoteInstall install<R>({
    required String url,
    String? hash,
    Future<String> Function(http.Client client)? fetchHash,
    required FutureOr<R Function(Uint8List raw)> decode,
    required Future<void> Function(R decoded, String hash) apply,
    bool reportsApplying = false,
    http.Client? client,
    void Function()? onEnd,
  }) {
    assert((hash == null) != (fetchHash == null));
    return _run(
      first: hash == null
          ? RemotePhase.fetchingVersion
          : RemotePhase.downloading,
      client: client,
      onEnd: onEnd,
      body: (c, report) async {
        final decodeFn = await decode;
        final expected = hash ?? await fetchHash!(c);

        report(RemotePhase.downloading);
        final gz = await _download(
          c,
          url,
          onProgress: (received, total) =>
              report(RemotePhase.downloading, received, total),
        );

        report(RemotePhase.verifying, gz.length, gz.length);
        final decoded = await _verifyAndDecode(gz, expected, decodeFn);

        if (reportsApplying) report(RemotePhase.applying);
        await apply(decoded, expected);
      },
    );
  }

  /// Streams [url] to [path] through `<path>.part`, renamed into place
  /// once its full hex [sha256Hex] matches, then runs [apply]. Unlike
  /// [install] the body is stored as is and never held in memory whole.
  static RemoteInstall downloadFile({
    required String url,
    required String path,
    required String sha256Hex,
    required Future<void> Function() apply,
    http.Client? client,
    void Function()? onEnd,
  }) {
    return _run(
      first: RemotePhase.downloading,
      client: client,
      onEnd: onEnd,
      body: (c, report) async {
        final part = File('$path.part');
        await part.parent.create(recursive: true);
        final sink = part.openWrite();
        final digest = _DigestSink();
        final hasher = sha256.startChunkedConversion(digest);
        try {
          try {
            await _stream(
              c,
              url,
              onChunk: (chunk) {
                sink.add(chunk);
                hasher.add(chunk);
              },
              onProgress: (received, total) =>
                  report(RemotePhase.downloading, received, total),
            );
          } finally {
            await sink.close();
          }
          hasher.close();

          report(RemotePhase.verifying);
          final actual = digest.value.toString();
          if (actual != sha256Hex.toLowerCase()) {
            throw StateError(
              'integrity check failed: expected $sha256Hex, got $actual',
            );
          }
        } catch (_) {
          if (await part.exists()) await part.delete();
          rethrow;
        }
        await part.rename(path);
        await apply();
      },
    );
  }

  static RemoteInstall _run({
    required RemotePhase first,
    required Future<void> Function(
      http.Client client,
      void Function(RemotePhase phase, [int received, int? total]) report,
    ) body,
    http.Client? client,
    void Function()? onEnd,
  }) {
    final install = RemoteInstall._(RemoteProgress(phase: first));

    void report(RemotePhase phase, [int received = 0, int? total]) {
      install.value = RemoteProgress(
        phase: phase,
        bytesReceived: received,
        bytesTotal: total,
      );
    }

    Future<void> run() async {
      final c = client ?? http.Client();
      try {
        await body(c, report);
        report(RemotePhase.done);
        install._outcome.complete(null);
      } catch (e) {
        install.value = RemoteProgress(
          phase: RemotePhase.failed,
          error: e.toString(),
        );
        install._outcome.complete(e.toString());
      } finally {
        if (client == null) c.close();
        onEnd?.call();
      }
    }

    run();
    return install;
  }

  static Future<Uint8List> _download(
    http.Client client,
    String url, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final builder = BytesBuilder(copy: false);
    await _stream(client, url, onChunk: builder.add, onProgress: onProgress);
    return builder.takeBytes();
  }

  /// GETs [url] and feeds each chunk to [onChunk], reporting progress
  /// through [onProgress] once per whole percent (per 256 KB when the
  /// length is unknown) rather than per chunk. Throws [HttpException] on
  /// a non-200.
  static Future<void> _stream(
    http.Client client,
    String url, {
    required void Function(List<int> chunk) onChunk,
    void Function(int received, int? total)? onProgress,
  }) async {
    final resp = await client.send(http.Request('GET', Uri.parse(url)));
    if (resp.statusCode != 200) {
      throw HttpException('$url: HTTP ${resp.statusCode}');
    }
    final total = resp.contentLength;
    var received = 0;
    var lastStep = -1;
    await for (final chunk in resp.stream) {
      onChunk(chunk);
      received += chunk.length;
      final step = total != null && total > 0
          ? received * 100 ~/ total
          : received >> 18;
      if (step != lastStep) {
        lastStep = step;
        onProgress?.call(received, total);
      }
    }
  }

  // Static, so the isolate closure captures only these three values.
  static Future<R> _verifyAndDecode<R>(
    Uint8List gz,
    String expected,
    R Function(Uint8List raw) decode,
  ) => Isolate.run(() {
    final actual = truncatedSha256(gz);
    if (actual != expected) {
      throw StateError(
        'integrity check failed: expected $expected, got $actual',
      );
    }
    final raw = gzip.decode(gz);
    return decode(raw is Uint8List ? raw : Uint8List.fromList(raw));
  });
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
