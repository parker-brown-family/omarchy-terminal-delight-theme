# Architecture

How this system is put together, why, and how to extend it without asking
anyone. Written agent-first: every rule here exists so that a fresh session —
human or model — can make a correct change from this file alone.

## The one-sentence design

**Every capability is a CLI verb on a tested engine; everything else —
the MCP server, the bar overlay, the theme-switch hook — is a thin façade
that delegates to it.**

If you are about to put logic anywhere except the engine, stop and re-read
that sentence.

## Layers

```
 data      variants.toml · colors.toml · backgrounds/ · previews/
   │
 generator bin/build-variants            variants.toml → palettes; under
   │                                     --as-themes, whole Omarchy themes
   │                                     (hyprland.lua + retinted frag)
 render    crt-glass.frag (monitor pass) · shaders/*.frag (per-window warp+glare
   │                                     — and the rounded-variant gate that
   │                                     makes the warp switchable per window)
 engine    bin/td-tint                   paint · theme · saturate · crt ·
   │                                     clear · sync · records ·
   │                                     THE ORACLE (--state)
   │       bin/td-monitor               the monitor pass's knob surface
   │
 façades   bin/td-mcp                   the engine as MCP tools (stdlib python)
   │       omarchy-td-palette (own repo) the engine as a bar widget + overlay
   │       hooks/theme-set.d/…          the engine on every theme switch
   │
 install   install-variants.sh · install-curve.sh
```

Dependencies point strictly downward. Façades never call `hyprctl` for state,
never parse record files, never carry a terminal-class list. They call the
engine and render what it says.

## The oracle: `td-tint --state`

One JSON document describing everything paintable:

```json
{
  "variants":        [ {"key","glyph","accent","partner"} … ],
  "active_workspace": 1,
  "focused":         "0x…" ,
  "monitor":         { "name", "x", "y" },
  "tiles": [ { "address", "class", "pid", "workspace",
               "on_active_workspace", "terminal_delight", "paintable",
               "at": [x,y], "size": [w,h],
               "variant": "cherry"|null, "saturated": bool } … ]
}
```

The MCP `state`/`list_tiles` tools relay it verbatim; the overlay's snapshot
IS this one command. Window filtering, record parsing, monitor offsets and
focus all live — and are tested — in exactly one place.

## Contracts

| Contract | Where | Shape |
|---|---|---|
| Terminal-class registry | `td-tint` `TERM_CLASSES` | one JSON array constant; every consumer sees additions through `--state`/`--sync` |
| Pick records | `$XDG_RUNTIME_DIR/td-tint/<addr>` | line 1: variant key or `-` (follows theme); optional line `sat=1`. Runtime-only, dies at logout. Written by every paint/pin, removed by `--clear`, swept for dead windows by `--sync` |
| Border rule | `td-tint` | active = accent→partner 45° gradient @ee; unfocused = accent at 35% channel luminance @cc (`dim_hex`). Only ever SET — Hyprland's `set_prop` has no working unset (pixel-verified) |
| SATURATE | `td-tint` | text keys phosphor-ize toward the accent (`phos_hex`: accent hue, S floored 0.7, own lightness); other keys multiply S ×1.6 (`sat_hex`) |
| Monitor knobs | `crt-glass.frag` `MONITOR CONFIG` block | `const float NAME = value;` lines + `#define ANIMATED 0|1`; `td-monitor` rewrites, glslang-validates, recompiles via `hyprctl eval` (keyword fails softly on the Lua config) |
| Self-healing | `hooks/theme-set.d/td-tint-sync.hook` | every Omarchy theme switch runs `td-tint --sync`; `--sync` records its pins as `-` so no window is ever unreconcilable |
| TD control | `terminal-delight ctl` (its repo) | per-pid socket `$XDG_RUNTIME_DIR/terminal-delight/ctl-<pid>.sock`, one line in, one line out |
| Exit codes | all CLIs | 0 success · 1 usage/engine error (`die`) · 2 nothing-to-act-on (ctl client) |
| MCP | `bin/td-mcp` | protocol 2024-11-05; tools delegate 1:1 to CLI verbs; `isError` carries the CLI's own stderr |

## Extension recipes

- **New variant** → one `[key]` block in `variants.toml` (+ glyph). Everything
  else — theme dir, retinted frag, tile, overlay card, MCP listing — derives.
- **New terminal emulator** → add its class to `TERM_CLASSES` in `td-tint`.
  Done; `--sync`, `--state`, MCP and the overlay all see it.
- **New paint dimension** (like SATURATE) → a verb + record line in `td-tint`,
  surfaced in `--state`, then a chip in the overlay and a tool in `td-mcp`
  that shells out to the verb. Never implement the dimension in a façade.
- **New monitor effect** → a `const` knob in the `MONITOR CONFIG` block plus
  its use; `td-monitor` picks it up from the grammar automatically. Keep both
  `ANIMATED` states compiling (CI enforces).
- **New MCP tool** → an entry in `TOOLS` delegating to a CLI. If the CLI verb
  doesn't exist, write it first, with tests.

## Constraints bought with bruises (do not re-derive)

- **One QML file per third-party plugin.** A second entry point fails to load
  (`File name case mismatch`, masked upstream) — omarchy-lab#8. The widget
  therefore owns its PanelWindow inline.
- **`hl.dsp.window.set_prop` has no working "unset"** — it silently ignores
  the magic string. Reset = explicitly SET what the theme would draw.
- **`hyprctl keyword` fails softly** on the Lua config ("use eval") while
  printing ok-shaped output. Use `hyprctl eval 'hl.config({…})'`.
- **A declared `time` uniform** in a screen shader costs Hyprland its damage
  tracking (full-screen redraws). Motion is gated behind `#define ANIMATED`.
- **Live screen-shader swaps can wedge wlr-screencopy** for a while
  (omarchy-lab#7). Don't screenshot right after a swap.
- **Per-window window shaders load once at login**; the screen shader swaps
  live. Plan verification accordingly.
- **Ubuntu ships ImageMagick 6** (`convert`), Arch ships 7 (`magick`) —
  `build-variants` resolves `MAGICK` once; keep invocations classic-CLI.
- **OSC palette theming cannot touch truecolor cells.** Verified 2026-08-29
  on a live tmux tile (`*:RGB` passthrough, `COLORTERM=truecolor` app): the
  indexed status line took the saturate crank, the 24-bit prose did not —
  same tile, same OSC push. Not a delivery bug; palette redefinition has no
  jurisdiction over per-cell RGB. Don't chase it with more OSC (see #7); the
  every-pixel path is renderer-level grading (Terminal Delight adoption).
- **A window shader can never be click-correct.** `shaders/surface.frag` runs
  during `renderWorkspace()`, before `renderSoftwareCursorsFor()` composites
  the cursor into the same buffer, so the picture moves and the pointer does
  not — ~1.7% of a window's width at its rim, ~4.25% at the corner, at
  k1=0.14/k2=0.06. Not tunable; it is which pass you are in. The monitor pass
  runs after the cursor is in the buffer, which is why the tubes live there
  (`td-tubes`). Same reason Terminal Delight's own CRT pass is honest — see
  `warp_screen_to_content`, app/src/pane.rs.
- **The cursor rides the MONITOR pass — but that alone does not make aiming
  work, and a probe built to check it can be circular.** The cursor is
  composited into the primary framebuffer before the screen shader: confirmed by
  the KMS scanout with `gpu-screen-recorder -cursor no`, which draws nothing of
  its own, and by `modetest -p` showing every Cursor-type plane at
  `crtc=0 fb=0`, so no hardware cursor plane is involved.
  **What that does NOT establish is alignment.** Write the maps out: a
  per-window shader `W` warps a window's texture, the monitor pass `M` warps the
  whole buffer, and the cursor is composited *between* them. Content at texture
  point `T` is drawn at `M⁻¹(W⁻¹(T))`; the cursor at pointer position `C` is
  drawn at `M⁻¹(C)`. Aligning them visually gives `C = W⁻¹(T)` while a hit needs
  `C = T` — so **any live per-window warp is a miss of exactly one `W`**, no
  matter how honest the monitor pass is.
  `test/probe-aim` cannot see this. It finds a marker's drawn position `D`,
  parks the pointer at `M(D)`, and confirms the cursor draws at `D` — which is
  true whether or not `W` exists. It is a test of `M` alone. Read its verdict as
  "the monitor pass is self-consistent", never as "aiming works".
  **Three traps sit around measuring any of this**, each of which produced a
  confident wrong answer first: a hover-reactive window repaints CONTENT under
  the pointer, which lands exactly on the barrel prediction and reads as a
  warped cursor while proving nothing (use a window running `sleep`); a hardware
  cursor plane would be on the panel and in NO capture; and
  `hyprctl dispatch movecursor` is a silent no-op on 0.56.
- **A tube outlives what it is a tube FOR, and the monitor pass cannot tell.**
  `tube_at` picks by output pixel, so a rect left baked under something that
  covers it warps whatever is drawn on top. The screensaver
  (`org.omarchy.screensaver`, a fullscreen window) came out with the tiles curved
  into it — straight on the half of the screen no tile occupied, bowed inside a
  bezel box on the half one did. The fullscreen window was already excluded on
  its own account, which is precisely why this was missed: **the offender is
  every OTHER tube on that monitor.** Same for a lock screen, which is a *layer*
  and therefore invisible to `clients -j` entirely. `tubes_json` now drops every
  tube on a monitor that has a fullscreen window on its active workspace, or a
  layer covering the output — levels 2 and 3 only, since the wallpaper is a
  full-size layer that sits *under* the windows. `watch` listens for
  `openlayer`/`closelayer` (both are real events — verified as
  `openlayer>>omarchy-menu`).
- **Omarchy's lock is not a layer, and nothing announces it.** There is no
  `hyprlock` on the box: `omarchy-system-lock` calls `omarchy-shell lock`, whose
  lock is a Quickshell **ext-session-lock** surface. That protocol is neither a
  client nor a layer, so `hyprctl clients` and `hyprctl layers` are both blind to
  it and no event fires — a lock screen came up over rects that were still baked
  and wore the curve of the tiles. The only tell is second-hand and is Omarchy's
  own: a session lock blocks a monitor from going solitary, so `LOCK` appears in
  `solitaryBlockedBy` (see `/usr/share/omarchy/bin/omarchy-hyprland-session-locked`).
  `watch` therefore carries a 2 s `read -t` heartbeat purely for this one state —
  measured at 0.096 s CPU per 30 s idle, 0.32%.
- **Match a covering layer by NAMESPACE, not by size.** `omarchy-menu` is also a
  full-output level-3 layer, and it is translucent: the desktop shows through it
  and is supposed to stay bowed. A size-only rule flattened the entire desktop on
  every menu press — a worse bug than the one being fixed, and the reason the
  rule now requires `lock` in the namespace as well.
- **A per-window shader survives deleting its file AND `hyprctl reload`. Only a
  logout drops it.** Measured 2026-08-31 with `test/probe-warp-count`: with
  `surface.frag` deleted from `~/.config/hypr/shaders/` and after a reload,
  windows were still bowed with the tubes baked at `TUBE_COUNT 0` — i.e. with
  the monitor pass an identity, so the bow could only be the window shader.
  Replacing the file with one whose `TD_K1`/`TD_K2` are `0.0` and reloading did
  not change it either. **This falsifies the commit message of `fb59fd8`
  ("`hyprctl reload` arms the warp — the relogin was never needed") and the note
  it put in `install-curve.sh`.** The older line above — window shaders load once
  at login — is the one that survived.
  It is the nastiest shape of bug this repo has hit, because every check is
  file-based and every file said "off" while the compositor kept running the
  compiled copy. `td-tubes` and `bin/doctor` now say "no shader on disk" rather
  than "off", and `install-curve.sh --tubes` tells you to log out.
- **Correct aim still feels wrong at a corner, and that is not a bug to fix.**
  The click lands, but your HAND travels to the target's TRUE position while
  your EYE sees it pulled inward — up to ~4.25% of the tile at a corner, ~40 px
  on a 900 px tile. Nothing in the compositor can reconcile that: Hyprland
  hit-tests raw pointer coordinates and knows nothing about the shader. The
  only dial is the warp itself, `TUBE_K1`/`TUBE_K2`, which is why they now live
  in the MONITOR CONFIG block where `td-monitor` lists them.
- **hyprctl coordinates and shader coordinates are different spaces on a
  rotated monitor.** hyprctl reports LOGICAL rects in the monitor's rotated
  orientation; the compositing buffer keeps the MODE orientation and Hyprland
  rotates at the final blit. Identical on transform 0, 90 degrees apart
  otherwise. Convert with Hyprutils' `Vector2D::transform` (both corners, then
  rebuild axis-aligned), never with an origin shift alone. Tell: the shader's
  own scanlines come out sideways on a rotated display.
- **A gather-warp screen shader needs `debug:damage_tracking = 0`.** The
  output pixel at P samples the source at some other point, so re-blitting
  only a damaged rect leaves stale pixels inside it. With a software cursor
  damaging a fresh rect every frame, it reads as tearing under mouse movement.
  `td-tubes` sets this, and `cursor:no_hardware_cursors = 1` beside it; both
  are runtime-only and a `hyprctl reload` drops them.
- **A screenshot cannot photograph a damage-tracking artifact.** wlr-screencopy
  calls `damageMonitor()` on every capture (Screencopy.cpp), which Hyprland
  promotes to a full-monitor repaint (Renderer.cpp) — so the act of capturing
  repairs exactly the staleness you were trying to measure. A grim-based probe
  for this class of bug reports "clean" unconditionally; one was written here
  and deleted for that reason. This is the one renderer question the
  pixel-verification rule below CANNOT answer: it needs a human looking at a
  live screen.

## Testing doctrine

`test/run`: hermetic — XDG trees are throwaway, every external binary is a
logging stub on PATH, and assertions read files and call logs. The engine's
logic (colour math, records, sync, the oracle, td-monitor's grammar, the MCP
session) is covered there; CI additionally compiles every generated frag in
both `ANIMATED` states and shellchecks everything. **Renderer changes are
verified by pixel** (screenshot crops), because this session proved twice
that exit codes lie about visual systems.

## Naming

`td-tint` under-describes what the engine became; it keeps the name because
its OSC-tint verb is still the heart, and churning a public binary name costs
users more than the asymmetry costs maintainers.
