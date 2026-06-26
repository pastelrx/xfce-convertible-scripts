# xfce-tablet-scripts

Small utility scripts for running a convertible/2-in-1 laptop comfortably under
**XFCE on X11** — pen annotation, on-screen drawing, and related tablet-mode
quality-of-life fixes.

Built and tested on a **Fujitsu LIFEBOOK U9313X** running **Manjaro XFCE**, but
most of it is generic to any X11 + XFCE setup with a Wacom pen.

## Scripts

### `gromit-toggle.sh`

Smart launcher for [Gromit-MPX](https://github.com/bk138/gromit-mpx), the
on-screen annotation tool. Bind it to a hotkey instead of calling `gromit-mpx`
directly: the first press launches it in drawing mode, and every press after
that toggles drawing on/off — so you never end up with duplicate instances.

```bash
cp scripts/gromit-toggle.sh ~/.local/bin/
chmod +x ~/.local/bin/gromit-toggle.sh
```

Then in `Settings → Keyboard → Application Shortcuts`, add a shortcut (e.g.
`Super+Home`) pointing at `~/.local/bin/gromit-toggle.sh`.

While Gromit-MPX is active, its own hotkeys apply (XFCE remaps them to avoid
conflicts):

| Key          | Action              |
|--------------|---------------------|
| `Home`       | toggle drawing      |
| `Shift+Home` | clear screen        |
| `Ctrl+Home`  | toggle visibility   |
| `End`        | undo last stroke    |
| `Shift+End`  | redo                |

### `gromit-mpx.cfg.example`

A ready-made Gromit-MPX config: cyan pen by default (readable on a dark
background) with the eraser mapped to the pen's side button.

```bash
cp scripts/gromit-mpx.cfg.example ~/.config/gromit-mpx.cfg
# then restart gromit-mpx
```

If the eraser lands on the wrong button, run `xinput test <pen-device-id>` to
find which `Button` number your side button reports and adjust the `[Button2]`
line in the config.

## Requirements

- X11 + XFCE
- `gromit-mpx` (from the AUR on Arch/Manjaro)
- `xorg-xinput` (for checking pen button numbers)

## Install

```bash
git clone https://github.com/pastelrx/xfce-tablet-scripts.git
cd xfce-tablet-scripts
```

Copy the scripts you want into `~/.local/bin/` (make sure it's on your `PATH`)
and the config into `~/.config/`.

## License

MIT — see [LICENSE](LICENSE).
