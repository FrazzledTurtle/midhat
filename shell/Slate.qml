import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Slate's windows, loaded only while the cover is off: the focused app stays
// maximized (bin/midhat-slate fit), and a strip on the right edge turns a swipe
// into back (short) or split (past the middle of the screen).
Scope {
  Component.onCompleted: Quickshell.execDetached(["midhat-slate", "fit"])

  Connections {
    target: Hyprland

    function onActiveToplevelChanged() {
      Quickshell.execDetached(["midhat-slate", "fit"])
    }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: edge
      required property var modelData

      screen: modelData
      anchors { top: true; bottom: true; right: true }
      implicitWidth: 12
      exclusiveZone: 0
      color: "transparent"
      WlrLayershell.namespace: "midhat-slate-edge"
      WlrLayershell.layer: WlrLayer.Top

      MouseArea {
        property real startX: 0

        anchors.fill: parent
        onPressed: function(mouse) { startX = mouse.x }
        onReleased: function(mouse) {
          var travel = startX - mouse.x
          if (travel > edge.modelData.width / 2) Quickshell.execDetached(["midhat-slate", "split"])
          else if (travel > 48) Quickshell.execDetached(["midhat-slate", "back"])
        }
      }
    }
  }
}
