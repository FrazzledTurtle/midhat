import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Shapes
import Quickshell.Wayland
import Quickshell.Services.UPower
import qs.Commons
import qs.Commons as Commons
import "BatteryModel.js" as BatteryModel

Item {
  id: root

  property var shell: null
  property string midhatPath: Quickshell.env("MIDHAT_PATH")

  readonly property int batteryThreshold: 10
  property string pendingPowerSource: ""

  PersistentProperties {
    id: persisted
    reloadableId: "midhat-battery"
    property bool notifiedLowBattery: false
  }

  function batteryPercentage() {
    return BatteryModel.batteryPercentage(UPower.displayDevice)
  }

  function isDischarging() {
    return BatteryModel.isDischarging(UPower.displayDevice, UPower.onBattery, UPowerDeviceState.Discharging)
  }

  function checkBattery() {
    var state = BatteryModel.shouldWarnLowBattery(UPower.displayDevice, UPower.onBattery, UPowerDeviceState.Discharging, batteryThreshold, persisted.notifiedLowBattery)
    persisted.notifiedLowBattery = state.notifiedLowBattery
    if (state.notify) sendLowBatteryWarning(state.level)
  }

  function sendLowBatteryWarning(level) {
    if (warningProcess.running) return
    warningProcess.command = [
      "midhat-battery-low",
      String(level)
    ]
    warningProcess.running = true
  }

  function applyPowerProfile() {
    pendingPowerSource = UPower.onBattery ? "battery" : "ac"
    if (!powerProfileProcess.running) runPendingPowerProfile()
  }

  function runPendingPowerProfile() {
    powerProfileProcess.command = ["midhat-powerprofiles-set", pendingPowerSource]
    pendingPowerSource = ""
    powerProfileProcess.running = true
  }

  Process { id: warningProcess }

  Process {
    id: powerProfileProcess
    onExited: if (root.pendingPowerSource !== "") root.runPendingPowerProfile()
  }

  Timer {
    interval: 30000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.checkBattery()
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() {
      root.checkBattery()
      root.applyPowerProfile()
    }
  }

  // The battery line: the charge drawn just outside the bar's edge.
  readonly property string position: shell && shell.barConfig && shell.barConfig.position ? shell.barConfig.position : "top"
  readonly property bool vertical: position === "left" || position === "right"
  readonly property int barSize: vertical ? Style.bar.sizeVertical : Style.bar.sizeHorizontal
  readonly property real thickness: 1.5
  readonly property int radius: Style.cornerRadius
  // From the start of the bar's corner curve to just past its edge; layer margins are whole pixels.
  readonly property int strip: radius + Math.ceil(thickness)
  readonly property var device: UPower.displayDevice
  readonly property bool present: device && device.isPresent
  readonly property real level: present ? Math.max(0, Math.min(1, device.percentage)) : 0

  // The line just outside the bar's edge, drawn for a left bar (W across, L along, starting
  // at the bottom), then turned to the bar's real side. Around a rounded corner it ends a
  // half stroke past the screen edge, so its end is never on screen.
  function edgePath(W, L) {
    var c = thickness / 2
    var r = radius
    var x = r + c
    var pts, len
    if (r === 0) {
      pts = [["M", x, L], ["L", x, 0]]
      len = L
    } else {
      pts = [["M", 0, L + c], ["A", x, L - r], ["L", x, r], ["A", 0, -c]]
      len = (L - 2 * r) + Math.PI * x
    }
    var mirror = position === "right" || position === "bottom"
    function map(x, y) {
      if (position === "right") return [W - x, y]
      if (position === "top") return [L - y, x]
      if (position === "bottom") return [L - y, W - x]
      return [x, y]
    }
    var d = pts.map(function(p) {
      var q = map(p[1], p[2])
      if (p[0] === "A")
        return "A " + x + " " + x + " 0 0 " + (mirror ? 1 : 0) + " " + q[0] + " " + q[1]
      return p[0] + " " + q[0] + " " + q[1]
    }).join(" ")
    return { d: d, len: len }
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      id: lineWindow
      required property var modelData

      readonly property var edge: root.edgePath(root.strip, root.vertical ? height : width)

      screen: modelData
      visible: root.present
      exclusionMode: ExclusionMode.Ignore
      // Starts where the bar's corner curve starts and reaches just past the bar's edge.
      anchors {
        top: root.position === "top" || root.vertical
        bottom: root.position === "bottom" || root.vertical
        left: root.position === "left" || !root.vertical
        right: root.position === "right" || !root.vertical
      }
      margins {
        top: root.position === "top" ? root.barSize - root.radius : 0
        bottom: root.position === "bottom" ? root.barSize - root.radius : 0
        left: root.position === "left" ? root.barSize - root.radius : 0
        right: root.position === "right" ? root.barSize - root.radius : 0
      }
      implicitWidth: root.vertical ? root.strip : 0
      implicitHeight: root.vertical ? 0 : root.strip
      color: "transparent"
      mask: Region {}
      WlrLayershell.namespace: "midhat-batteryline"
      WlrLayershell.layer: WlrLayer.Top

      Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4

        ShapePath {
          strokeColor: Commons.Color.bar.text
          strokeWidth: root.thickness
          fillColor: "transparent"
          capStyle: ShapePath.FlatCap
          // One dash as long as the charge, then a gap past the end of the path.
          strokeStyle: ShapePath.DashLine
          dashPattern: [root.level * lineWindow.edge.len / root.thickness, (lineWindow.edge.len + 1) / root.thickness]
          PathSvg { path: lineWindow.edge.d }
        }
      }
    }
  }
}
