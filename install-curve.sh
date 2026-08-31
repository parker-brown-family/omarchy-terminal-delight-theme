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
# TWO TIERS, PICK ONE.
#   ./install-curve.sh           the per-window warp (default). Cheap, static,
#                                and NOT click-correct — it runs before the
#                                cursor is composited, so the picture moves and
#                                the pointer does not.
#   ./install-curve.sh --tubes   the monitor pass. One tube per tile, warped
#                                after the cursor is in the buffer, so clicks
#                                land where you aimed. Moves the per-window
#                                shaders aside (reversibly) and installs the
#                                watcher that keeps the tile rects true.
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

# --tubes selects the OTHER tier. Both bow a window; only one of them can be
# click-correct, so this is a choice and not a level.
#
#   default   the per-window warp — shaders/surface.frag, drawn in
#             renderWorkspace(), before the cursor is composited. The picture
#             moves and the pointer does not: ~1.7% of a window's width at the
#             rim, ~4.25% at the corner. Cheap, needs nothing running.
#   --tubes   the monitor pass — crt-glass.frag warps one rect per tile AFTER
#             the cursor is in the buffer, so cursor and content are displaced
#             together and a click lands where you aimed. Costs a watcher.
#
# Running BOTH is the one combination that is worse than either: content is
# warped twice, the cursor once, and the miss comes back. So --tubes moves the
# per-window shaders aside rather than leaving that to a reader's discipline.
TUBES=""
# Set when --tubes actually moved a per-window shader out of the way. That means
# one is STILL COMPILED INTO THIS SESSION (a window shader is loaded at login and
# survives both rm and `hyprctl reload`), so the watcher must not be started
# until the next login — see install_unit.
WARP_WAS_LIVE=""
DISABLED_DIR="$SHADER_DIR/disabled-by-td-tubes"
UNIT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
UNIT="td-tubes.service"

# `case` rather than a loop ending in a bare `&&`: under `set -e` that shape is
# one edit away from aborting the script on any argument that is not --tubes,
# which would make --uninstall a silent no-op.
case " $* " in *" --tubes "*) TUBES=1 ;; esac

# The unit is shipped with a placeholder because this repo never puts its
# binaries on PATH — baking the checkout's own path in is what makes the
# service work for someone who installed the theme the documented way.
install_unit() {
  command -v systemctl >/dev/null || {
    echo "no systemctl — start the watcher yourself with: $here/bin/td-tubes watch"
    return 0
  }
  command -v socat >/dev/null ||
    echo "warning: 'socat' is missing and td-tubes watch needs it — install it or the unit will fail"
  mkdir -p "$UNIT_DIR"
  sed "s|@TD_TUBES@|$here/bin/td-tubes|g" "$here/systemd/$UNIT" >"$UNIT_DIR/$UNIT"
  echo "installed $UNIT_DIR/$UNIT"
  systemctl --user daemon-reload >/dev/null 2>&1 || true

  # DO NOT start the watcher in a session that still has the old per-window
  # shader compiled in. Moving the file aside does not unload it, so baking
  # tubes now would warp every window TWICE — once by the stale shader, once by
  # the monitor pass — while the cursor is warped only by the second. That is
  # the precise defect the tubes exist to remove, and starting eagerly would
  # hand it to the user for the rest of their session. Enable for next login and
  # say so.
  if [[ -n $WARP_WAS_LIVE ]]; then
    if systemctl --user enable "$UNIT" >/dev/null 2>&1; then
      echo "enabled $UNIT for NEXT LOGIN — deliberately not started now."
      echo "  The per-window shader you just moved aside is still compiled into"
      echo "  this session, and running both warps bows every window twice."
    else
      echo "wrote the unit but could not enable it; check: systemctl --user status $UNIT"
    fi
    return 0
  fi

  if systemctl --user enable --now "$UNIT" >/dev/null 2>&1; then
    echo "enabled and started $UNIT — the tubes now follow the layout"
  else
    echo "wrote the unit but could not start it; check: systemctl --user status $UNIT"
  fi
}

# Returns non-zero when there was nothing to remove, so the caller's "nothing
# to remove." message stays honest.
remove_unit() {
  command -v systemctl >/dev/null || return 1
  [[ -f "$UNIT_DIR/$UNIT" ]] || return 1
  systemctl --user disable --now "$UNIT" >/dev/null 2>&1 || true
  rm -f "$UNIT_DIR/$UNIT"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  echo "removed $UNIT_DIR/$UNIT"
}

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
  remove_unit && removed=true
  for f in surface.frag ext.frag; do
    if [[ -f "$SHADER_DIR/$f" ]] && grep -q "terminal-delight" "$SHADER_DIR/$f"; then
      rm -f "$SHADER_DIR/$f"
      echo "removed $SHADER_DIR/$f"
      removed=true
    fi
    # Anything --tubes moved aside was the user's, not ours. Put it back before
    # walking away, or an uninstall silently keeps a file it did not create.
    if [[ -f "$DISABLED_DIR/$f" ]]; then
      mv -n "$DISABLED_DIR/$f" "$SHADER_DIR/$f" && echo "restored $SHADER_DIR/$f"
      removed=true
    fi
  done
  rmdir "$DISABLED_DIR" 2>/dev/null || true
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

# 1. the warp — one tier or the other, never both
mkdir -p "$SHADER_DIR"
if [[ -n $TUBES ]]; then
  # Move rather than delete: these may be the user's own shaders, and
  # --uninstall puts them back. The directory name is the reason, so someone
  # finding it a month later does not have to guess.
  mkdir -p "$DISABLED_DIR"
  moved=false
  for f in surface.frag ext.frag; do
    if [[ -f "$SHADER_DIR/$f" ]]; then
      mv -f "$SHADER_DIR/$f" "$DISABLED_DIR/$f"
      echo "moved $f aside to ${DISABLED_DIR/#$HOME/\~} — the tubes are the window warp now"
      moved=true
      WARP_WAS_LIVE=1
    fi
  done
  $moved || echo "no per-window warp installed — nothing to move aside"
  rmdir "$DISABLED_DIR" 2>/dev/null || true
  # Moving the file is not the same as stopping the shader. Hyprland compiles a
  # per-window shader at login and keeps it: measured on 0.56.2, a window is
  # still bowed with the file deleted, after `hyprctl reload`, and with the tubes
  # baked at zero. Say so here, because everything else a user can check is
  # file-based and will cheerfully report "off" while the warp is on the screen.
  if $moved; then
    echo
    echo "  NOTE: the running Hyprland still has the old shader compiled in, and"
    echo "        neither the move above nor the reload below drops it. Until you"
    echo "        LOG OUT, windows are warped twice — once by that shader and once"
    echo "        by the tubes — and clicks will land off by the first warp."
    echo "        Verify with: test/probe-warp-count"
  fi
else
  for f in surface.frag ext.frag; do
    [[ -f "$here/shaders/$f" ]] || { echo "missing $here/shaders/$f" >&2; exit 1; }
    if [[ -f "$SHADER_DIR/$f" ]] && ! grep -q "terminal-delight" "$SHADER_DIR/$f"; then
      cp -n "$SHADER_DIR/$f" "$SHADER_DIR/$f.pre-terminal-delight" || true
      echo "kept your existing $f as $f.pre-terminal-delight"
    fi
    install -Dm644 "$here/shaders/$f" "$SHADER_DIR/$f"
    echo "installed $SHADER_DIR/$f"
  done
fi

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

# 3. the watcher, for the tubes tier only. This is not a nicety: `td-tubes
# apply` bakes a snapshot, and a rect stops being true the next time a window
# opens, closes or moves. Shipping the tubes without this is shipping a picture
# that is right once.
if [[ -n $TUBES ]]; then
  echo
  install_unit
fi

echo
if command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1; then
  echo "Reloaded Hyprland — the windows are bowed already."
else
  echo "Run 'hyprctl reload' (or log back in) to arm the warp."
fi
if [[ -n $TUBES ]]; then
  echo "Check it any time with: td-tubes   (it reports the watcher and the preconditions)"
fi
echo "Undo with: ./install-curve.sh --uninstall"
