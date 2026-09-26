import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Tint: a small dot in the top-right corner of every foot window on screen.
// Click it and a row of colors slides out; pick one and that terminal's
// background changes (tint-set writes the color escape into its terminal).
// The last circle resets to the theme. Colors come from ~/.config/tint/colors.
//
// Each dot is its own little layer surface placed over its window, so nothing
// else on screen takes clicks. Window positions come from hyprctl: at once on
// Hyprland events, and every few hundred ms to follow drags and resizes.
Item {
  id: root

  readonly property int dot: 30
  readonly property int swatch: 46
  readonly property int inset: 8               // from the window's top-right corner
  readonly property string colorsPath: Quickshell.env("HOME") + "/.config/tint/colors"
  readonly property string helper: Qt.resolvedUrl("tint-set").toString().replace("file://", "")
  readonly property var defaults: ["#1e2233", "#2a1f33", "#331f2a", "#33261a", "#2c2e1a",
                                   "#1c2e22", "#1a2e2e", "#1a2633", "#2b2b2b", "#3a1818"]

  property var palette: defaults
  property var windows: ({})       // address -> { pid, x, y, w, h, screen }
  property var shown: []           // addresses of foot windows on screen, for the Variants
  property var tints: ({})         // address -> the color set on it (none = theme)
  property string open: ""         // address whose row is out

  function parseColors(text) {
    var out = []
    var lines = text.split("\n")
    for (var i = 0; i < lines.length && out.length < 10; i++) {
      var m = lines[i].trim().match(/^#?([0-9a-fA-F]{6})$/)
      if (m) out.push("#" + m[1].toLowerCase())
    }
    return out.length > 0 ? out : defaults
  }

  function screenFor(monitorId) {
    var mons = Hyprland.monitors.values
    for (var i = 0; i < mons.length; i++) {
      if (mons[i].id !== monitorId) continue
      var screens = Quickshell.screens
      for (var j = 0; j < screens.length; j++)
        if (screens[j].name === mons[i].name)
          return { screen: screens[j], workspace: mons[i].activeWorkspace ? mons[i].activeWorkspace.id : -1 }
    }
    return null
  }

  function update(json) {
    var clients
    try { clients = JSON.parse(json) } catch (e) { return }
    var windows = {}
    var shown = []
    for (var i = 0; i < clients.length; i++) {
      var c = clients[i]
      if (c.class !== "foot" || !c.mapped || c.hidden || c.fullscreen > 0) continue
      var where = screenFor(c.monitor)
      if (!where || c.workspace.id !== where.workspace) continue
      windows[c.address] = { pid: c.pid, x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1], screen: where.screen }
      shown.push(c.address)
    }
    // Forget windows that closed.
    var tints = {}
    for (var b in root.tints) if (clients.some(x => x.address === b)) tints[b] = root.tints[b]
    root.tints = tints
    if (root.open !== "" && !(root.open in windows)) root.open = ""
    root.windows = windows
    if (JSON.stringify(shown) !== JSON.stringify(root.shown)) root.shown = shown
  }

  function apply(address, color) {
    var w = root.windows[address]
    if (!w) return
    Quickshell.execDetached([root.helper, String(w.pid), color || "reset"])
    var tints = Object.assign({}, root.tints)
    if (color) tints[address] = color
    else delete tints[address]
    root.tints = tints
    root.open = ""
  }

  FileView {
    path: root.colorsPath
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.palette = root.parseColors(text())
    onLoadFailed: root.palette = root.defaults
  }

  Process {
    id: poll
    command: ["hyprctl", "-j", "clients"]
    stdout: StdioCollector { onStreamFinished: root.update(text) }
  }

  function refresh() { if (!poll.running) poll.running = true }

  Timer {
    interval: 300
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.refresh() }
  }

  Timer {
    id: autoClose
    interval: 6000
    onTriggered: root.open = ""
  }

  Variants {
    model: root.shown

    PanelWindow {
      id: pill
      required property string modelData
      readonly property var win: root.windows[modelData] || null
      readonly property bool expanded: root.open === modelData
      readonly property string current: root.tints[modelData] || ""

      visible: win !== null
      screen: win ? win.screen : null
      anchors { top: true; left: true }
      margins.top: win ? win.y - win.screen.y + root.inset : 0
      margins.left: win ? win.x + win.w - win.screen.x - root.inset - implicitWidth : 0
      implicitWidth: expanded ? row.implicitWidth + 16 : root.dot + 8
      implicitHeight: expanded ? root.swatch + 16 : root.dot + 8
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      WlrLayershell.namespace: "tint"
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

      // Collapsed: one dot in the window's current color.
      Rectangle {
        visible: !pill.expanded
        anchors.centerIn: parent
        width: root.dot
        height: root.dot
        radius: width / 2
        color: pill.current || Color.background
        border.width: 2
        border.color: Util.alpha(Color.foreground, dotArea.containsMouse ? 1 : 0.75)
        scale: dotArea.containsMouse ? 1.25 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }

        MouseArea {
          id: dotArea
          anchors.fill: parent
          anchors.margins: -4
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.open = pill.modelData
            autoClose.restart()
          }
        }
      }

      // Expanded: the row of colors, reset last.
      Rectangle {
        visible: pill.expanded
        anchors.fill: parent
        radius: height / 2
        color: Util.alpha(Color.popups.background, 0.92)
        border.width: 1
        border.color: Util.alpha(Color.popups.border, 0.6)

        focus: pill.expanded
        Keys.onEscapePressed: root.open = ""

        HoverHandler { onHoveredChanged: if (hovered) autoClose.stop(); else autoClose.restart() }

        Row {
          id: row
          anchors.centerIn: parent
          spacing: 10

          Repeater {
            model: root.palette.concat([""])      // "" = reset to theme

            Rectangle {
              id: sw
              required property string modelData
              readonly property bool isReset: modelData === ""
              readonly property bool isCurrent: modelData === pill.current
              width: root.swatch
              height: root.swatch
              radius: width / 2
              color: isReset ? Color.background : modelData
              border.width: isCurrent ? 3 : 1
              border.color: isCurrent ? Color.foreground : Util.alpha(Color.foreground, 0.35)
              scale: area.containsMouse ? 1.18 : 1
              Behavior on scale { NumberAnimation { duration: 90 } }

              // Reset: a slash through the theme color.
              Rectangle {
                visible: sw.isReset
                anchors.centerIn: parent
                width: parent.width * 0.7
                height: 2
                rotation: -45
                color: Util.alpha(Color.foreground, 0.7)
              }

              MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.apply(pill.modelData, sw.modelData)
              }
            }
          }
        }
      }
    }
  }
}
