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

## Channel 1 — this repo (the theme + engine): shipping NOW

Users install the theme straight from the public repo (see README), which
brings the 11 variants, the curve + per-tile glare, the monitor pass,
`td-tint`/`td-monitor`/`td-mcp` and the self-healing hook. Released as
**v0.1.0** with a gallery. Optional reach: a PR to
[awesome-omarchy](https://github.com/aorumbayev/awesome-omarchy).

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

**Gate:** the lab's incubation-week doctrine (daily use since 2026-08-28).
Submission target: **on or after 2026-09-04**, via `lab/bin/graduate
td-palette` → repo `parker-brown-family/omarchy-td-palette` → submission
issue. Marketplace plugins are automatically eligible for future
competitions — being listed IS the entry ticket.

## Ready-to-submit checklist (graduation day)

- [ ] `bin/graduate td-palette` (own repo, tag, preview)
- [ ] `omarchy plugin validate` clean on the graduated repo
- [ ] README discloses footprint; LICENSE present; preview.png is the real bar
- [ ] `omarchy plugin add <url> --enable` works from scratch in one command
- [ ] Submission issue with category (Terminal) + tags (theme, terminal,
      terminal-delight, paint)
- [ ] Requirements section names `td-tint` (this repo) as the engine

## Sources

- <https://omarchyplugins.com/publish.html> — submission mechanics
- <https://omarchy.org/news/2026/08/the-first-plugin-competition/> — the
  competition + "500 plugins and growing"
- <https://github.com/HANCORE-linux/omarchy-plugin-marketplace> — the registry
- <https://omarchy.org/manual/shell-plugins/> — the plugin contract
