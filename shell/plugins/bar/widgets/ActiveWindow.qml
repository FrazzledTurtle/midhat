import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "midhat.active-window"


  readonly property var toplevel: ToplevelManager.activeToplevel
  readonly property string title: toplevel ? (toplevel.title || toplevel.appId || "") : ""
  readonly property int maxLabelWidth: Number(setting("maxWidth", 280))
  // On a vertical bar, "spine" shows the title along the bar, read bottom to top.
  readonly property bool spine: vertical && setting("spine", false) === true

  visible: title !== "" && (!vertical || spine)
  implicitWidth: !visible ? 0 : spine ? barSize : Math.min(maxLabelWidth, labelText.implicitWidth) + Style.spacing.controlPaddingX * 2
  implicitHeight: spine ? Math.min(maxLabelWidth, spineText.implicitWidth) + Style.space(16) : barSize

  Behavior on implicitWidth {
    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
  }

  Text {
    id: spineText
    visible: root.spine
    textFormat: Text.PlainText
    anchors.centerIn: parent
    width: Math.max(0, root.height - Style.space(16))
    rotation: -90
    horizontalAlignment: Text.AlignHCenter
    text: root.title
    color: root.bar ? root.bar.barForeground : Commons.Color.foreground
    font.family: root.bar ? root.bar.fontFamily : Style.font.family
    font.pixelSize: Style.font.body
    elide: Text.ElideRight
    opacity: 0.85
  }

  Item {
    visible: !root.spine
    anchors.fill: parent
    anchors.leftMargin: Style.space(8)
    anchors.rightMargin: Style.space(8)
    clip: true

    Text {
      id: labelText
      textFormat: Text.PlainText
      anchors.verticalCenter: parent.verticalCenter
      anchors.left: parent.left
      width: parent.width
      text: root.title
      color: root.bar ? root.bar.barForeground : Commons.Color.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
      opacity: 0.85
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onClicked: function(mouse) {
      if (!root.toplevel) return
      if (mouse.button === Qt.MiddleButton) {
        root.toplevel.close()
      } else if (mouse.button === Qt.RightButton) {
        root.toplevel.close()
      } else {
        root.toplevel.activate()
      }
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.title)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
