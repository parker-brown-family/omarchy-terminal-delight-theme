# Where these backgrounds came from

Thirteen of the fourteen are Omarchy's own theme art, not ours. They ship here
because Terminal Delight is an Omarchy theme and its wallpaper switcher needs
somewhere to cycle — not because we drew any of them.

Source: [Omarchy](https://github.com/basecamp/omarchy), MIT licensed, the tree
as of 2026-08-27. Copied byte-for-byte; nothing was recoloured, cropped, or
re-encoded, so each file is still exactly what its theme ships.

| File | Omarchy theme it belongs to |
|---|---|
| `00-osaka-jade-shaded-entrance.webp` | Osaka Jade — **the default** |
| `01-ethereal-meadow.webp` | Ethereal |
| `02-gruvbox-idyllic-procession.jpg` | Gruvbox |
| `03-kanagawa.jpg` | Kanagawa |
| `04-last-horizon-new-horizons.jpg` | Last Horizon |
| `05-matte-black-ship-at-sea.jpg` | Matte Black |
| `06-nord-night-hawks.webp` | Nord |
| `07-retro-82-dusk-guardian.webp` | Retro 82 |
| `08-ristretto-coffee-beans.jpg` | Ristretto |
| `09-ristretto-industrial-moon.webp` | Ristretto |
| `10-solitude-climb.jpg` | Solitude |
| `11-tokyo-night-swirl-buck.webp` | Tokyo Night |
| `12-tokyo-night-omakub.webp` | Tokyo Night |
| `13-void-tube.jpg` | Terminal Delight's own |

## Why the numbers, and why they are two digits

`omarchy-theme-bg-next` sorts the directory and takes the first file when no
background is currently linked, so **filename order is the default**. Two digits
throughout, because a single-digit set puts `10-` ahead of `2-`.

`13-void-tube.jpg` is the one file with a second job: `bin/build-variants`
reads it by name as the base image it tints per palette variant. Renaming it
means editing that line too.
