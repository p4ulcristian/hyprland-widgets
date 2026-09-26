# hyprland-widgets

Rainmeter-style desktop widgets for Hyprland, written in QML for [Quickshell](https://quickshell.org).
They draw straight on the wallpaper, below every window.

`desktop/` is two columns of sections on one screen: System on the left, the rest on the right.

| Section | Shows |
|---|---|
| `System.qml` | Processor, memory and graphics card: usage bar, what each one is (CPU model, RAM type and speed, GPU name), clock, temperature, VRAM and power. Read by `desktop/bin/system-stats` every 2 s. |
| `Drives.qml` | One row per mounted drive: name, disk model, fill bar, free space. Icons open the drive in the file manager or a terminal. |
| `Internet.qml` | Online/offline from a real ping, live download and upload speed with a 60-second graph, local / router / public address, link speed, WireGuard tunnel. |
| `Monitors.qml` | Every connected display with its resolution, refresh rate and scale. The power icon switches one on or off (`desktop/bin/monitor-power`); the last one on stays on. |
| `Devices.qml` | Paired Bluetooth devices plus Logitech-receiver and headset-dongle devices, with battery levels. Click a Bluetooth device to connect or disconnect it. |

`Theme.qml`, `Label.qml`, `Meter.qml` and friends are the shared look. Device batteries that are not
Bluetooth come from `desktop/bin/device-batteries`, which needs the `solaar` and `headsetcontrol` packages.

## Install

    ./install.sh

Symlinks each widget folder into `~/.config/quickshell/<name>-widget` and its service into
`~/.config/systemd/user/`, then enables and restarts it. Safe to re-run.

## Settings

Screen and corner are environment variables in the widget's `.service` file
(`WIDGETS_SCREEN`, `WIDGETS_CORNER` for the main column, `WIDGETS_SYSTEM_CORNER` for System); after changing them run
`systemctl --user daemon-reload && systemctl --user restart desktop-widget`.
Everything else (display names, ping targets) is at the top of each section's `.qml`, which reloads on save.

## Adding a section

Write `desktop/<Name>.qml` (a `ColumnLayout` starting with a `SectionHeader`) and add `<Name> {}` to a
`Corner` in `desktop/shell.qml`. A separate window elsewhere on screen is a new folder with its own
`shell.qml` and `<name>-widget.service`; `./install.sh` picks it up.

## Licence

MIT — see [LICENSE](LICENSE).

## Tint

`tint/` is different from the widgets above: an Omarchy shell plugin that sits *above* windows.
Every foot window on screen gets a small dot in its top-right corner. Click it and a row of
colors opens; pick one and that terminal's background changes. The crossed-out circle at the
end resets it to the theme. The row closes after a pick, on Escape, or after 6 s untouched.

- Colors: `~/.config/tint/colors`, up to 10 `#rrggbb` lines (starts as a copy of
  `tint/colors.example`). Edits show the next time a row opens.
- A color lasts until you change it or the window closes; nothing is kept across restarts.
- Only foot, one process per window (`foot`, not `footclient`): `tint/tint-set` finds the
  window's terminal through its process and writes the background color escape into it.
- `install.sh` links it into `~/.config/omarchy/plugins/p4ulcristian.tint` and enables it;
  run `omarchy-restart-shell` the first time so the shell loads it.
