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
command -v magick >/dev/null || command -v convert >/dev/null || { echo "ImageMagick (magick or convert) is required to draw the tiles." >&2; exit 1; }
fc-list 2>/dev/null | grep -qi "emoji" || \
  echo "warning: no emoji font found — the tiles will come out blank. Install noto-fonts-emoji." >&2

# td-tint is how a single terminal gets its own identity without moving the
# whole desktop. Put it somewhere the shell can find it.
bindir="$HOME/.local/bin"
mkdir -p "$bindir"
ln -sfn "$here/bin/td-tint" "$bindir/td-tint"
echo "installed $bindir/td-tint"

# td-monitor turns the knobs on the desktop's CRT glass (the MONITOR CONFIG
# block in crt-glass.frag) — same install story as td-tint.
ln -sfn "$here/bin/td-monitor" "$bindir/td-monitor"
echo "installed $bindir/td-monitor"

# td-mcp exposes the whole paint surface to agents as MCP tools; register it
# with e.g.  claude mcp add td-paint -- "$bindir/td-mcp"
ln -sfn "$here/bin/td-mcp" "$bindir/td-mcp"
echo "installed $bindir/td-mcp"

# The self-healing half of td-tint: Omarchy runs theme-set.d executables
# after every theme switch, and per-window border props outlive switches
# (set_prop has no working unset) — so every switch runs the reconciler.
hookdir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/hooks/theme-set.d"
mkdir -p "$hookdir"
ln -sfn "$here/hooks/theme-set.d/td-tint-sync.hook" "$hookdir/td-tint-sync.hook"
echo "installed $hookdir/td-tint-sync.hook"

"$here/bin/build-variants" "$@"

cat <<'TIP'

Tint one terminal without touching the others:

  td-tint            pick from the set
  td-tint cherry     this terminal is now the cherry one
  td-tint --clear    back to the desktop theme
TIP
