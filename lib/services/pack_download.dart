import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../db/repository.dart';
import 'remote_asset.dart';

const _manifestUrl = '$kIunaDataBase/packs.json';

/// One entry from the remote `packs.json` catalogue. This is metadata
/// only — enough to render the list and credit the source before
/// anything is downloaded.
class PackListing {
  const PackListing({
    required this.name,
    required this.label,
    required this.file,
    required this.version,
    this.description = '',
    this.cards = 0,
    this.sourceTitle,
    this.sourceUrl,
    this.sourceAuthor,
    this.license,
  });

  final String name;
  final String label;

  /// File name within the data repo, e.g. `packs/science.json.gz`.
  final String file;

  /// Truncated sha256 of the gzipped payload; doubles as the version.
  final String version;

  final String description;
  final int cards;
  final String? sourceTitle;
  final String? sourceUrl;
  final String? sourceAuthor;
  final String? license;

  String get url => '$kIunaDataBase/$file';

  static PackListing fromJson(Map<String, dynamic> j) {
    final source = j['source'] as Map<String, dynamic>?;
    return PackListing(
      name: j['pack'] as String,
      label: j['label'] as String? ?? j['pack'] as String,
      file: j['file'] as String,
      version: j['version'] as String,
      description: j['description'] as String? ?? '',
      cards: j['cards'] as int? ?? 0,
      sourceTitle: source?['title'] as String?,
      sourceUrl: source?['url'] as String?,
      sourceAuthor: source?['author'] as String?,
      license: source?['license'] as String?,
    );
  }
}

/// Fetches themed card packs from the public `Raffaelbdl/iuna-data`
/// repo and hands their payload to [IunaRepository.applyPack].
///
/// Packs are deliberately not bundled in the APK: publishing one is a
/// push to the data repo, not an app release, and the download is a
/// transient payload rather than a file that lives on disk — once
/// applied, the cards are ordinary rows and a Drive restore carries
/// them like any other.
class PackDownload {
  PackDownload._();

  /// The remote catalogue, or an empty list if unreachable. Never
  /// throws — a missing network shouldn't break the settings screen.
  static Future<List<PackListing>> catalogue({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final resp = await c.get(Uri.parse(_manifestUrl));
      if (resp.statusCode != 200) return const [];
      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      final packs = (decoded is Map<String, dynamic>)
          ? decoded['packs'] as List<dynamic>? ?? const []
          : decoded as List<dynamic>;
      return [
        for (final p in packs)
          PackListing.fromJson(p as Map<String, dynamic>),
      ];
    } catch (_) {
      return const [];
    } finally {
      if (client == null) c.close();
    }
  }

  /// Installs in progress, by pack name.
  static Map<String, RemoteInstall> get running => Map.unmodifiable(_running);
  static final Map<String, RemoteInstall> _running = {};

  /// Downloads [listing], verifies it against the manifest hash,
  /// decompresses it and applies it to [repo] — or joins the install of
  /// that pack already running.
  static RemoteInstall install(
    PackListing listing,
    IunaRepository repo, {
    http.Client? client,
  }) {
    return _running[listing.name] ??= RemoteAsset.install<Map<String, dynamic>>(
      url: listing.url,
      hash: listing.version,
      reportsApplying: true,
      client: client,
      decode: _decodePayload,
      apply: (payload, version) => repo.applyPack(payload, version: version),
      onEnd: () => _running.remove(listing.name),
    );
  }
}

Map<String, dynamic> _decodePayload(Uint8List raw) =>
    jsonDecode(utf8.decode(raw)) as Map<String, dynamic>;
