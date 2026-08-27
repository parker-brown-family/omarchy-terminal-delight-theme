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

## Files

| File | What |
|---|---|
| `colors.toml` | the palette every Omarchy template is generated from |
| `backgrounds/` | Void Tube |
| `crt-glass.frag` | full-screen finisher: scanlines, centre bloom, vignette. `CURV = 0` — the per-window warp carries the curve, so raise it only if you want the whole desktop in one tube |
| `shaders/surface.frag`, `shaders/ext.frag` | the per-window warp |
| `hyprland.lua` | rounding, blur, borders, screen shader. Applied if you copy this theme into `~/.config/omarchy/themes/` by hand; dropped if you install it from this repo |
| `install-curve.sh` | the opt-in installer for what the drop takes away |

Copying the directory into `~/.config/omarchy/themes/terminal-delight/`
yourself keeps all of it, `hyprland.lua` included — a theme you wrote stays
yours. Then `install-curve.sh` only needs to place the shaders, and it will
tell you it is skipping the rest.

## Light mode

There isn't one. It is a tube.

## Licence

MIT.
