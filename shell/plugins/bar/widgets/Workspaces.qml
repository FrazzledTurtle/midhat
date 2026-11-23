import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "midhat.workspaces"

  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  function workspaceIds() {
    // Workspaces 1..count always show; other occupied ones up to 10 join them.
    var ids = []
    for (var n = 1; n <= Number(setting("count", 5)); n++) ids.push(n)
    var values = Hyprland.workspaces.values

    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  // Bookmark ribbon: on a left cover bar (`bar.style: "cover"`) the current workspace gets a ribbon
  // that hangs from the cover over the page edge instead of the filled dot.
  readonly property bool ribbonMode: root.bar ? root.bar.coverShown === true && root.bar.position === "left" : false
  property Item focusedButton: null
  readonly property real ribbonCenter: {
    var b = root.focusedButton
    if (!b) return -1
    // Touch the geometry above the button so this re-evaluates whenever the bar lays out again.
    var moved = b.y + grid.y + root.y + root.height + (root.parent ? root.parent.y : 0)
      + (root.parent && root.parent.parent ? root.parent.parent.y : 0)
    return b.mapToItem(null, 0, b.height / 2).y + moved * 0
  }

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.workspaceIds().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.workspaceIds()

      WidgetButton {
        id: wsButton
        required property int modelData

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
        readonly property bool focused: Hyprland.focusedWorkspace !== null && Hyprland.focusedWorkspace.id === modelData

        bar: root.bar
        text: focused && !root.ribbonMode ? "\uDB85\uDCFB" : (modelData === 10 ? "0" : String(modelData))
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { root.focusWorkspace(modelData) }
        onFocusedChanged: if (focused) root.focusedButton = wsButton
        Component.onCompleted: if (focused) root.focusedButton = wsButton
      }
    }
  }

  PanelWindow {
    id: ribbonWindow
    readonly property int ribbonLength: 6
    readonly property int ribbonWidth: 6

    screen: root.QsWindow.window ? root.QsWindow.window.screen : null
    visible: root.ribbonMode && root.ribbonCenter >= 0
    exclusionMode: ExclusionMode.Ignore
    anchors { left: true; top: true; bottom: true }
    margins.left: root.barSize
    implicitWidth: ribbonLength + 2
    color: "transparent"
    surfaceFormat.opaque: false
    mask: Region {}
    WlrLayershell.namespace: "midhat-bar-ribbon"
    WlrLayershell.layer: WlrLayer.Top

    Item {
      id: ribbon
      width: ribbonWindow.ribbonLength
      height: ribbonWindow.ribbonWidth
      y: Math.round(root.ribbonCenter - height / 2)
      Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

      RibbonShape { x: 1; y: 1.2; fill: "black"; opacity: 0.35 }
      RibbonShape { fill: "#b3261e" }

      Rectangle {
        x: 0; y: 1
        width: ribbon.width - 2; height: 0.6
        color: Qt.rgba(1, 1, 1, 0.18)
      }
    }
  }

  // Swallowtail bookmark, notch on the page side.
  component RibbonShape: Shape {
    property color fill
    width: ribbonWindow.ribbonLength
    height: ribbonWindow.ribbonWidth
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: fill
      strokeColor: "transparent"
      startX: 0; startY: 0
      PathLine { x: ribbonWindow.ribbonLength; y: 0 }
      PathLine { x: ribbonWindow.ribbonLength - 2; y: ribbonWindow.ribbonWidth / 2 }
      PathLine { x: ribbonWindow.ribbonLength; y: ribbonWindow.ribbonWidth }
      PathLine { x: 0; y: ribbonWindow.ribbonWidth }
    }
  }
}
