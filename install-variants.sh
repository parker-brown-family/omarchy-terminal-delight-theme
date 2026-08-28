#!/usr/bin/env bash
# Terminal Delight — install the variant set.
#
# Builds every variant in variants.toml into its own Omarchy theme under
# ~/.config/omarchy/themes/, so Omarchy's own theme grid becomes the picker:
#
#   Super + Shift + Ctrl + Space
#
# One click per terminal identity. Nothing new to learn, no second UI.
#
# The variants are generated on your machine rather than shipped in the repo,
# which is not just about repo size: omarchy-theme-set only strips Lua from a
# theme carrying its own .git, so a locally-built theme keeps its
# hyprland.lua — and with it the rounding, blur and screen shader the curve
# needs. Run ./install-curve.sh once for the per-window warp itself.
#
# Reversible:  ./install-variants.sh --uninstall
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/themes"

if [[ "${1:-}" == "--uninstall" ]]; then
  removed=0
  while IFS= read -r key; do
    dir="$THEMES/terminal-delight-$key"
    if [[ -d $dir && ! -d $dir/.git ]]; then
      rm -rf "$dir"
      echo "removed $dir"
      removed=$((removed + 1))
    fi
  done < <(grep -oP '^\[\K[a-z0-9-]+' "$here/variants.toml")
  echo "${removed} variant(s) removed. The base Terminal Delight theme is untouched."
  exit 0
fi

command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }
command -v magick >/dev/null || { echo "ImageMagick (magick) is required to draw the tiles." >&2; exit 1; }
fc-list 2>/dev/null | grep -qi "emoji" || \
  echo "warning: no emoji font found — the tiles will come out blank. Install noto-fonts-emoji." >&2

exec "$here/bin/build-variants" "$@"
