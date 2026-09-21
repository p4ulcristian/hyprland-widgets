// The fill bar: drive usage, battery level.
import QtQuick

Rectangle {
  id: meter
  property real pct: 0
  property color fill: Theme.accent
  implicitHeight: 8; radius: 4
  color: Theme.track
  border.width: 1; border.color: Theme.shadow
  Rectangle {
    width: Math.max(parent.height, parent.width * Math.min(100, meter.pct) / 100)
    height: parent.height; radius: 4
    color: meter.fill
    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
  }
}
