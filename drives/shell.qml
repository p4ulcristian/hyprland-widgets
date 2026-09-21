// Drives widget — Rainmeter-style: one row per mounted drive with a fill bar, drawn straight on
// the wallpaper (no card) below every window (Bottom layer), so it only shows where the wallpaper
// does. Reads `df` (and `lsblk` for the disk model) every 30 s. Clicking a drive's name, path or
// folder icon opens it in the file manager; the prompt icon opens a terminal there.
//
// Screen and corner: set DRIVES_WIDGET_SCREEN / DRIVES_WIDGET_CORNER in drives-widget.service.
// Display names: the `names` table below.
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

ShellRoot {
  id: root

  readonly property string home: Quickshell.env("HOME")
  readonly property string screenName: Quickshell.env("DRIVES_WIDGET_SCREEN") || "DP-1"
  readonly property string corner: Quickshell.env("DRIVES_WIDGET_CORNER") || "top-right"
  property var drives: []
  property var models: ({})  // device path -> model of the physical disk under it
  property var theme: ({})

  function c(key, fallback) { return theme[key] || fallback }
  readonly property color fg: c("foreground", "#dcd7ba")
  readonly property color red: c("red", "#c34043")
  readonly property color yellow: c("yellow", "#c0a36e")
  readonly property color accent: c("accent", "#7e9cd8")
  readonly property color soft: Qt.rgba(fg.r, fg.g, fg.b, 0.8)
  readonly property color shadow: Qt.rgba(0, 0, 0, 0.7)
  readonly property string mono: "JetBrainsMono Nerd Font"

  function pctColor(p) { return p >= 90 ? red : p >= 75 ? yellow : accent }
  function size(n) {
    const u = ["B", "K", "M", "G", "T", "P"]
    let i = 0
    while (n >= 1024 && i < u.length - 1) { n /= 1024; i++ }
    return (n >= 100 || i === 0 ? Math.round(n) : n.toFixed(1)) + u[i]
  }
  // Display names, by mount point. Anything not listed shows the last part of its path.
  readonly property var names: ({
    "/": "Linux & Home",
    "/mnt/fast": "Work & Models",
    "/mnt/games": "Steam Library",
    "/mnt/store": "Media & Archive",
  })
  function label(mount) { return names[mount] || mount.split("/").pop() }

  // One row per device: btrfs subvolumes repeat the same source, keep the shortest mount point.
  function parse(out) {
    const by = {}
    for (const l of out.trim().split("\n").slice(1)) {
      const m = l.match(/^(\S+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+)$/)
      if (!m || m[5].indexOf("/boot") === 0) continue
      const d = { dev: m[1], total: +m[2], used: +m[3], free: +m[4], mount: m[5] }
      if (!by[d.dev] || d.mount.length < by[d.dev].mount.length) by[d.dev] = d
    }
    const list = Object.values(by)
    for (const d of list) d.pct = d.used + d.free > 0 ? 100 * d.used / (d.used + d.free) : 0
    list.sort((a, b) => a.mount === "/" ? -1 : b.mount === "/" ? 1 : a.mount.localeCompare(b.mount))
    drives = list
  }

  Process {
    id: df
    command: ["df", "-B1", "--output=source,size,used,avail,target",
              "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.parse(text) }
  }
  // lsblk nests partitions and encrypted volumes under their disk; give them all the disk's model.
  function parseModels(out) {
    const m = {}
    const walk = (n, model) => { m[n.name] = model; for (const k of n.children || []) walk(k, model) }
    try { for (const d of JSON.parse(out).blockdevices) walk(d, (d.model || "").trim()) } catch (e) {}
    models = m
  }
  Process {
    id: lsblk
    command: ["lsblk", "-J", "-p", "-o", "NAME,MODEL"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.parseModels(text) }
  }
  Timer { interval: 30000; running: true; repeat: true; onTriggered: { df.running = true; lsblk.running = true } }

  // All widget text: outlined so it reads on any wallpaper.
  component Label: Text { style: Text.Outline; styleColor: root.shadow; font.family: root.mono }

  // A Nerd Font glyph that lights up on hover and takes a click.
  component IconButton: Label {
    id: icon
    signal clicked()
    color: iconMouse.containsMouse ? root.accent : root.soft
    font.pixelSize: 16
    leftPadding: 4; rightPadding: 4
    MouseArea { id: iconMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: icon.clicked() }
  }

  FileView {
    path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
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

  PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === root.screenName) || Quickshell.screens[0]
    anchors {
      top: root.corner.indexOf("top") === 0; bottom: root.corner.indexOf("bottom") === 0
      left: root.corner.indexOf("left") > 0; right: root.corner.indexOf("right") > 0
    }
    margins { top: 28; bottom: 28; left: 28; right: 28 }
    implicitWidth: 360
    implicitHeight: card.implicitHeight
    color: "transparent"
    WlrLayershell.namespace: "drives-widget"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Rectangle {
      id: card
      width: win.implicitWidth
      implicitHeight: col.implicitHeight + 32
      color: "transparent"

      ColumnLayout {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
        spacing: 22

        Repeater {
          model: root.drives
          delegate: ColumnLayout {
            id: row
            required property var modelData
            readonly property bool hot: nameMouse.containsMouse || pathMouse.containsMouse
            function open() { Quickshell.execDetached(["xdg-open", row.modelData.mount]) }
            function term() { Quickshell.execDetached(["xdg-terminal-exec", "--dir=" + row.modelData.mount]) }
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
              Layout.fillWidth: true
              Label {
                text: root.label(row.modelData.mount)
                color: row.hot ? root.accent : root.fg
                font.pixelSize: 18; font.bold: true
                MouseArea { id: nameMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.open() }
              }
              Item { Layout.fillWidth: true }
              Label {
                text: Math.round(row.modelData.pct) + "%"
                color: root.pctColor(row.modelData.pct)
                font.pixelSize: 18; font.bold: true
              }
            }

            Label {
              Layout.fillWidth: true
              visible: text !== ""
              text: root.models[row.modelData.dev] || ""; elide: Text.ElideRight
              color: root.soft; font.pixelSize: 13
            }

            Rectangle {
              Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 2
              height: 8; radius: 4
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.25)
              border.width: 1; border.color: root.shadow
              Rectangle {
                width: Math.max(parent.height, parent.width * row.modelData.pct / 100)
                height: parent.height; radius: 4
                color: root.pctColor(row.modelData.pct)
                Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              Label {
                text: row.modelData.mount
                color: row.hot ? root.accent : root.soft
                font.pixelSize: 13; font.underline: row.hot
                MouseArea { id: pathMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.open() }
              }
              IconButton { text: "\uf07c"; Layout.leftMargin: 8; onClicked: row.open() }   // folder -> file manager
              IconButton { text: "\uf489"; onClicked: row.term() }                         // prompt -> terminal here
              Item { Layout.fillWidth: true }
              Label {
                text: root.size(row.modelData.free) + " free of " + root.size(row.modelData.total)
                color: root.fg; font.pixelSize: 13
              }
            }
          }
        }

        Text {
          visible: root.drives.length === 0
          text: "no drives found"; color: root.soft; style: Text.Outline; styleColor: root.shadow; font.family: root.mono; font.pixelSize: 13
        }
      }
    }
  }
}
