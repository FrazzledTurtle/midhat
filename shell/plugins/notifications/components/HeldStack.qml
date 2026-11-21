import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// One card listing what Reading mode held back. Tapping a row opens it.
BorderSurface {
  id: root

  property var rows: []
  property int cornerRadius: 0

  signal openRequested(int index)
  signal closeRequested()

  readonly property color dimColor: Qt.darker(Commons.Color.notifications.text, 1.4)

  implicitWidth: Style.space(380)
  implicitHeight: column.implicitHeight + borderTop + borderBottom
  radius: cornerRadius
  color: Commons.Color.notifications.background
  borderSpec: Border.surfaceSpec("notifications", "border", Commons.Color.notifications.border, Math.max(1, Style.space(2)))
  clip: true

  ColumnLayout {
    id: column
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: root.borderTop
    anchors.leftMargin: root.borderLeft
    anchors.rightMargin: root.borderRight
    spacing: 0

    RowLayout {
      Layout.fillWidth: true
      Layout.leftMargin: Style.space(12)
      Layout.rightMargin: Style.space(4)
      Layout.preferredHeight: Style.space(48)

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: root.rows.length === 1 ? "1 notification while reading" : root.rows.length + " notifications while reading"
        font.family: "Liberation Sans"
        font.pixelSize: Style.font.title
        font.bold: true
        color: Commons.Color.notifications.text
      }

      Text {
        Layout.preferredWidth: Style.space(44)
        Layout.fillHeight: true
        textFormat: Text.PlainText
        text: "×"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Style.font.title
        color: root.dimColor

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.closeRequested()
        }
      }
    }

    Repeater {
      model: root.rows

      Item {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        Layout.preferredHeight: Style.space(56)

        Rectangle {
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.spacing.hairline
          color: root.dimColor
          opacity: 0.4
        }

        ColumnLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(2)

          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: String(modelData.app || "")
            font.family: "Liberation Sans"
            font.pixelSize: Style.font.caption
            color: root.dimColor
            elide: Text.ElideRight
          }

          Text {
            Layout.fillWidth: true
            textFormat: Text.PlainText
            text: String(modelData.summary || modelData.body || "")
            font.family: "Liberation Sans"
            font.pixelSize: Style.font.body
            color: Commons.Color.notifications.text
            elide: Text.ElideRight
          }
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: root.openRequested(index)
        }
      }
    }
  }
}
