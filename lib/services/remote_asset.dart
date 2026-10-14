import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

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
    final install = RemoteInstall._(
      RemoteProgress(
        phase: hash == null
            ? RemotePhase.fetchingVersion
            : RemotePhase.downloading,
      ),
    );

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

  /// Fetches [url], reporting download progress through [onProgress].
  /// Throws [HttpException] on a non-200.
  static Future<Uint8List> _download(
    http.Client client,
    String url, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final resp = await client.send(http.Request('GET', Uri.parse(url)));
    if (resp.statusCode != 200) {
      throw HttpException('$url: HTTP ${resp.statusCode}');
    }
    final total = resp.contentLength;
    final builder = BytesBuilder(copy: false);
    var received = 0;
    await for (final chunk in resp.stream) {
      builder.add(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    return builder.takeBytes();
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
