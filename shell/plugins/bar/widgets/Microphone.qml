import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs.Ui

BarWidget {
  id: root
  moduleName: "midhat.microphone"


  readonly property var source: Pipewire.defaultAudioSource
  readonly property real volume: source && source.audio ? source.audio.volume : 0
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []

  readonly property var sources: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i]
      if (node && node.audio && !node.isStream && node.isSink === false) list.push(node)
    }
    return list
  }

  readonly property bool micOn: {
    for (var i = 0; i < sources.length; i++) {
      if (sources[i].audio && !sources[i].audio.muted) return true
    }
    return false
  }

  property string camera: "none"
  readonly property bool allOff: !micOn && camera !== "on"
  readonly property bool allOn: micOn && camera !== "off"

  readonly property var activeStreams: {
    var list = []
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i]
      if (node && node.isStream && node.isSink === false && !node.audio?.muted) list.push(node)
    }
    return list
  }

  readonly property bool inUse: activeStreams.length > 0 && micOn

  visible: sources.length > 0 || camera !== "none"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refreshCamera() {
    if (!cameraProc.running) cameraProc.running = true
  }

  Component.onCompleted: refreshCamera()

  Process {
    id: cameraProc
    command: ["midhat-toggle-mic-camera", "status", "camera"]
    stdout: StdioCollector {
      onStreamFinished: root.camera = text.trim() || "none"
    }
  }

  IpcHandler {
    target: "midhat.microphone"

    function refresh(): void {
      root.refreshCamera()
    }
  }

  PwObjectTracker { objects: root.sources }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.allOff ? "󰦝" : (root.allOn ? "󰍬" : "󰞀")
    active: root.inUse
    tooltipText: root.allOff ? "Mic and camera off" : (root.allOn ? (root.inUse ? "Mic in use, camera on" : "Mic and camera on") : (root.micOn ? "Mic on, camera off" : "Mic off, camera on"))
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.bar.run("midhat-shell shell toggle midhat.audio")
      else root.bar.run("midhat-toggle-mic-camera")
    }
    onWheelMoved: function(delta) {
      if (!root.source || !root.source.audio) return
      var step = 0.05
      root.source.audio.volume = Math.max(0, Math.min(1, root.volume + (delta > 0 ? step : -step)))
    }
  }
}
