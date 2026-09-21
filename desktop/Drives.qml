// One row per mounted drive: name, disk model, fill bar, path and free space.
// Reads `df` (and `lsblk` for the disk model) every 30 s. The name, path and folder icon open
// the drive in the file manager; the prompt icon opens a terminal there.
import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: root
  spacing: 22

  // Display names, by mount point. Anything not listed shows the last part of its path.
  readonly property var names: ({
    "/": "Linux & Home",
    "/mnt/fast": "Work & Models",
    "/mnt/games": "Steam Library",
    "/mnt/store": "Media & Archive",
  })
  function label(mount) { return names[mount] || mount.split("/").pop() }

  property var drives: []
  property var models: ({})  // device path -> model of the physical disk under it
  function pctColor(p) { return p >= 90 ? Theme.red : p >= 75 ? Theme.yellow : Theme.accent }

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

  // lsblk nests partitions and encrypted volumes under their disk; give them all the disk's model.
  function parseModels(out) {
    const m = {}
    const walk = (n, model) => { m[n.name] = model; for (const k of n.children || []) walk(k, model) }
    try { for (const d of JSON.parse(out).blockdevices) walk(d, (d.model || "").trim()) } catch (e) {}
    models = m
  }

  Process {
    id: df
    command: ["df", "-B1", "--output=source,size,used,avail,target",
              "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.parse(text) }
  }
  Process {
    id: lsblk
    command: ["lsblk", "-J", "-p", "-o", "NAME,MODEL"]
    running: true
    stdout: StdioCollector { onStreamFinished: root.parseModels(text) }
  }
  Timer { interval: 30000; running: true; repeat: true; onTriggered: { df.running = true; lsblk.running = true } }

  SectionHeader { text: "DRIVES" }

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
          color: row.hot ? Theme.accent : Theme.fg
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
        color: Theme.soft
      }

      Meter {
        Layout.fillWidth: true; Layout.topMargin: 2; Layout.bottomMargin: 2
        pct: row.modelData.pct; fill: root.pctColor(row.modelData.pct)
      }

      RowLayout {
        Layout.fillWidth: true
        Label {
          text: row.modelData.mount
          color: row.hot ? Theme.accent : Theme.soft
          font.underline: row.hot
          MouseArea { id: pathMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: row.open() }
        }
        IconButton { text: ""; Layout.leftMargin: 8; onClicked: row.open() }   // folder -> file manager
        IconButton { text: ""; onClicked: row.term() }                         // prompt -> terminal here
        Item { Layout.fillWidth: true }
        Label { text: Theme.size(row.modelData.free) + " free of " + Theme.size(row.modelData.total) }
      }
    }
  }

  Label { visible: root.drives.length === 0; text: "no drives found"; color: Theme.soft }
}
