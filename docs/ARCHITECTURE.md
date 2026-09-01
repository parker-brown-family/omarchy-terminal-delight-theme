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
- **THE INVARIANT: every visible surface claims its own rect, so nothing is ever
  warped by a rect that is not its own.** This is the whole design, and it
  replaced a list of exceptions that was growing by one entry per overlay.
  `tube_at` picks a tube by OUTPUT PIXEL. A surface that is *drawn* but has no
  tube of its own therefore gets whatever rect happens to lie beneath it — and
  that is the tear, every time. The screensaver, the scratchpad, the calculator
  over an un-tubed neighbour: not three bugs, one bug, arriving through whichever
  filter had dropped a visible surface from the registry.
  So `tubes_json` drops none of them. Fullscreen windows are in; windows on a
  *raised special workspace* are in (visible-on-this-monitor is not the same as
  on-its-active-workspace); and a surface that must not bow gets **curvature 0**
  instead of being omitted — an identity map that draws no bezel but still claims
  its pixels, which is how `terminal-delight` opts out without leaving a hole for
  a neighbour to fill. A fullscreen window is now warped by one continuous map
  edge to edge rather than being torn across the tiles it covers.
  What remains is the one honest case: **a surface we cannot enumerate or
  place.** There is no rect to give it, so the partition is unknowable and the
  monitor gets no tubes at all. That is a statement about our knowledge, not a
  list of exceptions, which is why it does not grow. Today it is exactly one
  thing: a session lock. `watch` also listens for `openlayer`/`closelayer` (both
  real events — verified as `openlayer>>omarchy-menu`).
- **CLAIMING IS ONLY HALF THE RULE: tubes must also be DISJOINT.** Ordering
  decides who *owns* a pixel. It says nothing about where a map *reaches* — and a
  gather maps a whole rect into whatever of that rect is still visible. So two
  overlapping rects draw the covered band **twice**: once at 1:1 by the tube on
  top, and once again, squeezed, by the tube underneath pulling it back into
  view. Measured on the shape that produced it — a full-screen window
  `(0,0,2560,1600)` at curvature 1 with the bar claiming `(0,0,2560,41.6)` flat
  over its top:

  | screen rows | owning tube | samples source rows |
  |---|---|---|
  | 0 – 41.6 | bar, flat | 0 – 41.6 (1:1) |
  | 41 – 65 | window, bowed | 14.8 – 41.3 (**again**) |

  which is a window toolbar drawn twice, a few pixels apart. It arrived the day
  the bar started claiming: before that the window tube owned every row and its
  map was monotonic across the whole screen, so each source row appeared once.
  **A tube therefore claims what remains VISIBLE of it, not its full geometry.**
  Full generality is not available — subtracting a rect from the middle of a rect
  is not a rect — but the case that matters is edge chrome, which spans a full
  edge, so the subtraction stays a rect. A covering layer clips nothing and must
  not: it owns every pixel already, so no map beneath it is ever evaluated.
  **Residual, and it predates all of this:** two overlapping *windows* duplicate
  the same way — a floating window over a tiled one is pulled into the tile
  beneath by the tile's own map. It is least visible near the centre, where the
  barrel is near-identity, and worst at the rim. Not clippable as a rect.
- **The enumeration is the invariant. Widening a filter is not.** The tear came
  back four times, and the first three fixes are why the fourth was misread. The
  screensaver, the scratchpad and the calculator were each a CLIENT dropped by a
  filter, so each was fixed by widening that filter — and after three wins in a
  row the shape looked like "find the next dropped window". It was not. Hyprland
  draws two kinds of surface, and `tubes_json` enumerated one: `hyprctl layers`
  was read for exactly one purpose, deciding whether a lock was up, so no layer
  could ever be a claimant. The bar, the menu, every notification and every
  picker sat permanently in the failure the invariant forbids, and no widening of
  the client filter could reach them, because they were never in the loop being
  widened. **When this class recurs, ask what is DRAWN that this program does not
  ENUMERATE — not which filter dropped it.** Layers claim their own rects now, on
  the same terms as clients, and `test/run` checks each fixture layer by name so
  a whole missing source cannot pass as green again.
- **A SIZED layer claims flat. A COVERING layer is a policy call, not a
  partition.** A tube is a screen; a layer is drawn ON the glass, so a sized one
  — a bar, a dock, a panel — takes curvature 0: immune to its neighbours,
  undistorted itself. Barrelling a 26 px strip inside its own rect shears the
  text and the bezel eats its edge. That half is ordinary and it is what fixed
  the bar, which had been wearing a fullscreen window's map whenever one reached
  under it.
  **The covering half is not ordinary, and the obvious rule is wrong twice
  over.** Every Quickshell overlay Omarchy ships — `omarchy-menu`,
  `omarchy-notifications`, `hyprpicker`, `selection` — is a **full-output HOST
  surface**. Measured 2026-09-01: `omarchy-notifications` reports 1600x1000 on
  eDP-1 while drawing three toasts in a corner. The rect is the whole monitor
  whatever the host happens to be drawing, so **the surface rect tells you
  nothing about where the content is** — and the content is composited into the
  buffer BEFORE the screen shader runs, so toast pixels and desktop pixels
  arrive already blended. No single-pass gather can unwarp one and not the
  other. Same shape as the cursor problem, and not tunable either.
  **So a covering layer claims the whole output, FLAT.** Three rules were tried
  against real screens, in this order, and the two obvious ones are both wrong:
  1. **Claim nothing.** The desktop is untouched and the overlay is drawn through
     whatever tiles lie under it. It tears at their seams — and worse than
     "tears": a tile's bezel blacks whatever is drawn over its rim, so an
     overlay crossing a window's edge is CUT, not bent. Photographed twice: a
     menu with a bezel band through the middle of the card, and a toast sheared
     off mid-line where it crossed a window tube's top edge.
  2. **Claim it bowed.** Keeps the desktop bowed under a translucent card, which
     is why it looked right for the menu. It is not: a full-output tube claims
     ABOVE every tile it covers, so it also takes the pixels of a window that
     opted out at curvature 0 — `terminal-delight`, which warps its own panes —
     and warps it a second time. On a monitor filled by one such window that is
     every pixel on the screen. **The curvature-0 opt-out cannot survive
     anything claiming over the top of it bowed**, which is a general fact about
     the opt-out, not a fact about menus. It also made the desktop reshape twice
     per notification; the journal caught the count swinging `5 → 11 → 9 → 7 → 5`
     as overlays mapped and unmapped.
  3. **Claim it flat.** An identity map draws no bezel and distorts nothing, so
     the overlay renders whole and sharp, and nothing that opted out can be
     warped twice — identity composes with anything. The cost is that the
     desktop unbows for as long as an overlay is up. That is the only one of the
     three that is a change of DEGREE rather than a broken picture, and on a
     monitor whose windows are already curvature 0 it is not visible at all.
  So there is no namespace table and no list to grow: every layer is flat, sized
  or covering. The one namespace rule left is the lock, and it is not about
  curvature — a lock covers the screen with something we cannot ENUMERATE, so
  the partition is unknowable and the monitor gets no tubes rather than a flat
  one.
  Residual, worth knowing before chasing it: the re-bake is event-driven, so an
  overlay is drawn under the old tubes for the frame or two between `openlayer`
  and the recompile. That is inherent to a baked shader, not a rule that can be
  fixed here.
- **A slice is a dropped surface you wrote yourself.** `cap()` used to trim the
  list to `MAX_TUBES` with `.[0:24]`. The surfaces past the cut are still drawn —
  they just lose their rects and get warped through whichever neighbour survived,
  which is this bug arriving from inside the fix for it. There is no partially
  partitioned monitor: the budget is spent a monitor at a time and one that does
  not fit goes flat, the same answer already given for a surface that cannot be
  placed.
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
