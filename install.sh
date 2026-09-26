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

# Tint is an Omarchy shell plugin (it sits above windows, not on the wallpaper):
# link it into the shell's plugins, give it a colors file, and enable it.
ln -sfn "$R/tint" ~/.config/omarchy/plugins/p4ulcristian.tint
mkdir -p ~/.config/tint
[ -f ~/.config/tint/colors ] || cp "$R/tint/colors.example" ~/.config/tint/colors
python3 - ~/.config/omarchy/shell.json p4ulcristian.tint <<'PY'
import json, sys
path, plugin = sys.argv[1:]
with open(path) as f:
    cfg = json.load(f)
plugins = cfg.setdefault("plugins", [])
if not any(p.get("id") == plugin for p in plugins):
    plugins.append({"id": plugin})
    with open(path, "w") as f:
        json.dump(cfg, f, indent=2)
        f.write("\n")
PY
omarchy-shell -q shell rescanPlugins
echo "installed: tint (first time: omarchy-restart-shell)"
