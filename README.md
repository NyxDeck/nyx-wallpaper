# Nyx Wallpaper (DMS)

A bar widget and panel for wallpapers — both the still ones DMS natively knows
and the live ones it does not.

## What it does

- **Browse what is on disk.** Three tabs (`All` / `Static` / `Live`) and a
  second row of chips for the subfolders the files live in, so a library keeps
  whatever structure you gave it.
- **Apply either kind.** A still image goes to DMS' wallpaper IPC; a video goes
  to `mpvpaper`, with a still frame handed to DMS so the Material You palette
  still tracks what you are looking at.
- **Download collections without leaving the shell.** The `Sources` tab lists
  the configured wallpaper collections, shows which ones you already have, and
  fetches the rest. Nothing is downloaded until you press the button.

## Requirements

`mpvpaper` (live wallpapers), `ffmpeg` (the still frame for the palette), `git`
(downloads), and the `nyxdeck` command, which owns the whole wallpaper chain.

This plugin is the front end; `nyxdeck wallpaper` is the implementation. That is
deliberate — the GTK picker on `Mod+W`, this panel and the CLI all drive the
same code, so none of them can disagree about how a wallpaper is applied.

## Relationship to DMS' own picker

DMS' bar picker and its cycling only list still images, and neither knows about
`mpvpaper`. If one of them sets a wallpaper while a video is playing, the video
stays on top and the palette is taken from a picture nobody can see. This
plugin watches the same wallpaper state DMS does: when something *else* changes
it, the live layer is dropped so the new choice is actually visible. That can be
turned off in the settings.

## Keybinds and IPC

```
dms ipc call nyxWallpaper apply /path/to/wallpaper.webm
dms ipc call nyxWallpaper next
dms ipc call nyxWallpaper nextVideo
dms ipc call nyxWallpaper refresh
```

## License

MIT. See [LICENSE](LICENSE).
