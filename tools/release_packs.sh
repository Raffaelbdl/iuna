#!/usr/bin/env bash
# Release card packs to Raffaelbdl/iuna-data via plain git.
#
# Publishes `packs/dist/` into `packs/` on `main`, alongside the JMdict
# sidecar at the repo root. The app fetches through
# raw.githubusercontent.com — no GitHub Releases, no `gh` CLI, no token.
#
# Usage:
#   dart run tools/build_science_pack.dart --apkg <deck>.apkg   # sources
#   dart run tools/package_packs.dart                           # dist/
#   tools/release_packs.sh
#
# Publishing a pack is a push to the data repo, not an app release —
# that's the whole point of packs being downloaded rather than bundled.
#
# Sources for the app:
#   https://raw.githubusercontent.com/Raffaelbdl/iuna-data/main/packs.json
#   https://raw.githubusercontent.com/Raffaelbdl/iuna-data/main/packs/<name>.json.gz

set -euo pipefail

REMOTE=git@github.com:Raffaelbdl/iuna-data.git
DIST=packs/dist

if [[ ! -f "$DIST/packs.json" ]]; then
  echo "missing: $DIST/packs.json" >&2
  echo "run first: dart run tools/package_packs.dart" >&2
  exit 1
fi

WORK=$(mktemp -d)
trap "rm -rf '$WORK'" EXIT

echo "Cloning $REMOTE..."
if ! git clone --depth 1 "$REMOTE" "$WORK" 2>&1; then
  echo "(empty repo — initialising)"
  git -C "$WORK" init -q -b main
  git -C "$WORK" remote add origin "$REMOTE"
fi

# The catalogue sits at the repo root so its URL is stable; the
# payloads live under packs/ exactly as `file` in the catalogue says.
mkdir -p "$WORK/packs"
cp "$DIST/packs.json" "$WORK/packs.json"
for gz in "$DIST"/*.json.gz; do
  cp "$gz" "$WORK/packs/$(basename "$gz")"
done

git -C "$WORK" add packs.json packs

if git -C "$WORK" diff --cached --quiet; then
  echo "no changes vs remote main — nothing to release."
  exit 0
fi

COUNT=$(ls -1 "$DIST"/*.json.gz | wc -l | tr -d ' ')
git -C "$WORK" commit -m "packs: $COUNT pack(s)"
git -C "$WORK" branch -M main
git -C "$WORK" push -u origin main

echo
echo "Released $COUNT pack(s) to $REMOTE on main."
echo "App URLs (raw.githubusercontent.com is cached ~5 min):"
echo "  https://raw.githubusercontent.com/Raffaelbdl/iuna-data/main/packs.json"
