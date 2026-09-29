# Nyx Wallpaper (DMS)

A bar widget for the parts of wallpaper handling nothing else in the shell can
do.

## What it is, and what it is not

Browsing wallpapers is already solved twice: DMS ships a picker and a cycler for
still images, and this desktop ships the GTK picker on `Mod+W`, which handles
still *and* live video wallpapers with categories and search. This plugin does
not repeat either of them. It holds the three things that were missing:

- **Reachable from the bar** — the current wallpaper, one-click *next* and *next
  live*, and a button that opens the picker for real browsing.
- **The download chain** — the collections `nyxdeck wallpaper` knows about, what
  is already on disk, and a Download button. Nothing is fetched until you press
  it.
- **The mpvpaper conflict** — DMS' own picker and its cycling only list still
  images, and neither knows about `mpvpaper`. If one of them sets a wallpaper
  while a video is playing, the video stays on top and the palette is taken from
  a picture nobody can see. The daemon watches the same wallpaper state DMS does
  and drops the live layer when somebody *else* made the choice. It can be turned
  off in the settings.

## Requirements

`mpvpaper` (live wallpapers), `ffmpeg` (the still frame the palette is taken
from), `git` (downloads), and the `nyxdeck` command, which owns the whole
wallpaper chain.

This plugin is the front end; `nyxdeck wallpaper` is the implementation. The GTK
picker, this panel and the CLI all drive the same code, so none of them can
disagree about how a wallpaper is applied.

## Keybinds and IPC

```
dms ipc call nyxWallpaper apply /path/to/wallpaper.webm
dms ipc call nyxWallpaper next
dms ipc call nyxWallpaper nextVideo
dms ipc call nyxWallpaper refresh
dms ipc call nyxWallpaper status
```

## License

MIT. See [LICENSE](LICENSE).
