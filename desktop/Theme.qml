// Shared look: colours follow the Omarchy theme, plus the few formatters every section uses.
pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
  id: root

  property var theme: ({})
  function c(key, fallback) { return theme[key] || fallback }
  readonly property color fg: c("foreground", "#dcd7ba")
  readonly property color soft: Qt.rgba(fg.r, fg.g, fg.b, 0.8)
  readonly property color track: Qt.rgba(fg.r, fg.g, fg.b, 0.25)
  readonly property color shadow: Qt.rgba(0, 0, 0, 0.7)
  readonly property color red: c("red", "#c34043")
  readonly property color yellow: c("yellow", "#c0a36e")
  readonly property color green: c("green", "#76946a")
  readonly property color accent: c("accent", "#7e9cd8")
  readonly property string mono: "JetBrainsMono Nerd Font"

  function size(n) {
    const u = ["B", "K", "M", "G", "T", "P"]
    let i = 0
    while (n >= 1024 && i < u.length - 1) { n /= 1024; i++ }
    return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)) + u[i]
  }

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      const t = {}
      for (const l of text().split("\n")) {
        const m = l.match(/^\s*([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6})"/)
        if (m) t[m[1]] = m[2]
      }
      root.theme = t
    }
  }
}
