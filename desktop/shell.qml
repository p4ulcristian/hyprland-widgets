// Desktop widgets — Rainmeter-style: columns of sections drawn straight on the wallpaper
// (no card) below every window (Bottom layer), so they only show where the wallpaper does.
// Sections are the capitalised files next to this one; add one to a column below.
//
// Screen and corners: set WIDGETS_SCREEN / WIDGETS_CORNER / WIDGETS_SYSTEM_CORNER in desktop-widget.service.
import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

ShellRoot {
  id: root

  readonly property string screenName: Quickshell.env("WIDGETS_SCREEN") || "DP-2"

  // One column in one corner ("top-right", "bottom-left", ...); its sections go inside.
  component Corner: PanelWindow {
    id: win
    property string corner
    default property alias sections: col.data
    screen: Quickshell.screens.find(s => s.name === root.screenName) || Quickshell.screens[0]
    anchors {
      top: win.corner.indexOf("top") === 0; bottom: win.corner.indexOf("bottom") === 0
      left: win.corner.indexOf("left") > 0; right: win.corner.indexOf("right") > 0
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
    }
  }

  Corner {
    corner: Quickshell.env("WIDGETS_CORNER") || "top-right"
    Drives {}
    Internet {}
    Devices {}
  }

  Corner {
    corner: Quickshell.env("WIDGETS_SYSTEM_CORNER") || "top-left"
    System {}
  }
}
