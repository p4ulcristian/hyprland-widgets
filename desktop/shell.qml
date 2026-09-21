// Desktop widgets — Rainmeter-style: one column of sections drawn straight on the wallpaper
// (no card) below every window (Bottom layer), so it only shows where the wallpaper does.
// Sections are the capitalised files next to this one; add one to the column below.
//
// Screen and corner: set WIDGETS_SCREEN / WIDGETS_CORNER in desktop-widget.service.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

ShellRoot {
  id: root

  readonly property string screenName: Quickshell.env("WIDGETS_SCREEN") || "DP-2"
  readonly property string corner: Quickshell.env("WIDGETS_CORNER") || "top-right"

  PanelWindow {
    id: win
    screen: Quickshell.screens.find(s => s.name === root.screenName) || Quickshell.screens[0]
    anchors {
      top: root.corner.indexOf("top") === 0; bottom: root.corner.indexOf("bottom") === 0
      left: root.corner.indexOf("left") > 0; right: root.corner.indexOf("right") > 0
    }
    margins { top: 28; bottom: 28; left: 28; right: 28 }
    implicitWidth: 400
    implicitHeight: col.implicitHeight + 32
    color: "transparent"
    WlrLayershell.namespace: "desktop-widget"
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    ColumnLayout {
      id: col
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
      spacing: 44

      Drives {}
      Internet {}
      Devices {}
    }
  }
}
