# Architecture

Iuna is a Flutter app with no server of its own. Everything lives in two
SQLite files in the app's documents directory:

- `iuna.sqlite` — the deck: cards, what you own, scheduling, stats.
- `learn.sqlite` — the AI tutor's courses and chats.

They never reference each other and back up independently. Optional
network use: card packs and the dictionary are downloaded from a public
data repository, backups go to the user's own Google Drive, and the tutor
talks to OpenRouter with the user's own key.

## The deck database (`lib/db/`, Drift, schema v7)

```text
cards         id, kanji, kana, furigana?, meaning (first-sense headline),
              rarity, jlpt_level?, audio_path?, image_path?,
              source (seed|user), pack? (themed-pack tag).
              UNIQUE(kanji, kana).
card_senses   card_id, ordinal (1..N), pos (CSV), gloss (CSV),
              definition?. UNIQUE(card_id, ordinal); ordered by ordinal.
examples      id, sentence, source_title?
card_examples (card_id, example_id).
user_cards    PK card_id; level, ease (2.0), interval_minutes,
              last_reviewed?, next_due, obtained_at, is_new, fail_count,
              suspended. A row here means "owned".
review_log    one row per graded review (kind, correct, duration, the
              interval before it, rarity).
daily_stats   one wide row per logical day: totals per rarity.
wishlist      cards the learner asked to see sooner.
packs         one row per installed card pack: label, credits, version
              (sha256 prefix of the payload), card_count.
meta          K/V settings and gates (last_booster_date, last_seen_ts,
              reset_hour, boosters_per_day, draw filters, streak, …).
```

`lib/db/database.dart` is the authoritative shape and holds every
migration (v1 → v7). The bundled `assets/db/seed.sqlite` (26.7k cards
built from JMdict) is copied in on first open; `onCreate` patches in the
columns added since the seed was built.

- `lib/core/deck_rules.dart` — pure Dart, shared with `tools/`: `Rarity`,
  `ReviewKind`, `classifyReview`, the logical day (`logicalDayKey`,
  `logicalDayStart`, calendar-safe `shiftDayKey`), `truncatedSha256`.
- `lib/db/repository.dart` — `IunaRepository`, every deck read and write.
- `lib/db/repository_stats.dart` — the stats queries, aggregated in SQL
  (`reviewBreakdown`, `retentionCurve`, `dailyActivity`, `streakStats`, …).
- `lib/db/booster_draw.dart` — the weighted booster sampler.
- `lib/db/sqlite_open.dart` — opening a documents database (including the
  pending-restore swap), `documentsFile`, `SnapshotSpec` (what a valid
  snapshot of each database looks like) and `vacuumInto`.
- `lib/db/meta_store.dart` — K/V helpers shared by both repositories.

### Logical days

A day rolls over at `reset_hour` (midnight by default, 0..23 in
Settings). Day keys
are `YYYY-MM-DD` strings of the logical day; stepping between them goes
through `shiftDayKey`, which does calendar arithmetic so DST changes never
skip or repeat a day.

### Boosters

`claimAllAvailableBoosters` draws every pack the daily quota allows
(`boosters_per_day`, 1..5) in one transaction. `last_seen_ts` guards
against clock rewinds: if the wall clock is earlier than the stored
timestamp, the stored one wins, so moving the clock back never unlocks a
pack.

A pack holds ten unseen cards (`kDefaultPackSize`). The pool is filtered
in SQL (unowned, and optionally "JLPT only" or one themed pack —
wishlisted cards are exempt from both). Each slot picks a rarity tier by
`kBoosterRarityWeights`, then a card; with probability
`kWishlistDrawBias` (0.3) it takes a wishlisted card instead. During the reveal a card can be suspended and swapped in place
(`suspendAndReplace`).

### Spaced repetition (`lib/services/scheduler.dart`)

Binary-grade SM-2:

- **Correct:** 1 day, then 3 days, then interval × ease; ease + 0.1
  (max 3.0), level + 1.
- **Wrong:** interval × 0.5 (min 10 min), ease − 0.2 (min 1.3),
  level − 1 (min 0).

Each review is logged with its kind (learn, review, relearn) derived from
the interval before it, which feeds the stats screen.

### Rarity

Rarity is decided when the seed is built (`tools/dict_importer.dart`,
`rarityFor`), in this order:

1. JMdict priority tags (`ke_pri` / `re_pri`).
2. JLPT level.
3. Frequency rank: < 2000 Common, < 5000 Rare, < 9000 SR, < 14000 SSR,
   else UR.
4. jmdict-simplified's `common` flag.
5. Otherwise UR.

## Downloads (`lib/services/`)

Both downloadable assets live in the public `iuna-data` repository and
are fetched from `raw.githubusercontent.com` (`kIunaDataBase` in
`remote_asset.dart`).

`RemoteAsset.install` is the shared pipeline:

1. Stream the body, reporting progress.
2. Check it against the expected truncated sha256, gunzip it and decode
   it in one `Isolate.run`.
3. Apply the result.

The service that starts an install owns it as a `RemoteInstall`, a
`ValueNotifier<RemoteProgress>` with a `result` future. Settings only
listens, so leaving the screen never aborts an install, and coming back
re-attaches to it.

- **Dictionary** (`dict_download.dart`) — a ~216k-entry JMdict lookup,
  ~17 MB gzipped, ~45 MB on disk. It is written to `jmdict.sqlite.tmp`
  and renamed into place, then a version marker is written. When
  installed, Collection shows "Add card" (`add_card_screen.dart`,
  searching through `lib/db/jmdict_lookup.dart`). Adding a card writes a
  `cards` row and wishlists it, so the booster reveal stays the only way
  to own a card.
- **Card packs** (`pack_download.dart`) — themed sets listed in a
  `packs.json` catalogue. See *Card packs* below.

## Card packs

A pack is a versioned JSON document (`lib/core/pack_format.dart`:
`kPackFormatVersion`, `PackDocument.parse`, `PackCard.toJson`). The
format is deliberately *not* a mirror of the schema: a pack published
today must keep importing after any number of schema bumps. So
`IunaRepository.applyPack` maps the parsed document onto whatever the
tables currently look like, and packs are never re-published to follow a
schema change. Credits travel inside the payload and land in the `packs`
table.

Applying a pack is additive only. A headword the deck already has keeps
its id, senses and scheduling and just gains the pack tag, so
re-applying an updated pack can't duplicate cards or reset progress.
There is no removal; the "Themed pack only" draw filter is how a learner
narrows to, or away from, a pack.

Building and publishing a pack:

```bash
dart run tools/build_science_pack.dart --apkg <deck>.apkg \
  [--jmdict <uncompressed sidecar>]   # → packs/science.json (committed)
dart run tools/package_packs.dart     # → packs/dist/*.json.gz + packs.json
```

`packs/*.json` is committed as the reviewable record of what's
published. A pack's `version` is the truncated sha256 of its gzipped
payload; it is both the integrity check and the update trigger.

## Drive backup (`lib/services/drive_*.dart`)

Backup is opt-in and goes to the user's own Drive `appDataFolder`, a
hidden per-app folder, using only the `drive.appdata` scope.

- `DriveAuth` wraps `google_sign_in`.
- `DriveSync` uploads, lists, restores and prunes. Each database is a
  `DriveSnapshotSource`; its snapshot is a `VACUUM INTO` copy in the temp
  directory, so the live file is never read mid-write.
- Each family keeps its own `<prefix>yyyyMMdd-HHmmss.sqlite` names (the
  library as `iuna-…`, courses as `iuna-learn-…`) and its 7 newest
  snapshots. Courses are uploaded only when they changed.
- Concurrent backups (pull-to-refresh on Home plus "Back up now" in
  Settings) share one in-flight run.

A restore downloads the snapshot as a `.pending` file next to the live
database, checks it against the database's `SnapshotSpec`, and swaps it
in on the next launch. "Restore from file" in Settings stages a local
`.sqlite` the same way.

## The Learn tab (`lib/learn/`)

An AI tutor, Kuma-sensei, that runs Japanese courses by calling OpenRouter
directly with the learner's key. The key and model live in the Android
Keystore (`flutter_secure_storage`), never in either database. The tab
appears only while a key is saved.

### `learn.sqlite` (schema v3)

```text
courses        title, goal, state_markdown (the tutor's memory).
chapters       course_id, key, ordinal, title, summary, status
               (locked|unlocked|passed), doc (theory: append-only,
               frozen once passed), dropped.
chat_sessions  per course: 'main' (the room) and 'ch-<key>' (lessons);
               summary (after compaction).
messages       role, content, tool calls, archived, kind (kickoff,
               wrap_up), attachments (base64 photos, JSON).
learn_meta     updated_at, last_drive_backup_ts, preferences.
usage_log      kind (chat|ask|compact|dictation), model, tokens, cost.
```

### Conversation loop

`ChatController` (`agent/chat_controller.dart`) streams a completion, runs
the tools it asks for, and repeats until the reply ends. Streamed text
goes to a `ValueNotifier<String>`, so only the bubble being written
rebuilds. On reopen, a tool call cut off by an app kill is closed with an
error result, and an unanswered turn resumes.

**Tools** (`agent/tools.dart`). Each `ChatTool` carries its schema, its
running label, its history entry and its crash result, so neither the
loop nor the chat view switches on tool names.

| Tool | File | What it does |
|---|---|---|
| `course_plan`, `course_write`, `course_pass`, `save_state`, `save_preference` | `tutor_tools.dart` | Plan chapters only in the room; write theory only in its own lesson; statuses are derived. |
| `ask_quiz` | `ask_quiz_tool.dart` | A batch quiz card. |
| `bookmark_words` | `bookmark_tool.dart` | Puts words on the deck's wishlist through `DeckBookmarks`; uses the dictionary for words the deck lacks; leaves owned cards alone. |

**Prompt.** The static part comes first so provider prefix caching hits:
persona, harness notes, the multiple-choice contract, the deck and photo
rules, and three teaching skills from `assets/learn/`. Then the course
context. A tutor message that ends in a ```` ```choices ```` block becomes
answer buttons.

**Compaction** (`agent/compaction.dart`). Past about 80k characters, a
session is summarised into `chat_sessions.summary`. Archived messages stay
visible to the learner.

**Ask.** Each message from the chat bar on the Learn hub opens a
throwaway in-memory chat. Its only tool is `bookmark_words`.

### Photos and dictation

- **Photos** (`photo/`). Downscaled to 1280 px at quality 80 and stored
  as base64 inside the message row, so backups carry them. They are
  decoded only for display, at display size. Compaction charges each
  photo a flat `kPhotoWireChars`. A session whose live history holds a
  photo goes to `kPhotoFallbackModel` unless the learner's model reads
  images; `VisionModels` asks OpenRouter's `/models/<id>/endpoints`.
- **Dictation** (`voice/`). Hold the mic to record 16 kHz mono WAV.
  Slide left to cancel; slide up to lock for hands-free recording. The
  clip is transcribed through OpenRouter's `/audio/transcriptions`
  (MAI-Transcribe 2, picked with `tools/stt_probe.dart`) and only the
  text is sent. The audio is never stored.

The cost OpenRouter reports for each call is logged in `usage_log` and
shown only under Settings → AI tutor.

## UI (`lib/screens/`, `lib/widgets/`, `lib/theme/`)

**Navigation**

- `app_nav.dart` routes the bottom-nav tabs.
- `today_flow.dart` decides what "today" opens: a pack, else reviews,
  else the day's tally.

**Screens**

- Home: `home_screen.dart`.
- Boosters: `pack_intro_screen.dart`, then `booster_reveal_screen.dart`.
- Reviews: `review_screen.dart`, then `review_done_screen.dart`.
- Cards: `collection_screen.dart`, `card_detail_screen.dart`,
  `add_card_screen.dart`.
- Settings: `settings_screen.dart`, with sections under `settings/`.
- Stats: `stats_screen.dart`, with `part` files under `stats/`.

**Shared widgets**

- Cards: `VocabCard` and `RarityChip` (`vocab_card.dart`), `SenseRow`.
- Buttons and bars: `IunaIconButton` and `IunaTopBar`, `IunaCtaButton`,
  `IunaSearchField`, `ProgressDots`.
- Section titles: `IunaSectionHeader` and `IunaEyebrow`.
- Dialogs and feedback: `showConfirmDialog`, `showTextInputDialog`,
  `showSnack`.
- Background and mascot: `HexBg` (drifting hexagon bokeh), `KumaMascot`.

`lib/theme/iuna_theme.dart` holds the palette, radii, shadows,
`paperPanelDecoration`, `ctaDecoration` and `ghostPillDecoration`.

## Tools (`tools/`)

| Tool | What it does |
|---|---|
| `build_dict.dart` + `dict_importer.dart` + `seed_schema.dart` | Build the seed from JMdict, with JLPT and frequency overlays. |
| `build_jmdict_sidecar.dart` | Build the downloadable dictionary and its `jmdict.LICENSE.txt`. |
| `build_science_pack.dart` + `anki/` | Turn an Anki deck into `packs/science.json`. |
| `package_packs.dart` + `pack_format.dart` | Gzip the packs and write the catalogue. |
| `release_sidecar.sh`, `release_packs.sh` | Push to the data repository (maintainer only). |
| `stt_probe.dart` | Compare transcription models on sample clips. |
| `build_launcher_icons.py` | Android launcher icons from the mascot (needs Pillow). |
| `setup_test_fonts.sh` | Link the fonts the golden tests need. |

The JMdict importer reads raw EDRDG XML or jmdict-simplified JSON,
choosing by file extension. For XML it stream-parses with a custom entity
mapping that keeps entity *names*, so `<pos>&v5k-s;</pos>` reads as
`v5k-s` rather than JMdict's prose expansion.
