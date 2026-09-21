# hyprland-widgets

Rainmeter-style desktop widgets for Hyprland, written in QML for [Quickshell](https://quickshell.org).
They draw straight on the wallpaper, below every window.

`desktop/` is one column of sections, stacked in one window so they can sit under each other:

| Section | Shows |
|---|---|
| `Drives.qml` | One row per mounted drive: name, disk model, fill bar, free space. Icons open the drive in the file manager or a terminal. |
| `Internet.qml` | Online/offline from a real ping, live download and upload speed with a 60-second graph, local / router / public address, link speed, WireGuard tunnel. |
| `Devices.qml` | Paired Bluetooth devices plus Logitech-receiver and headset-dongle devices, with battery levels. Click a Bluetooth device to connect or disconnect it. |

`Theme.qml`, `Label.qml`, `Meter.qml` and friends are the shared look. Device batteries that are not
Bluetooth come from `desktop/bin/device-batteries`, which needs the `solaar` and `headsetcontrol` packages.

## Install

    ./install.sh

Symlinks each widget folder into `~/.config/quickshell/<name>-widget` and its service into
`~/.config/systemd/user/`, then enables and restarts it. Safe to re-run.

## Settings

Screen and corner are environment variables in the widget's `.service` file
(`WIDGETS_SCREEN`, `WIDGETS_CORNER`); after changing them run
`systemctl --user daemon-reload && systemctl --user restart desktop-widget`.
Everything else (display names, ping targets) is at the top of each section's `.qml`, which reloads on save.

## Adding a section

Write `desktop/<Name>.qml` (a `ColumnLayout` starting with a `SectionHeader`) and add `<Name> {}` to the
column in `desktop/shell.qml`. A separate window elsewhere on screen is a new folder with its own
`shell.qml` and `<name>-widget.service`; `./install.sh` picks it up.

## Licence

MIT — see [LICENSE](LICENSE).
