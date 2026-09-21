// Wireless devices and their batteries: every paired Bluetooth device, plus what hangs off the
// Logitech receiver and the headset dongle (read by bin/device-batteries every 5 minutes).
// Clicking a Bluetooth device connects or disconnects it; the header icon switches Bluetooth on/off.
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: root
  spacing: 18

  // Display names, by the name the device reports (without any "Someone's " in front).
  readonly property var names: ({
    "Magic Trackpad": "Trackpad",
    "Xbox Wireless Controller": "Xbox Controller",
    "MX Keys Mini": "Keyboard",
    "MX Master 3S": "Mouse",
    "Arctis 7X+": "Headset",
  })
  readonly property var icons: ({
    keyboard: "", mouse: String.fromCodePoint(0xF037D), trackpad: String.fromCodePoint(0xF07F8),
    gamepad: "", headset: "", other: "",
  })
  function btKind(icon) {
    return icon === "input-tablet" ? "trackpad" : icon === "input-gaming" ? "gamepad" : icon === "input-keyboard" ? "keyboard"
         : icon === "input-mouse" ? "mouse" : icon.indexOf("audio") === 0 ? "headset" : "other"
  }
  function levelColor(p) { return p <= 15 ? Theme.red : p <= 30 ? Theme.yellow : Theme.accent }

  readonly property var adapter: Bluetooth.defaultAdapter
  property var dongles: []

  // Apple devices report battery through the input driver, which only UPower sees: match by address.
  function upowerLevel(address) {
    const mac = address.toLowerCase()
    const d = UPower.devices.values.find(d => d.nativePath.toLowerCase().indexOf(mac) >= 0)
    return d ? d.percentage * 100 : -1
  }

  readonly property var rows: {
    const list = []
    for (const d of (adapter ? adapter.devices.values : [])) {
      if (!d.paired) continue
      const level = d.batteryAvailable ? d.battery * 100 : d.connected ? upowerLevel(d.address) : -1
      const model = d.name.replace(/^.*[’']s /, "")  // "Paul's Magic Trackpad" -> "Magic Trackpad"
      list.push({ name: names[model] || model, model: model, via: "Bluetooth",
                  kind: btKind(d.icon), online: d.connected, battery: level, charging: false, bt: d })
    }
    for (const d of dongles)
      list.push({ name: names[d.name] || d.name, model: d.name, via: d.via, kind: d.kind, online: d.online,
                  battery: d.battery == null ? -1 : d.battery, charging: d.charging, bt: null })
    // On first, then by name, so the list does not jump around.
    list.sort((a, b) => (b.online - a.online) || a.name.localeCompare(b.name))
    return list
  }

  Process {
    id: helper
    running: true
    command: [Quickshell.shellDir + "/bin/device-batteries"]
    stdout: StdioCollector { onStreamFinished: { try { root.dongles = JSON.parse(text) } catch (e) {} } }
  }
  Timer { interval: 300000; running: true; repeat: true; onTriggered: helper.running = true }

  RowLayout {
    Layout.fillWidth: true
    SectionHeader { text: "DEVICES" }
    Item { Layout.fillWidth: true }
    Label { text: root.adapter && root.adapter.enabled ? "Bluetooth on" : "Bluetooth off"; color: Theme.soft; font.pixelSize: 12 }
    IconButton {
      text: ""
      idle: root.adapter && root.adapter.enabled ? Theme.accent : Theme.soft
      onClicked: Quickshell.execDetached(["omarchy-bluetooth-power", root.adapter && root.adapter.enabled ? "off" : "on"])
    }
  }

  Repeater {
    model: root.rows
    delegate: Item {
      id: row
      required property var modelData
      readonly property bool hasLevel: modelData.online && modelData.battery >= 0
      readonly property bool busy: !!modelData.bt && modelData.bt.state !== BluetoothDeviceState.Connected
                                   && modelData.bt.state !== BluetoothDeviceState.Disconnected
      Layout.fillWidth: true
      implicitHeight: body.implicitHeight
      opacity: modelData.online ? 1 : 0.6

      ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right }
        spacing: 4

        RowLayout {
          Layout.fillWidth: true
          spacing: 10
          Label {
            text: root.icons[row.modelData.kind] || root.icons.other
            color: nameMouse.containsMouse ? Theme.accent : Theme.fg
            font.pixelSize: 18
          }
          Label {
            text: row.modelData.name
            color: nameMouse.containsMouse ? Theme.accent : Theme.fg
            font.pixelSize: 18; font.bold: true
          }
          Item { Layout.fillWidth: true }
          Label {
            text: row.hasLevel ? (row.modelData.charging ? " " : "") + Math.round(row.modelData.battery) + "%" : ""
            color: root.levelColor(row.modelData.battery)
            font.pixelSize: 18; font.bold: true
          }
        }

        Label {
          Layout.fillWidth: true
          elide: Text.ElideRight
          color: Theme.soft
          text: row.modelData.model + " · " + row.modelData.via + " · "
                + (row.busy ? "connecting…" : row.modelData.online ? "connected" : "off")
        }

        Meter {
          Layout.fillWidth: true; Layout.topMargin: 2
          visible: row.hasLevel
          pct: row.modelData.battery; fill: root.levelColor(row.modelData.battery)
        }
      }

      // Only Bluetooth devices can be connected from here; the rest switch themselves on.
      MouseArea {
        id: nameMouse
        anchors.fill: parent
        enabled: !!row.modelData.bt; hoverEnabled: enabled
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: row.modelData.bt.connected ? row.modelData.bt.disconnect() : row.modelData.bt.connect()
      }
    }
  }

  Label { visible: root.rows.length === 0; text: "no devices"; color: Theme.soft }
}
