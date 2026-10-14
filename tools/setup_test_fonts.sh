#!/usr/bin/env bash
# Links the fonts the golden tests render with into test/fonts/
# (gitignored): Noto Sans CJK (Regular + Bold) and Noto Color Emoji.
#
#   Debian/Ubuntu: sudo apt install fonts-noto-cjk fonts-noto-color-emoji
#
# Override the search with CJK_DIR=... / EMOJI_FONT=... if your
# distribution puts them elsewhere.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p test/fonts

find_font() {
  local name=$1; shift
  for dir in "$@"; do
    [[ -f "$dir/$name" ]] && { echo "$dir/$name"; return 0; }
  done
  echo "missing: $name (searched: $*)" >&2
  return 1
}

cjk_dirs=(${CJK_DIR:-} /usr/share/fonts/opentype/noto /usr/share/fonts/noto-cjk
  /usr/share/fonts/google-noto-cjk)
regular=$(find_font NotoSansCJK-Regular.ttc "${cjk_dirs[@]}")
bold=$(find_font NotoSansCJK-Bold.ttc "${cjk_dirs[@]}")
emoji=${EMOJI_FONT:-$(find_font NotoColorEmoji.ttf /usr/share/fonts/truetype/noto \
  /usr/share/fonts/noto /usr/share/fonts/google-noto-emoji)}

ln -sf "$regular" test/fonts/NotoSansCJK-JP-Regular.otf
ln -sf "$bold" test/fonts/NotoSansCJK-JP-Bold.otf
ln -sf "$emoji" test/fonts/NotoColorEmoji.ttf
echo "Linked test fonts into test/fonts/."
