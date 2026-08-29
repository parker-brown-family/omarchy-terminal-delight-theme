# Terminal Delight — an Omarchy theme

Phosphor green on void black, and every window bowed like the face of a tube.

Sampled from the [Terminal Delight](https://github.com/parker-brown-family/terminal-delight)
terminal's own brand palette, with the same barrel warp the app uses on its
panes — `f = 1 + 0.14·r² + 0.06·r⁴` — lifted to the compositor so it bends
every window, not just one app's.

![preview](preview.png)

## Install

```
Omarchy menu (Super + Space) → Install → Style → Theme
https://github.com/parker-brown-family/omarchy-terminal-delight-theme
```

That gets you the colours, the background, and the full-screen glass. It does
not get you the curve — read on.

## The curve is a second step, on purpose

Omarchy keeps everything in an installed theme that is colour and drops
anything that would run code on your machine: any `.lua`, the terminal
configs, `vscode.json`. That is a good rule, and this theme runs headlong into
it, because the curve lives in exactly the file it drops.

Two pieces make a window look like glass:

| Piece | File | Survives `theme install`? |
|---|---|---|
| Per-window barrel warp | `shaders/{surface,ext}.frag` | goes to `~/.config/hypr/shaders/`, never the theme dir |
| Rounding, squircle, blur, screen shader | `hyprland.lua` | **no** — dropped as Lua |

So the curve ships as a script you run yourself, after you have read it:

```bash
git clone https://github.com/parker-brown-family/omarchy-terminal-delight-theme
cd omarchy-terminal-delight-theme
./install-curve.sh          # then log out and back in
```

It copies the two shaders into `~/.config/hypr/shaders/` and writes one marked
block into your `~/.config/hypr/looknfeel.lua` — the rounding and blur the warp
is drawn for. Both are reversed by `./install-curve.sh --uninstall`.

**Log out and back in.** Hyprland reads its shaders once at startup
(`m_shadersInitialized`, 0.56); editing them on a running session does nothing.

## The monitor has knobs

The glass is not a fixed effect any more — it is Terminal Delight's own
display stack, ported dial for dial from the terminal (`app/src/crt.rs` and
its CRT render pass): scanlines with the phosphor tint line, the 160px
tracking band that sweeps down and rests, the occasional stepped flicker
burst, the glass glare hotspot with its diagonal streak, centre phosphor
bloom, vignette — and a monitor-OSD grade (brightness / contrast /
saturation / gamma) applied last, exactly the order the terminal grades its
own tube. Each variant's glass glows in its own hue: the phosphor, scanline
tint, tracking band and glare are retinted per variant by `bin/build-variants`.

Every dial is a `const` at the top of `crt-glass.frag` — the MONITOR CONFIG
block is the config surface — and `td-monitor` turns them without a relogin:

```bash
td-monitor                       # what every knob is set to
td-monitor set TRACKING 0.8      # a hotter roll bar
td-monitor set FLICKER 0 SCAN 0.1   # calm it down
td-monitor off                   # lift the glass entirely
td-monitor reset                 # pristine defaults
```

A `set` is validated with `glslangValidator` before it touches the live
compositor, applied across the whole installed family (a monitor setting is
not a per-colourway thing), and recompiled in place. Hand-editing the block
works exactly as well — the tool is a convenience, not a gate.

**The glare lives on the tiles.** Each window's glass glare (the hotspot +
diagonal streak) ships in the per-window warp shaders — `install-curve.sh`,
relogin to arm — so every tile catches the room light like a Terminal Delight
pane, and Terminal Delight's own windows (which draw their own glass) are
excluded by their rounding-0 rule. The monitor pass's `GLARE` knob is the
WHOLE-SCREEN version and defaults to 0; without the curve installed, raise it
(`td-monitor set GLARE 0.42`) for one big sheet of glass instead.

**Motion is opt-in.** Hyprland treats any screen shader that declares a
`time` uniform as animated and turns damage tracking off for it — its own
warning says the quiet part: the whole screen redraws every frame. So the
glass ships STILL (`ANIMATED 0`): no clock, no warning, no cost — scanlines,
glare, bloom and grade are all static effects. Turning any motion knob
(`TRACKING`, `FLICKER`, `JIGGLE`) above zero raises `ANIMATED` for you, and
zeroing all three drops it again; `td-monitor set ANIMATED 1` forces it. The
tracking band earns its GPU bill — decide per moment, not per install.

## What the warp does, and what it costs

The warp compiles only into the rounded-window shader variant, so it keys off
`rounding > 0`. Windows bow. Layers — the bar, the wallpaper, menus — and
fullscreen windows stay flat.

Three things worth knowing before you install it:

- **It is compositor-wide, not theme-scoped.** Those two shaders sit in your
  Hyprland config, not in the theme, so they keep bending windows after you
  switch to another theme — as long as that theme has rounding. Any theme with
  `rounding = 0` is unaffected on its own. Remove the warp with
  `--uninstall`.
- **Hit-testing stays flat.** Near a window's edge the visible content sits up
  to about 2% of the window's size inward of where your cursor actually
  clicks. Middles are fine; corners of a tightly-packed UI are not. Turn
  `TD_K1`/`TD_K2` down in `shaders/surface.frag` if it bothers you.
- **Terminal Delight itself is exempt.** The app warps its own panes, so the
  theme pins its window class to `rounding = 0` — otherwise it gets bent
  twice.

## Nine terminals you can tell apart

![the variant set](previews/gallery.png)

A wall of terminals that all look the same is a wall of terminals you have to
read to navigate. So the theme ships a set: one glyph, one hue, one identity
each.

```bash
./install-variants.sh
```

Then open Omarchy's own theme grid and click one:

```
Super + Shift + Ctrl + Space
```

That grid is already an image picker with labelled thumbnails, so there is no
second UI to build and nothing new to learn — the variants just show up in it,
clustered together under `Terminal Delight …`, each wearing its glyph.

| | Variant | Reads as |
|---|---|---|
| 🪵 | wood | warm oak, the quiet one |
| ☢️ | radioactive | acid green, impossible to miss |
| 🦇 | bat | violet dusk |
| 🍍 | pineapple | gold with a green leaf |
| 🪖 | soldier | olive drab, muted on purpose |
| 🔥 | ember | forge red |
| ❄️ | glacier | ice cyan |
| 🌊 | tide | deep cobalt |
| 🍒 | cherry | rose crimson |

Remove them again with `./install-variants.sh --uninstall`. The base theme is
left alone.

### The config surface is one file

[`variants.toml`](variants.toml) is the whole thing. Six keys per variant —
glyph, accent, accent_bright, foreground, background, surface — and
`bin/build-variants` derives the rest: the full 26-key palette, the foreground
ramp, the background steps, the window border gradient, the tinted wallpaper
and the tile.

```toml
[cherry]
glyph         = "🍒"
accent        = "#F43C7A"
accent_bright = "#F49CC8"
foreground    = "#C7A9B4"
background    = "#0A0407"
surface       = "#220C16"
```

Copy a block, change the colours, re-run the installer. There is no colour
wheel and no live editor, because the thing editing this is usually an agent,
and an agent would rather write six hex values than drag a pip.

The semantic ANSI colours — red, yellow, orange, magenta — are inherited from
the base in every variant, so code stays readable wherever you are. The slots
Terminal Delight uses as its signature pair, the greens and cyans, are where
the variant's hue lands. That is the part you see without looking.

### One terminal at a time — `td-tint`

An Omarchy theme is global by design. Switching it repaints every terminal at
once, which is the exact opposite of being able to tell them apart. So the
variants come with a second, smaller tool that changes **one terminal and
nothing else**:

```bash
td-tint            # pick from the set
td-tint cherry     # this terminal is now the cherry one
td-tint --clear    # back to whatever the desktop theme says
```

It writes that variant's OSC palette down the terminal's own tty, and sets
the border colour as a property on that terminal's own window. Both are
runtime-only: nothing is written to disk, there is no state to clean up, and
the tint dies with the window. The desktop theme is never touched, so you can
run nine differently-coloured terminals side by side on one theme — text,
ANSI ramp and window border all matching.

The window it recolours is found by walking up `/proc` from the calling shell
until a pid matches a Hyprland client, so it works from inside tmux and from
a script, not only from the shell you are typing in.

Every pick is remembered at `$XDG_RUNTIME_DIR/td-tint/<addr>` (runtime-only,
dies at logout), and a `theme-set.d` hook installed by `install-variants.sh`
runs `td-tint --sync` after every Omarchy theme switch — so recorded picks
keep their identity, everything else adopts the new theme's borders, and no
window is ever left wearing yesterday's colours. Per-window border props
survive switches on their own (Hyprland's `set_prop` has no working unset),
which is exactly why the hook exists.

Terminal Delight itself is not the target here — it renders its own palette
and has a per-pane colour tray for the same job. `td-tint` is for foot,
Alacritty, Ghostty, kitty: anything that honours OSC 4/10/11.

### Why the variants are built, not shipped

`omarchy-theme-set` only strips Lua from a theme carrying its own `.git`
(`omarchy-theme-set:207`). A variant generated on your machine has none — so
it keeps its `hyprland.lua`, and the rounding, blur and screen shader come
with it. **Every variant is curved out of the box.** Only the per-window warp
is still a separate step, because those shaders live in Hyprland's config
rather than in any theme:

```bash
./install-curve.sh    # once, then log out and back in
```

## Files

| File | What |
|---|---|
| `colors.toml` | the palette every Omarchy template is generated from |
| `backgrounds/` | Void Tube |
| `crt-glass.frag` | the MONITOR pass — Terminal Delight's display stack for the whole desktop: px-true scanlines, the rolling tracking band, stepped flicker, glass glare, phosphor bloom, vignette, and a brightness/contrast/saturation/gamma grade. Every dial is a `const` in its MONITOR CONFIG block; `CURV = 0` because the per-window warp carries the curve |
| `shaders/surface.frag`, `shaders/ext.frag` | the per-window warp |
| `hyprland.lua` | rounding, blur, borders, screen shader. Applied if you copy this theme into `~/.config/omarchy/themes/` by hand; dropped if you install it from this repo |
| `install-curve.sh` | the opt-in installer for what the drop takes away |
| `variants.toml` | the variant set: six keys each, the only file you edit |
| `bin/build-variants` | derives a full theme from those six keys, and draws the tile |
| `bin/td-tint` | tint one terminal — text and border — without touching the theme |
| `bin/td-monitor` | turn the monitor's knobs — rewrite the CONFIG block across the installed family, validate, recompile live |
| `bin/td-mcp` | the paint surface as MCP tools for agents — see "Agents paint too" |
| `test/run` | the hermetic test suite (stubs for hyprctl/omarchy-theme-*; no compositor needed) |
| `install-variants.sh` | builds every variant into `~/.config/omarchy/themes/` |
| `previews/` | the tiles, as the theme grid shows them |

Copying the directory into `~/.config/omarchy/themes/terminal-delight/`
yourself keeps all of it, `hyprland.lua` included — a theme you wrote stays
yours. Then `install-curve.sh` only needs to place the shaders, and it will
tell you it is skipping the rest.

## Agents paint too

`bin/td-mcp` is the whole surface as an MCP server — stdlib Python, stdio,
register it once:

```bash
claude mcp add td-paint -- ~/.local/bin/td-mcp
```

Tools: `list_variants`, `list_tiles` (every terminal window with its recorded
variant + saturation), `paint`, `border_only`, `saturate`, `clear`, `sync`,
`paint_panes` (Terminal Delight's per-pane picker over its control socket),
`monitor_knobs`, `monitor_set`. Deliberately thin: every tool delegates to
the same CLI a human runs, so there is one behaviour and the MCP layer can
never drift from it.

## Tests

```bash
./test/run
```

Dependency-free and hermetic: `XDG_*` point into a throwaway tree and
hyprctl / omarchy-theme-color / omarchy-theme-osc / glslangValidator /
terminal-delight are logging stubs on `PATH`, so the suite asserts against
files and call logs, never your live compositor. CI (GitHub Actions) runs
the suite, shellcheck at warning level, `td-mcp` byte-compilation, and
compiles every generated frag in BOTH `ANIMATED` states.

## Light mode

There isn't one. It is a tube.

## Licence

MIT.
