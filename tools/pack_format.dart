// The writing side of the card-pack transfer format. The version and
// the reader live in `lib/core/pack_format.dart`, shared with the app.

import 'package:iuna/core/pack_format.dart';

/// Where the pack sources live in the repo, and where the publishable
/// artifacts are staged. Only `packs/*.json` is committed — `dist/` is
/// generated and gitignored, same arrangement as the JMdict sidecar.
const String kPacksDir = 'packs';
const String kPacksDistDir = 'packs/dist';

/// Path a pack's gzipped payload takes inside the `iuna-data` repo. The
/// app resolves it against `kIunaDataBase`.
String packFilePath(String name) => 'packs/$name.json.gz';

/// Builds the pack document. [cards] entries are already in wire shape.
Map<String, dynamic> packDocument({
  required String name,
  required String label,
  required String description,
  required List<Map<String, dynamic>> cards,
  String? sourceTitle,
  String? sourceUrl,
  String? sourceAuthor,
  String? license,
}) {
  // Absent attribution is omitted rather than written as null — an
  // unknown licence is not a licence.
  final source = <String, dynamic>{
    'title': ?sourceTitle,
    'url': ?sourceUrl,
    'author': ?sourceAuthor,
    'license': ?license,
  };
  return {
    'format': kPackFormatVersion,
    'pack': name,
    'label': label,
    'description': description,
    if (source.isNotEmpty) 'source': source,
    'cards': cards,
  };
}

/// Manifest entry for `packs.json`. [version] is the truncated sha256
/// of the gzipped payload — the app verifies against it and uses it to
/// decide whether an installed pack is stale.
Map<String, dynamic> manifestEntry(
  Map<String, dynamic> doc, {
  required String version,
}) {
  return {
    'pack': doc['pack'],
    'label': doc['label'],
    'description': doc['description'] ?? '',
    'file': packFilePath(doc['pack'] as String),
    'version': version,
    'cards': (doc['cards'] as List).length,
    if (doc['source'] != null) 'source': doc['source'],
  };
}
