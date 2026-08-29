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
 generator bin/build-variants            variants.toml → full Omarchy themes
   │                                     (palette, hyprland.lua, retinted frag)
 render    crt-glass.frag (monitor pass) · shaders/*.frag (per-window warp+glare)
   │
 engine    bin/td-tint                   paint · saturate · clear · sync ·
   │                                     records · THE ORACLE (--state)
   │       bin/td-monitor               the monitor pass's knob surface
   │
 façades   bin/td-mcp                   the engine as MCP tools (stdlib python)
   │       incubator/td-palette (lab)   the engine as a bar widget + overlay
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
