// "label ........ value [icon]" — the icon slot is always reserved so values line up.
import QtQuick
import QtQuick.Layouts

RowLayout {
  id: row
  property string label
  property string value
  property color valueColor: Theme.fg
  property string icon: ""
  signal clicked()
  Layout.fillWidth: true
  spacing: 4

  Label { text: row.label; color: Theme.soft }
  Item { Layout.fillWidth: true }
  Label { text: row.value; color: row.valueColor }
  IconButton { text: row.icon || ""; opacity: row.icon ? 1 : 0; enabled: row.icon !== ""; font.pixelSize: 14; onClicked: row.clicked() }
}
