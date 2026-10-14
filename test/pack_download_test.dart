// Network side of card packs: catalogue parsing, the sha256 gate, and
// the fact that a rejected download leaves the deck untouched.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:iuna/core/pack_format.dart';
import 'package:iuna/db/database.dart';
import 'package:iuna/db/repository.dart';
import 'package:iuna/services/pack_download.dart';
import 'package:iuna/services/remote_asset.dart';

const _manifestUrl = '$kIunaDataBase/packs.json';
const _packUrl = '$kIunaDataBase/packs/demo.json.gz';

final _payload = <String, dynamic>{
  'format': kPackFormatVersion,
  'pack': 'demo',
  'label': 'Demo Pack',
  'description': 'two cards',
  'source': {
    'title': 'Somebody Else\'s Deck',
    'url': 'https://example.invalid/deck',
    'license': 'CC-BY-SA 4.0',
  },
  'cards': [
    {
      'kanji': '素粒子',
      'kana': 'そりゅうし',
      'meaning': 'elementary particle',
      'rarity': 3,
      'senses': [
        {'ordinal': 1, 'gloss': 'elementary particle', 'pos': 'physics'}
      ],
    },
    {
      'kanji': '回折',
      'kana': 'かいせつ',
      'meaning': 'diffraction',
      'rarity': 4,
      'senses': [
        {'ordinal': 1, 'gloss': 'diffraction'}
      ],
    },
  ],
};

({Uint8List gz, String hash}) _gzPayload() {
  final gz = Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(_payload))));
  return (gz: gz, hash: truncatedSha256(gz));
}

String _manifest(String hash) => jsonEncode({
      'format': 1,
      'packs': [
        {
          'pack': 'demo',
          'label': 'Demo Pack',
          'description': 'two cards',
          'file': 'packs/demo.json.gz',
          'version': hash,
          'cards': 2,
          'source': _payload['source'],
        },
      ],
    });

/// Every progress value [install] reports, through to its end.
Future<List<RemoteProgress>> _events(RemoteInstall install) async {
  final events = [install.value];
  install.addListener(() => events.add(install.value));
  await install.result;
  return events;
}

void main() {
  late AppDatabase db;
  late IunaRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = IunaRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('catalogue parses the manifest, credits included', () async {
    final fixture = _gzPayload();
    final client = MockClient((req) async {
      expect(req.url.toString(), _manifestUrl);
      return http.Response(_manifest(fixture.hash), 200);
    });

    final listings = await PackDownload.catalogue(client: client);
    expect(listings, hasLength(1));
    final l = listings.single;
    expect(l.name, 'demo');
    expect(l.label, 'Demo Pack');
    expect(l.cards, 2);
    expect(l.version, fixture.hash);
    expect(l.url, _packUrl);
    expect(l.sourceTitle, "Somebody Else's Deck");
    expect(l.license, 'CC-BY-SA 4.0');
  });

  test('an unreachable catalogue is empty, not an error', () async {
    final client = MockClient((_) async => http.Response('nope', 404));
    expect(await PackDownload.catalogue(client: client), isEmpty);
  });

  test('install downloads, verifies and applies', () async {
    final fixture = _gzPayload();
    final client = MockClient((req) async {
      if (req.url.toString() == _manifestUrl) {
        return http.Response(_manifest(fixture.hash), 200);
      }
      return http.Response.bytes(fixture.gz, 200);
    });

    final listing =
        (await PackDownload.catalogue(client: client)).single;
    final install = PackDownload.install(listing, repo, client: client);
    final phases = [for (final p in await _events(install)) p.phase];

    expect(phases.last, RemotePhase.done);
    expect(phases, contains(RemotePhase.verifying));
    expect(phases, contains(RemotePhase.applying));

    final cards = await db.select(db.cards).get();
    expect(cards, hasLength(2));
    expect(cards.every((c) => c.pack == 'demo'), isTrue);

    final installed = (await repo.installedPacks()).single;
    expect(installed.version, fixture.hash);
    expect(installed.license, 'CC-BY-SA 4.0');
    expect(installed.sourceUrl, 'https://example.invalid/deck');
  });

  test('a corrupted payload is rejected and writes nothing', () async {
    final fixture = _gzPayload();
    final client = MockClient((req) async {
      if (req.url.toString() == _manifestUrl) {
        // Advertise a hash the payload can't possibly match.
        return http.Response(_manifest('0' * 16), 200);
      }
      return http.Response.bytes(fixture.gz, 200);
    });

    final listing = (await PackDownload.catalogue(client: client)).single;
    final events =
        await _events(PackDownload.install(listing, repo, client: client));

    expect(events.last.phase, RemotePhase.failed);
    expect(events.last.error, contains('integrity check failed'));
    expect(await db.select(db.cards).get(), isEmpty);
    expect(await repo.installedPacks(), isEmpty);
  });

  test('a pack draws alongside the rest of the deck once installed',
      () async {
    final fixture = _gzPayload();
    final client = MockClient((req) async {
      if (req.url.toString() == _manifestUrl) {
        return http.Response(_manifest(fixture.hash), 200);
      }
      return http.Response.bytes(fixture.gz, 200);
    });
    await db.into(db.cards).insert(CardsCompanion.insert(
          kanji: '猫',
          kana: 'ねこ',
          meaning: 'cat',
        ));

    final listing = (await PackDownload.catalogue(client: client)).single;
    await PackDownload.install(listing, repo, client: client).result;

    await repo.setBoosterPackFilter('demo');
    final claim = (await repo.claimAllAvailableBoosters()).single;
    expect(claim.cards, hasLength(2));
    expect(claim.cards.every((c) => c.pack == 'demo'), isTrue);
  });
}
