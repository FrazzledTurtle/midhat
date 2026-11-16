import QtQuick
import Quickshell.Io
import qs.Ui

BarWidget {
  id: root
  moduleName: "midhat.reading-mode"

  property bool reading: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  Component.onCompleted: refresh()

  Process {
    id: statusProc
    command: ["midhat-toggle-reading-mode", "status"]
    onExited: function(exitCode) {
      root.reading = exitCode === 0
    }
  }

  IpcHandler {
    target: "midhat.reading-mode"

    function refresh(): void {
      root.refresh()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.reading ? "󰗚" : "󱗖"
    active: root.reading
    tooltipText: root.reading ? "Leave Reading Mode" : "Reading Mode"
    onPressed: function(b) {
      root.bar.run("midhat-toggle-reading-mode")
    }
  }
}
