import QtQuick

// Blloqe on the left, the chosen bllok's pages on the right.
Rectangle {
  id: root
  required property var library
  required property var theme
  required property string current
  signal openFile(string file)
  signal closed()

  property var blloqe: library.blloqe()
  property string bllok: {
    for (const b of blloqe)
      if (current.startsWith(b.path + "/")) return b.path
    return blloqe.length > 0 ? blloqe[0].path : ""
  }
  property var pages: bllok ? library.pages(bllok) : []
  property bool naming: false

  function refresh() {
    blloqe = library.blloqe()
    pages = bllok ? library.pages(bllok) : []
  }

  color: theme.background

  Rectangle {
    id: side
    width: Math.min(280, root.width * 0.32)
    height: parent.height
    color: root.theme.background

    Column {
      x: 28
      y: 22
      width: parent.width - 48
      spacing: 6

      Text {
        textFormat: Text.PlainText
        text: "Blloku"
        font.family: "Liberation Serif"
        font.pixelSize: 26
        font.bold: true
        color: root.theme.foreground
        bottomPadding: 10
      }

      Rectangle {
        width: parent.width
        height: 48
        radius: 10
        color: root.theme.foreground
        Accessible.role: Accessible.Button
        Accessible.name: "Today"
        Text {
          anchors.verticalCenter: parent.verticalCenter
          x: 14
          textFormat: Text.PlainText
          text: "Today"
          font.pixelSize: 15
          font.bold: true
          color: root.theme.background
        }
        TapHandler { onTapped: root.openFile(root.library.todayFile()) }
      }

      Text {
        textFormat: Text.PlainText
        text: "BLLOQE"
        font.pixelSize: 11
        font.letterSpacing: 1
        color: root.theme.muted
        topPadding: 16
        bottomPadding: 4
      }

      Repeater {
        model: root.blloqe
        delegate: Rectangle {
          required property var modelData
          readonly property bool chosen: modelData.path === root.bllok
          width: parent.width
          height: 48
          radius: 10
          color: chosen ? root.theme.dark_background : "transparent"
          border.width: chosen ? 1.5 : 0
          border.color: root.theme.foreground
          Accessible.role: Accessible.Button
          Accessible.name: modelData.name

          Text {
            anchors.verticalCenter: parent.verticalCenter
            x: 14
            width: parent.width - 60
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: parent.modelData.name
            font.pixelSize: 15
            font.bold: parent.chosen
            color: root.theme.foreground
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: 14
            textFormat: Text.PlainText
            text: parent.modelData.count
            font.pixelSize: 13
            color: root.theme.muted
          }
          TapHandler {
            onTapped: {
              root.bllok = parent.modelData.path
              root.pages = root.library.pages(root.bllok)
            }
          }
        }
      }

      Rectangle {
        width: parent.width
        height: 48
        radius: 10
        color: "transparent"
        border.width: 1
        border.color: root.theme.muted
        Accessible.role: Accessible.Button
        Accessible.name: "New bllok"

        Text {
          visible: !root.naming
          anchors.verticalCenter: parent.verticalCenter
          x: 14
          textFormat: Text.PlainText
          text: "+  New bllok"
          font.pixelSize: 15
          color: root.theme.foreground
        }
        TextInput {
          id: name
          visible: root.naming
          anchors.verticalCenter: parent.verticalCenter
          x: 14
          width: parent.width - 28
          font.pixelSize: 15
          color: root.theme.foreground
          maximumLength: 80
          onAccepted: {
            const made = root.library.newBllok(text)
            if (made) {
              root.bllok = made
              root.refresh()
            }
            text = ""
            root.naming = false
          }
          onActiveFocusChanged: if (!activeFocus) root.naming = false
        }
        TapHandler {
          enabled: !root.naming
          onTapped: {
            root.naming = true
            name.forceActiveFocus()
          }
        }
      }
    }
  }

  Rectangle {
    x: side.width
    width: 1
    height: parent.height
    color: root.theme.selection
  }

  Flickable {
    x: side.width + 1
    width: parent.width - x
    height: parent.height
    contentHeight: grid.y + grid.height + 40
    boundsBehavior: Flickable.StopAtBounds
    clip: true

    Item {
      id: bar
      x: 28
      y: 22
      width: parent.width - 56
      height: 48

      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.bllok.split("/").pop()
        font.family: "Liberation Serif"
        font.pixelSize: 21
        font.bold: true
        color: root.theme.foreground
      }
      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Rectangle {
          width: 110
          height: 44
          radius: 10
          color: "transparent"
          border.width: 1.5
          border.color: root.theme.foreground
          Accessible.role: Accessible.Button
          Accessible.name: "Back to the page"
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "Back"
            font.pixelSize: 14
            color: root.theme.foreground
          }
          TapHandler { onTapped: root.closed() }
        }
        Rectangle {
          width: 120
          height: 44
          radius: 10
          color: root.theme.foreground
          Accessible.role: Accessible.Button
          Accessible.name: "New page"
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "New page"
            font.pixelSize: 14
            font.bold: true
            color: root.theme.background
          }
          TapHandler { onTapped: if (root.bllok) root.openFile(root.library.newPageFile(root.bllok)) }
        }
      }
    }

    Grid {
      id: grid
      x: 28
      y: bar.y + bar.height + 22
      width: parent.width - 56
      columns: Math.max(2, Math.floor((width + spacing) / 200))
      spacing: 20
      readonly property real cell: (width - (columns - 1) * spacing) / columns

      Repeater {
        model: root.pages
        delegate: Item {
          required property var modelData
          width: grid.cell
          height: card.height + 52
          Accessible.role: Accessible.Button
          Accessible.name: modelData.title

          Rectangle {
            id: card
            width: parent.width
            height: width * 4 / 3
            radius: 8
            color: root.theme.background
            border.width: modelData.file === root.current ? 2 : 1
            border.color: modelData.file === root.current ? root.theme.foreground : root.theme.muted
            clip: true

            Image {
              anchors.fill: parent
              anchors.margins: 1
              visible: source !== ""
              source: parent.parent.modelData.ink
              sourceSize.width: width * 2
              fillMode: Image.PreserveAspectFit
              verticalAlignment: Image.AlignTop
              asynchronous: true
              cache: false
            }
            Text {
              x: 12
              y: 10
              width: parent.width - 24
              height: parent.height - 20
              wrapMode: Text.Wrap
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: parent.parent.modelData.preview
              font.family: "Liberation Serif"
              font.pixelSize: 12
              lineHeight: 1.3
              color: root.theme.foreground
            }
          }
          Text {
            y: card.height + 8
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: parent.modelData.title
            font.pixelSize: 14
            font.bold: true
            color: root.theme.foreground
          }
          Text {
            y: card.height + 28
            textFormat: Text.PlainText
            text: parent.modelData.when
            font.pixelSize: 12
            color: root.theme.muted
          }
          TapHandler { onTapped: root.openFile(parent.modelData.file) }
        }
      }
    }
  }
}
