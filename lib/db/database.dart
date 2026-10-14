import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../core/deck_rules.dart';
import 'sqlite_open.dart';

export '../core/deck_rules.dart';

part 'database.g.dart';

enum CardSource { seed, user }

@DataClassName('CardRow')
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get kanji => text()();
  TextColumn get kana => text()();

  /// Positional furigana, e.g. `食[た]べる`. Optional.
  TextColumn get furigana => text().nullable()();

  /// Denormalized short headline used in lists / collection grid /
  /// review-card front. Typically the glosses of the first sense joined
  /// with `; ` (e.g. "to take; to pick up"). Full per-sense data lives
  /// in [CardSenses].
  TextColumn get meaning => text()();

  IntColumn get rarity =>
      intEnum<Rarity>().withDefault(Constant(Rarity.common.index))();

  /// JLPT level 1..5 (5 = N5 / easiest). Null for cards that don't map
  /// onto the JLPT scale (e.g. user-added words).
  IntColumn get jlptLevel => integer().nullable()();
  TextColumn get audioPath => text().nullable()();
  TextColumn get imagePath => text().nullable()();
  IntColumn get source =>
      intEnum<CardSource>().withDefault(Constant(CardSource.seed.index))();

  /// Name of the themed pack this card belongs to, e.g. `science`. Null
  /// for the general dictionary. Packs are downloaded and applied by
  /// `IunaRepository.applyPack`; the tag both drives the "pack only"
  /// booster filter and gives the stats screen something to chart
  /// progress against.
  TextColumn get pack => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {kanji, kana},
      ];
}

/// One JMdict-style sense per row. A card with multiple senses has
/// multiple rows here, ordered by [ordinal]. Each sense carries its own
/// POS list because senses of the same headword can disagree (e.g. 開く
/// is `v5k,vi` for "to open (intr.)" and `v5k,vt` for "to hold (event)").
@DataClassName('CardSenseRow')
class CardSenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();

  /// 1-based position of this sense within the dictionary entry.
  IntColumn get ordinal => integer()();

  /// POS / grammar tags for this sense, comma-separated (e.g. "v5r,vt").
  TextColumn get pos => text().withDefault(const Constant(''))();

  /// English glosses for this sense, comma-separated
  /// (e.g. "to take, to pick up, to grab"). At least one is required.
  TextColumn get gloss => text()();

  /// Optional longer prose explanation for this sense.
  TextColumn get definition => text().withDefault(const Constant(''))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {cardId, ordinal},
      ];
}

@DataClassName('ExampleRow')
class Examples extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sentence => text()();
  TextColumn get sourceTitle => text().nullable()();
}

@DataClassName('CardExampleRow')
class CardExamples extends Table {
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  IntColumn get exampleId =>
      integer().references(Examples, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {cardId, exampleId};
}

/// Per-user state for cards in the user's collection. Only owned cards
/// have rows here.
@DataClassName('UserCardRow')
class UserCards extends Table {
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  IntColumn get level => integer().withDefault(const Constant(0))();
  RealColumn get ease => real().withDefault(const Constant(2.0))();

  /// Current scheduling interval in minutes.
  IntColumn get intervalMinutes => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastReviewed => dateTime().nullable()();
  DateTimeColumn get nextDue => dateTime()();
  DateTimeColumn get obtainedAt => dateTime()();

  /// True until the card has been reviewed for the first time. Used by the
  /// review flow to trigger the booster-reveal animation.
  BoolColumn get isNew => boolean().withDefault(const Constant(true))();

  /// Lifetime count of wrong answers. Powers the "leeches" stat list.
  IntColumn get failCount => integer().withDefault(const Constant(0))();

  /// Cards the user has shelved. They stay in the collection and keep
  /// their scheduling state frozen, but never appear in the review
  /// queue. Toggled from review (info sheet), card detail, or the
  /// booster reveal — and reversed via the same surfaces.
  BoolColumn get suspended => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {cardId};
}

/// Generic key/value bag for app-level metadata: `last_booster_date`,
/// `last_seen_ts`, etc.
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// One row per installed card pack. Holds what the pack file said
/// about itself — label, description and the attribution its source
/// deck asks for — so the app can credit it without going back to the
/// network, plus the version it was installed at so updates can be
/// offered later. The cards themselves are ordinary `cards` rows tagged
/// with [Cards.pack].
@DataClassName('PackRow')
class Packs extends Table {
  TextColumn get name => text()();
  TextColumn get label => text()();
  TextColumn get description => text().withDefault(const Constant(''))();

  /// Attribution for the upstream deck. Absent fields stay null rather
  /// than being guessed at — an unknown licence is not "public domain".
  TextColumn get sourceTitle => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get sourceAuthor => text().nullable()();
  TextColumn get license => text().nullable()();

  /// Truncated sha256 of the pack file this row was installed from.
  TextColumn get version => text()();
  IntColumn get cardCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get installedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {name};
}

/// Cards the user has explicitly bookmarked for accelerated learning.
/// Unowned wishlisted cards get a heavy boost in the booster sampler;
/// owned wishlisted cards just sit here as a personal "important to
/// me" list (the entry has no effect once a card is in `user_cards`
/// because the sampler intersects with the unseen pool).
@DataClassName('WishlistRow')
class Wishlist extends Table {
  IntColumn get cardId =>
      integer().references(Cards, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get addedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {cardId};
}

/// One row per logical day, in `YYYY-MM-DD` form (resetHour-shifted to
/// match the rest of the app). The breakdown is wide-by-rarity rather
/// than long because rarity is a closed enum and every chart we draw
/// reads all five tiers at once. Overall daily totals are
/// `SUM(*_total) / SUM(*_correct)` — derived rather than stored, so the
/// breakdown can never drift from the totals.
@DataClassName('DailyStatRow')
class DailyStats extends Table {
  TextColumn get date => text()();

  IntColumn get cTotal => integer().withDefault(const Constant(0))();
  IntColumn get cCorrect => integer().withDefault(const Constant(0))();
  IntColumn get rTotal => integer().withDefault(const Constant(0))();
  IntColumn get rCorrect => integer().withDefault(const Constant(0))();
  IntColumn get srTotal => integer().withDefault(const Constant(0))();
  IntColumn get srCorrect => integer().withDefault(const Constant(0))();
  IntColumn get ssrTotal => integer().withDefault(const Constant(0))();
  IntColumn get ssrCorrect => integer().withDefault(const Constant(0))();
  IntColumn get urTotal => integer().withDefault(const Constant(0))();
  IntColumn get urCorrect => integer().withDefault(const Constant(0))();

  /// Cards reviewed for the very first time on this logical day.
  IntColumn get newCards => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {date};
}

/// Append-only per-review record. One row per swipe — feeds the
/// retention curve (accuracy bucketed by `prevIntervalMinutes`) and any
/// future "what was I doing on day X" forensic. Storage is ~30 bytes/row;
/// even at 200 reviews/day for a decade it stays under 30 MB.
@DataClassName('ReviewLogRow')
class ReviewLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get reviewedAt => dateTime()();

  /// Interval the card had *coming into* this review (minutes). 0 for
  /// the very first review of a card; subsequent rows record the gap
  /// since the previous review (in scheduler terms — not wall clock).
  IntColumn get prevIntervalMinutes => integer()();

  BoolColumn get correct => boolean()();

  /// Denormalised so the retention curve can be sliced per-rarity
  /// without joining cards. Stored as the [Rarity] enum index.
  IntColumn get rarity => integer()();

  /// Whether this answer was a learn-phase, review-phase, or relearn-
  /// phase event. Stored as the [ReviewKind] enum index. Defaults to
  /// `review.index` so legacy rows (pre-v5) read as plain reviews; the
  /// migration backfills 0 for the (very few) rows that already exist.
  IntColumn get kind =>
      intEnum<ReviewKind>().withDefault(Constant(ReviewKind.review.index))();

  /// Wall-clock time the user spent on this card, in milliseconds —
  /// from the moment the front was shown to the swipe. Null when not
  /// known (Anki imports without a `time` value, or a swipe that fell
  /// through before the timer started).
  IntColumn get durationMs => integer().nullable()();
}

@DriftDatabase(
  tables: [
    Cards,
    CardSenses,
    Examples,
    CardExamples,
    UserCards,
    Meta,
    Wishlist,
    DailyStats,
    ReviewLog,
    Packs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onCreate: (m) async {
          await m.createAll();
          // Pre-v4 seed assets ship with `user_cards` already populated
          // but missing the `fail_count` column. createAll() uses
          // `CREATE TABLE IF NOT EXISTS`, so it can't add the column on
          // its own — patch it in here, tolerating "duplicate column"
          // for genuinely-fresh installs. Same idempotent path used for
          // v5's review_log columns below.
          await _addColumnIfMissing(
            'user_cards',
            'fail_count',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addColumnIfMissing(
            'review_log',
            'kind',
            'INTEGER NOT NULL DEFAULT ${ReviewKind.review.index}',
          );
          await _addColumnIfMissing(
            'review_log',
            'duration_ms',
            'INTEGER',
          );
          await _addColumnIfMissing(
            'user_cards',
            'suspended',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _addColumnIfMissing('cards', 'pack', 'TEXT');
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(cardSenses);
            // Backfill: lift the legacy flat (pos, meaning, definition)
            // tuple into a single ordinal-1 sense per card.
            await customStatement('''
              INSERT INTO card_senses (card_id, ordinal, pos, gloss, definition)
              SELECT id, 1, pos, meaning, definition
              FROM cards
              WHERE meaning != ''
            ''');
            // SQLite 3.35+ supports DROP COLUMN; both columns are
            // unconstrained text, so this is a clean drop.
            await customStatement('ALTER TABLE cards DROP COLUMN pos');
            await customStatement(
              'ALTER TABLE cards DROP COLUMN definition',
            );
          }
          if (from < 3) {
            await m.createTable(wishlist);
          }
          if (from < 4) {
            await m.createTable(dailyStats);
            await m.createTable(reviewLog);
            await m.addColumn(userCards, userCards.failCount);
          }
          if (from < 5) {
            await m.addColumn(reviewLog, reviewLog.kind);
            await m.addColumn(reviewLog, reviewLog.durationMs);
          }
          if (from < 6) {
            await m.addColumn(userCards, userCards.suspended);
          }
          if (from < 7) {
            await m.addColumn(cards, cards.pack);
            await m.createTable(packs);
          }
        },
      );

  /// `ALTER TABLE ADD COLUMN` is not idempotent in SQLite — there's no
  /// `IF NOT EXISTS` flavour. Inspect the schema first so legacy seeds
  /// missing a column get patched, while fresh ones stay silent.
  Future<void> _addColumnIfMissing(
    String table,
    String column,
    String typeAndConstraints,
  ) async {
    final rows = await customSelect(
      'PRAGMA table_info($table)',
    ).get();
    final hasColumn = rows.any((r) => r.read<String>('name') == column);
    if (hasColumn) return;
    await customStatement(
      'ALTER TABLE $table ADD COLUMN $column $typeAndConstraints',
    );
  }
}

/// File name of the live database in the app documents directory.
const String kDbFileName = 'iuna.sqlite';

/// Side-car file written by the "Restore from file" flow. The next
/// `_openConnection()` call swaps it in over the live DB before opening,
/// then deletes the side-car. Pending-then-apply avoids closing /
/// reopening Drift while the UI still holds references to it.
const String kPendingRestoreFileName = 'iuna.sqlite.pending';

LazyDatabase _openConnection() => openDocumentsDatabase(
      kDbFileName,
      pendingFileName: kPendingRestoreFileName,
      seed: _copySeedToFile,
    );

Future<void> _copySeedToFile(File target) async {
  await target.parent.create(recursive: true);
  try {
    final bytes = await rootBundle.load('assets/db/seed.sqlite');
    await target.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      flush: true,
    );
  } catch (_) {
    // No bundled seed yet — start with an empty file. Drift will create
    // the schema on first open.
  }
}
