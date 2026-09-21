// A Nerd Font glyph that lights up on hover and takes a click.
import QtQuick

Label {
  id: icon
  signal clicked()
  property color idle: Theme.soft
  color: mouse.containsMouse ? Theme.accent : idle
  font.pixelSize: 16
  leftPadding: 4; rightPadding: 4
  MouseArea { id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: icon.clicked() }
}
