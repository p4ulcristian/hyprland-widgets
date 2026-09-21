# hyprland-widgets

Rainmeter-style desktop widgets for Hyprland, written in QML for [Quickshell](https://quickshell.org).
They draw straight on the wallpaper, below every window.

| Widget | Shows |
|---|---|
| `drives/` | One row per mounted drive: name, disk model, fill bar, free space. Icons open the drive in the file manager or a terminal. |

## Install

    ./install.sh

Symlinks each widget folder into `~/.config/quickshell/<name>-widget` and its service into
`~/.config/systemd/user/`, then enables and restarts it. Safe to re-run.

## Settings

Screen and corner are environment variables in the widget's `.service` file
(`DRIVES_WIDGET_SCREEN`, `DRIVES_WIDGET_CORNER`); after changing them run
`systemctl --user daemon-reload && systemctl --user restart drives-widget`.
Everything else is in the widget's `shell.qml`, which reloads on save.

## Adding a widget

Make a folder with a `shell.qml` and a `<name>-widget.service` whose `ExecStart` is
`/usr/bin/qs -c <name>-widget`, then run `./install.sh`.
