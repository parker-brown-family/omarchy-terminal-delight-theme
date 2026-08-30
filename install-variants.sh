#!/usr/bin/env bash
# Terminal Delight — install the palette set.
#
# Builds every variant in variants.toml into a PALETTE under
# ~/.local/share/terminal-delight/palettes/, and installs the tools that wear
# them. The picker is Terminal Paint, one card per terminal tile:
#
#   Super + Alt + P
#
# One click per terminal identity — but the identity is the TERMINAL's, not
# the desktop's. That is the whole reason palettes are not themes. Omarchy's
# theme grid answers "what does this desktop look like"; it should hold one
# Terminal Delight, not eleven, and the painter is where the eleven belong.
# An install that predates this move had them in the grid, and the build
# retires those directories on the way past.
#
# Run ./install-curve.sh once for the per-window warp itself, and
# `omarchy theme set 'Terminal Delight'` for the desktop theme.
#
# Reversible:  ./install-variants.sh --uninstall
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/themes"
PALETTES="${XDG_DATA_HOME:-$HOME/.local/share}/terminal-delight/palettes"

if [[ "${1:-}" == "--uninstall" ]]; then
  removed=0
  # Both homes: the palette directory, and the theme directory an install from
  # before the move used. A key is read from variants.toml with the SAME
  # pattern the build validates, so a malformed section can never name a path
  # to delete.
  while IFS= read -r key; do
    for dir in "$PALETTES/$key" "$THEMES/terminal-delight-$key"; do
      if [[ -d $dir && ! -d $dir/.git ]]; then
        rm -rf "$dir"
        echo "removed $dir"
        removed=$((removed + 1))
      fi
    done
  done < <(grep -oP '^\[\K[a-z0-9][a-z0-9-]*' "$here/variants.toml")
  echo "${removed} director(ies) removed. The base Terminal Delight theme is untouched."
  exit 0
fi

command -v python3 >/dev/null || { echo "python3 is required." >&2; exit 1; }
# ImageMagick and an emoji font only draw the gallery tiles, and only the
# full-theme form has a gallery. A palette install needs neither, so demanding
# them would be turning away an install that has everything it uses.
if [[ " $* " == *" --as-themes "* ]]; then
  command -v magick >/dev/null || command -v convert >/dev/null || { echo "ImageMagick (magick or convert) is required to draw the tiles." >&2; exit 1; }
  fc-list 2>/dev/null | grep -qi "emoji" || \
    echo "warning: no emoji font found — the tiles will come out blank. Install noto-fonts-emoji." >&2
fi

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

  td-tint                    pick from the set
  td-tint cherry             this terminal is now the cherry one
  td-tint --theme osaka-jade …or wear one of Omarchy's own themes
  td-tint --clear            back to the desktop theme

Or paint every tile on the workspace at once, with Terminal Paint:

  Super + Alt + P

Check the whole install at any time — it says what is missing and how to fix it:

  ./bin/doctor
TIP
