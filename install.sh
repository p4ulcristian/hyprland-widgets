#!/usr/bin/env bash
# Link every widget into place (idempotent) and (re)start its service.
# A widget is a folder holding shell.qml and <name>-widget.service.
set -euo pipefail
R="$(cd "$(dirname "$0")" && pwd)"

mkdir -p ~/.config/quickshell ~/.config/systemd/user
units=()
for svc in "$R"/*/*-widget.service; do
  unit="$(basename "$svc")"
  ln -sfn "$(dirname "$svc")" ~/.config/quickshell/"${unit%.service}"
  ln -sfn "$svc"              ~/.config/systemd/user/"$unit"
  units+=("$unit")
done

systemctl --user daemon-reload
systemctl --user enable "${units[@]}"
systemctl --user restart "${units[@]}"
echo "installed: ${units[*]}"
