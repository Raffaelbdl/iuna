# Iuna — agent notes

A gacha-style Japanese vocabulary app in Flutter: daily booster packs,
a rarity-tiered collection, spaced-repetition reviews and stats, plus an
optional Learn tab where Kuma-sensei, an on-device AI tutor, runs
courses against OpenRouter with the learner's own key. There is no Iuna
server. Two SQLite files hold everything: `iuna.sqlite`, the deck (Drift,
schema v7), and `learn.sqlite`, the tutor (schema v3).

Read before changing things:

- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): schemas, module layout,
  booster/SRS rules, card packs, downloads, Drive backup, the Learn tab.
- `CLAUDE.local.md` (gitignored, if present): machine-specific notes.

## Commands

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after schema edits
flutter analyze && dart analyze tools
flutter test                                               # goldens need tools/setup_test_fonts.sh
flutter test --update-goldens test/screenshots_test.dart   # after visual changes
```

## Rules

- Never hand-edit `*.g.dart`. Run codegen after any schema change.
- Schema changes bump `schemaVersion` and come with a real migration
  plus a test. No backwards-compat shims (pre-1.0).
- The card-pack wire format (`lib/core/pack_format.dart`) must survive
  schema bumps. Never re-publish packs to follow the schema.
- Applying a pack is additive only: an existing headword keeps its id,
  senses and scheduling. The booster reveal is the only path that mints
  owned cards (`user_cards`). Add card and the tutor only wishlist.
- `lib/core/` stays Flutter-free, because `tools/` import it.
- Comments only for a non-obvious *why*.
- Don't run `dart format` over existing files or directories. Format
  only files you create.
- Visual change → refresh the affected goldens, Read the PNGs, and
  commit them. Goldens are Skia, devices are Impeller. Never pair
  `MaskFilter.blur` with an advanced `BlendMode`, and check blur/blend
  changes on a device.
- Golden scenes must be deterministic. Pass `now` / seeds into the
  screen instead of reading the clock or `Random()`.
- New data sources get credited in NOTICE *and* Settings → Data sources.
- Keep the tutor Japanese-only (the personas decline anything else).
  Its cost shows only under Settings → AI tutor, never on Learn
  screens.

## Releasing (maintainer)

- **APK.** Bumping `version:` in `pubspec.yaml` and pushing to `main` is
  the release: `.github/workflows/release.yml` sees no `vX.Y.Z` tag for
  it yet, so it tags the commit, tests, builds a release-signed APK and
  publishes a GitHub Release. Pushes that don't change the version build
  nothing. Always bump the `+N` build number too, or Android refuses the
  upgrade. It needs the
  secrets `ANDROID_KEYSTORE_BASE64` (`base64 -w0
  android/upload-keystore.jks`), `ANDROID_STORE_PASSWORD`,
  `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`, and fails rather than
  fall back to the debug key. Keep the keystore backed up: losing it
  means existing installs can't upgrade.
- **Dictionary.** `dart run tools/build_jmdict_sidecar.dart`, then
  `tools/release_sidecar.sh` (pushes to iuna-data).
- **Card packs.** `dart run tools/build_science_pack.dart …`, then
  `dart run tools/package_packs.dart`, then `tools/release_packs.sh`.
- **Seed.** `dart run tools/build_dict.dart --jmdict
  tools/_cache/JMdict_e_examp.gz --tanos-dir tools/_cache/tanos --freq
  <frequency list>` (add `--limit 1000` for quick runs).

## Product decisions (don't re-propose)

- **No "Review now" button on card detail.** No per-card shortcut that
  sets `nextDue = now`.
- **No real deck-list screen.** Showing the upcoming deck spoils the
  reveal loop. `deck_list_preview` stays a static mockup golden only.
- **No EPUB parser or book tokenizer.** The wishlist covers it: a
  bookmarked word surfaces within a few packs (`kWishlistDrawBias` =
  0.3).
- **No pack removal.** The "Themed pack only" draw filter covers it.
- **Neutral collection vocabulary in user-facing text.** Say
  "Collection", "Show missing", "all cards". Never use another game's
  name for the collection, in UI strings or commit messages.
- **No canned course ideas or example questions in the Learn tab.**

## Roadmap

- Widget tests for Home and Collection (goldens only today).
- A mocked `flutter_tts` channel for TTS coverage.
- Direct tests for `examplesForCard` and the booster-date rollover.
- A rarity long-tail fix: some common cultural words land too rare
  (お守り → UR).
- Learn: mini-games on the hub, homework files, background memory
  review, deck-aware tutoring, a monthly cost cap.
