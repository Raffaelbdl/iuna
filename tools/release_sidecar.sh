#!/usr/bin/env bash
# Release the JMdict sidecar to Raffaelbdl/iuna-data via plain git.
#
# Hosts the three artifacts at the repo root on `main`. The app fetches
# them through raw.githubusercontent.com — no GitHub Releases, no `gh`
# CLI, no API token. Anyone with push access to the repo can run this.
#
# Usage:
#   tools/release_sidecar.sh
#
# Requires:
#   - artifacts in assets/db/jmdict.* (run build_jmdict_sidecar.dart first)
#   - SSH access to git@github.com:Raffaelbdl/iuna-data.git
#     (HTTPS works too — change REMOTE below)
#
# Sources for the app:
#   https://raw.githubusercontent.com/Raffaelbdl/iuna-data/main/jmdict.version
#   https://raw.githubusercontent.com/Raffaelbdl/iuna-data/main/jmdict.sqlite.gz
#   https://raw.githubusercontent.com/Raffaelbdl/iuna-data/main/jmdict.LICENSE.txt

set -euo pipefail

REMOTE=git@github.com:Raffaelbdl/iuna-data.git
GZ=assets/db/jmdict.sqlite.gz
VERSION=assets/db/jmdict.version
LICENSE=assets/db/jmdict.LICENSE.txt

for f in "$GZ" "$VERSION" "$LICENSE"; do
  if [[ ! -f "$f" ]]; then
    echo "missing: $f" >&2
    echo "run first: dart run tools/build_jmdict_sidecar.dart" >&2
    exit 1
  fi
done

HASH=$(tr -d '\n' < "$VERSION")
SIZE=$(du -h "$GZ" | cut -f1)

WORK=$(mktemp -d)
trap "rm -rf '$WORK'" EXIT

echo "Cloning $REMOTE..."
if ! git clone --depth 1 "$REMOTE" "$WORK" 2>&1; then
  # Brand-new empty repo — clone fails (no commits to fetch).
  # Initialise locally and push first commit.
  echo "(empty repo — initialising)"
  git -C "$WORK" init -q -b main
  git -C "$WORK" remote add origin "$REMOTE"
fi

cp "$GZ" "$WORK/jmdict.sqlite.gz"
cp "$VERSION" "$WORK/jmdict.version"
cp "$LICENSE" "$WORK/jmdict.LICENSE.txt"

git -C "$WORK" add jmdict.sqlite.gz jmdict.version jmdict.LICENSE.txt

if git -C "$WORK" diff --cached --quiet; then
  echo "no changes vs remote main — nothing to release."
  exit 0
fi

git -C "$WORK" commit -m "dict $HASH ($SIZE)"
# Older GitHub repos default to `master` — rename to `main` so the
# app's raw.githubusercontent.com URLs resolve consistently. Idempotent
# when the local branch is already `main`.
git -C "$WORK" branch -M main
git -C "$WORK" push -u origin main

echo
echo "Released $HASH ($SIZE) to $REMOTE on main."
echo "App URLs (raw.githubusercontent.com is cached ~5 min):"
echo "  https://raw.githubusercontent.com/Raffaelbdl/iuna-data/main/jmdict.version"
echo "  https://raw.githubusercontent.com/Raffaelbdl/iuna-data/main/jmdict.sqlite.gz"
echo "  https://raw.githubusercontent.com/Raffaelbdl/iuna-data/main/jmdict.LICENSE.txt"
