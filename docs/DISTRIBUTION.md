# Distribution

How this offering reaches people, and why it deliberately lives OUTSIDE
Omarchy core. Researched against the live ecosystem on 2026-08-29.

## The bet

Omarchy's culture answered this question for us: the plugin marketplace at
<https://omarchyplugins.com> went from **zero community plugins to 500+ in
under a week**, and the project ran its first plugin competition in August
2026 ($2.5k/$1k/$500, judged by the new Omarchy Core team, funded by DHH's
X promotion money). Core stays lean; **the bolt-on ecosystem is the point.**
We do not aim for core inclusion — we aim to be an exemplary citizen of the
ecosystem that is actually growing.

## Channel 1 — this repo (the theme + engine)

Users install the theme straight from the public repo (see README), which
brings the 11 palettes, the curve + per-tile glare, the monitor pass,
`td-tint`/`td-monitor`/`td-mcp` and the self-healing hook. **Shipped, current
release v0.3.0.**

### What a theme actually has to author

Researched against Omarchy 4.0.1 on 2026-08-30, because the shipped themes are
misleading on this point. 22 of 22 carry `neovim.lua`, `vscode.json`,
`btop.theme` and friends, and **none of that is a theme's job any more**:
`omarchy-theme-set-templates` generates every one of them from `colors.toml`
via `$OMARCHY_PATH/default/themed/*.tpl` — neovim, btop, chromium, vscode,
helix, kitty/foot/ghostty/alacritty, claude, obsidian, even the keyboard RGB.

Shipping them is worse than pointless. `INSTALLED_THEME_DENIED` plus a blanket
`*.lua` rule strips them from any theme installed from a repo, so they would be
dead weight in the clone and absent from the staged theme.

A theme authors four things:

| File | Why |
|---|---|
| `colors.toml` | every generated config comes from here |
| `backgrounds/` | at least one, or the switcher has nothing to preview |
| `icons.theme` | one line naming a GTK icon theme |
| `preview.png` | the tile in Omarchy's own theme grid |

`unlock.png` and `preview-unlock.png` are the trap: every shipped theme has
both, and **nothing in Omarchy 4.x reads either.** `LockView.qml` blurs the
wallpaper. They are Omarchy 3 leftovers; do not add them.

## Channel 1b — omarchy.org/themes: the official listing

A pull request to [`omacom/omarchy-site`](https://github.com/omacom/omarchy-site)
(`omacom-io` redirects to it; default branch `master`), touching two paths:
`assets/themes/<name>.webp` and an alphabetical `<figure>` in
`themes/index.html`. Their README sets the terms, and the last line is the one
that matters: *"Pull requests without a screenshot can't be merged, because
there's nothing to put on the page."*

The screenshot brief, verbatim in effect:

- WebP, aim 1200x675, under about 100 KB
- their own recipe: `magick shot.png -strip -resize '1200>' -quality 80 out.webp`
- a **real session with a terminal AND an editor**, not an empty desktop
- the **theme's own wallpaper**
- no cursor, no notification, nothing personal
- don't scale a small capture up

`bin/shoot-theme` builds exactly that, reproducibly, on a workspace it stages
itself — see its header for the three things it had to learn to make a 3840px
capture legible at 1200. **Submitted 2026-08-30 as
[omarchy-site#122](https://github.com/omacom/omarchy-site/pull/122).**

## Channel 1c — awesome-omarchy: blocked, on purpose

[awesome-omarchy](https://github.com/aorumbayev/awesome-omarchy) lists 100+
themes and would be real reach, but its `CONTRIBUTING.md` requires **5+ GitHub
stars** and enforces it in CI (`scripts/check-min-stars.py`). Both repos are at
zero. A PR opened now fails their automated check on arrival, which is not how
you introduce a project to a curated list. Tracked with the invalidation
criterion as [omarchy-td-palette#10](https://github.com/parker-brown-family/omarchy-td-palette/issues/10).

## Channel 2 — the 🎨 widget: marketplace listing

The `brownfamilysports.td-palette` bar widget incubates in omarchy-contrib's
`lab` branch and graduates to its own public repo (marketplace rule: one
plugin, one repo, `manifest.json` at root). Submission mechanics
(<https://omarchyplugins.com/publish.html>):

1. Public GitHub repo, valid `manifest.json` at root (`schemaVersion`, `id`,
   `name`, `version`, `author`, `description`, `kinds`, `entryPoints`),
   README + license, safe install/removal, optional preview (auto-optimized).
2. Validate locally: `omarchy plugin validate` (our lab `bin/verify` is a
   superset of this).
3. Open the submission issue (template form: repo link, category, tags) on
   `HANCORE-linux/omarchy-plugin-marketplace`; automated validation checks
   the current commit, then a maintainer approves.
4. The marketplace validates listings, **not security** — our README's full
   footprint disclosure (runs/reads/writes/network) is the answer to that.

**Shipped 2026-08-29** — the incubation-week gate was cut short on the
owner's call (issue #8: match the marketplace protocol now, not next week).
Live at <https://github.com/parker-brown-family/omarchy-td-palette> (v0.1.0,
tagged + released, graduated with history via `lab/bin/graduate`), installed
on the reference box through the real `omarchy plugin add` path, and
submitted as [marketplace #3330](https://github.com/HANCORE-linux/omarchy-plugin-marketplace/issues/3330).
Two facts the live submission form corrected against this plan: there is
no **Terminal** category (filed under **Appearance**, tags Bar / Hyprland /
Quickshell, with "Terminal" suggested as a new reusable tag), and the
checklist requires removal instructions in the README — it carries them
now. Marketplace plugins are automatically eligible for future
competitions — being listed IS the entry ticket.

## Theme checklist (submitted: 2026-08-30)

- [x] `colors.toml`, `backgrounds/`, `icons.theme`, `preview.png` — and nothing
      that Omarchy generates for itself
- [x] `test/install-e2e` — the REAL `omarchy-theme-install` and
      `omarchy-theme-set` against a sandboxed `HOME`: 20 green, deny list
      included, so a stranger's clone is proven rather than reasoned about
- [x] `preview.png` regenerated from the current build — 282 KB, against a
      stock theme's 350 KB and this repo's own previous 1.5 MB
- [x] `assets/themes/terminal-delight.webp` — 1200x675, 40 KB, terminal +
      editor, this theme's wallpaper, no cursor
- [x] Entry filed alphabetically between Temerald and Terminus
- [x] Both links point at this repository
- [x] CI green: 172 assertions, shellcheck, `td-mcp` byte-compile, and every
      generated frag compiled in both `ANIMATED` states

## Plugin checklist (graduation day: 2026-08-29)

- [x] `bin/graduate td-palette` (own repo, tag, preview)
- [x] `omarchy plugin validate` clean on the graduated repo (exit 0)
- [x] README discloses footprint; LICENSE present; preview.png is a real-bar
      crop — a fuller overlay shot is
      [omarchy-td-palette#1](https://github.com/parker-brown-family/omarchy-td-palette/issues/1)
      (screen locked + screencopy wedged on graduation day)
- [x] `omarchy plugin add <url> --enable` works from scratch in one command
      (proven by replacing the dev-link on the reference box; `plugin
      update` proven too)
- [x] Submission issue — category **Appearance** (no Terminal category
      exists on the live form), tags Bar / Hyprland / Quickshell,
      "Terminal" suggested as a new tag
- [x] Requirements section names `td-tint` (this repo) as the engine

## Sources

- <https://omarchyplugins.com/publish.html> — submission mechanics
- <https://omarchy.org/news/2026/08/the-first-plugin-competition/> — the
  competition + "500 plugins and growing"
- <https://github.com/HANCORE-linux/omarchy-plugin-marketplace> — the registry
- <https://omarchy.org/manual/shell-plugins/> — the plugin contract
- <https://github.com/omacom/omarchy-site> — the themes page, and its
  screenshot brief in the README under "Adding your theme"
- <https://github.com/aorumbayev/awesome-omarchy/blob/main/CONTRIBUTING.md> —
  the 5-star bar and the CI that enforces it
- `$OMARCHY_PATH/default/themed/*.tpl` and `omarchy-theme-set:30`
  (`INSTALLED_THEME_DENIED`) — what a theme must author, and what is generated
  or stripped for it
