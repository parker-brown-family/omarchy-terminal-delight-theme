#!/usr/bin/env bash
# Terminal Delight — install the curve.
#
# `omarchy theme install` keeps everything that is colour and drops anything
# that would run code on your machine, which includes this theme's
# `hyprland.lua`. That file is where the curve lives: the rounding + squircle
# that the per-window warp keys off, the blur, and the full-screen glass
# finisher. So the colours arrive from the theme, and the curve is this
# opt-in script.
#
# It does two things:
#
#   1. copies shaders/{surface,ext}.frag into ~/.config/hypr/shaders/ — the
#      per-window barrel warp, one tube per window
#   2. writes a managed block into ~/.config/hypr/looknfeel.lua with the
#      rounding/blur/shadow/screen-shader the warp is drawn for
#
# Step 2 is skipped when the theme is a hand-copied one whose own hyprland.lua
# survived, because then those settings are already being applied.
#
# Hyprland loads the shaders when it reads its config, so step 1 needs a
# `hyprctl reload` — NOT a relogin, which is what this said for a long time
# and what the Hyprland docs imply. Verified by pixel on 0.56: install the
# shaders, `hyprctl reload`, and the windows bow immediately.
#
# Reversible:  ./install-curve.sh --uninstall
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPR_DIR="$CONFIG_HOME/hypr"
SHADER_DIR="$HYPR_DIR/shaders"
LOOKNFEEL="$HYPR_DIR/looknfeel.lua"
STAGED_THEME="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/current/theme"

BEGIN='-- >>> terminal-delight curve (managed by install-curve.sh) >>>'
END='-- <<< terminal-delight curve <<<'

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

strip_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -qF -e "$BEGIN" "$file" || return 0
  awk -v b="$BEGIN" -v e="$END" '
    index($0, b) { skip = 1 }
    !skip        { print }
    index($0, e) { skip = 0 }
  ' "$file" >"$file.td-tmp"
  awk 'NF { last = NR } { line[NR] = $0 } END { for (i = 1; i <= last; i++) print line[i] }' \
    "$file.td-tmp" >"$file"
  rm -f "$file.td-tmp"
}

if [[ "${1:-}" == "--uninstall" ]]; then
  removed=false
  for f in surface.frag ext.frag; do
    if [[ -f "$SHADER_DIR/$f" ]] && grep -q "terminal-delight" "$SHADER_DIR/$f"; then
      rm -f "$SHADER_DIR/$f"
      echo "removed $SHADER_DIR/$f"
      removed=true
    fi
  done
  if [[ -f "$LOOKNFEEL" ]] && grep -qF -e "$BEGIN" "$LOOKNFEEL"; then
    strip_block "$LOOKNFEEL"
    echo "removed the look'n'feel block from $LOOKNFEEL"
    removed=true
  fi
  $removed || echo "nothing to remove."
  echo
  if command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1; then
    echo "Reloaded Hyprland — the warp is gone."
  else
    echo "Run 'hyprctl reload' (or log back in) to drop the warp."
  fi
  exit 0
fi

[[ -d "$HYPR_DIR" ]] || { echo "no $HYPR_DIR — is Hyprland configured?" >&2; exit 1; }

# 1. the per-window warp
mkdir -p "$SHADER_DIR"
for f in surface.frag ext.frag; do
  [[ -f "$here/shaders/$f" ]] || { echo "missing $here/shaders/$f" >&2; exit 1; }
  if [[ -f "$SHADER_DIR/$f" ]] && ! grep -q "terminal-delight" "$SHADER_DIR/$f"; then
    cp -n "$SHADER_DIR/$f" "$SHADER_DIR/$f.pre-terminal-delight" || true
    echo "kept your existing $f as $f.pre-terminal-delight"
  fi
  install -Dm644 "$here/shaders/$f" "$SHADER_DIR/$f"
  echo "installed $SHADER_DIR/$f"
done

# 2. the look'n'feel the warp is drawn for — unless the theme's own Lua survived
if [[ -f "$STAGED_THEME/hyprland.lua" ]]; then
  echo
  echo "The theme's own hyprland.lua is staged, so its rounding/blur/shader are"
  echo "already applied — skipping the look'n'feel block."
else
  [[ -f "$LOOKNFEEL" ]] || { echo "-- Change the default Omarchy look'n'feel." >"$LOOKNFEEL"; }
  strip_block "$LOOKNFEEL"
  cat >>"$LOOKNFEEL" <<'LUA'

-- >>> terminal-delight curve (managed by install-curve.sh) >>>
-- The per-window warp in ~/.config/hypr/shaders/ only compiles into the
-- rounded-window shader variant, so it needs rounding > 0 to show at all.
-- rounding_power > 2 is a squircle, which reads as blown glass rather than a
-- rounded rectangle.
hl.config({
  decoration = {
    rounding = 14,
    rounding_power = 2.6,

    -- Windows must be translucent for the blur behind them to be visible.
    active_opacity = 0.94,
    inactive_opacity = 0.86,

    dim_inactive = true,
    dim_strength = 0.18,

    blur = {
      enabled = true,
      size = 5,
      passes = 2,
      noise = 0.015,
      contrast = 1.05,
      brightness = 0.85,
      vibrancy = 0.18,
      popups = true,
    },

    shadow = {
      enabled = true,
      range = 26,
      render_power = 3,
      color = "rgba(00000066)",
    },
  },
})

-- The full-screen glass finisher (scanlines, bloom, vignette). Only applied
-- while a theme that ships it is current, so switching themes cannot leave
-- Hyprland pointing at a shader that is no longer there.
local glass = os.getenv("HOME") .. "/.local/state/omarchy/current/theme/crt-glass.frag"
local probe = io.open(glass, "r")
if probe then
  probe:close()
  hl.config({ decoration = { screen_shader = glass } })
end

-- Terminal Delight warps its own panes internally -- rounding 0 exempts the
-- app from the compositor's warp so panes are not bent twice.
if o and o.window then
  o.window("terminal-delight", { rounding = 0 })
end
-- <<< terminal-delight curve <<<
LUA
  echo "wrote the look'n'feel block to $LOOKNFEEL"
fi

echo
if command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1; then
  echo "Reloaded Hyprland — the windows are bowed already."
else
  echo "Run 'hyprctl reload' (or log back in) to arm the warp."
fi
echo "Undo with: ./install-curve.sh --uninstall"
