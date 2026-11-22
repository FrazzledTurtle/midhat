import QtCore
import QtQuick
import Blloku

Window {
  id: win
  required property var page
  required property var library
  required property var theme
  property string view: "page"

  readonly property int textSize: 17
  readonly property int lineHeight: 32
  readonly property int margin: Math.max(24, Math.min(56, width * 0.05))
  readonly property var blocks: page.blocks
  readonly property bool endsWithText: {
    for (let i = blocks.length - 1; i >= 0; i--)
      if (blocks[i].kind !== "layer") return blocks[i].kind === "text"
    return false
  }
  property int focusIndex: lastText()

  function lastText() {
    for (let i = blocks.length - 1; i >= 0; i--)
      if (blocks[i].kind === "text") return i
    return -1
  }

  function openFile(file) {
    page = library.open(file)
    focusIndex = lastText()
    flick.contentY = 0
    view = "page"
  }
  property string tool: "pen"
  property string paper: "lined"
  readonly property var papers: ["blank", "lined", "dotted", "grid"]

  visible: true
  width: 1280
  height: 800
  title: "Blloku · " + page.title
  color: theme.background

  Settings {
    category: "page"
    property alias paper: win.paper
  }

  FontMetrics {
    id: body
    font.family: "Liberation Serif"
    font.pixelSize: win.textSize
  }

  // Pen near the glass: fingers (and the palm) stop scrolling the page.
  HoverHandler {
    id: penNear
    acceptedDevices: PointerDevice.Stylus
  }

  Item {
    id: header
    x: win.margin
    y: 18
    width: column.width
    height: headerText.implicitHeight + 10

    Text {
      id: headerText
      textFormat: Text.PlainText
      text: "‹  " + win.page.bllok + " › " + win.page.title
      color: win.theme.muted
      font.pixelSize: 13
      Accessible.role: Accessible.Button
      Accessible.name: "Blloqe"

      TapHandler {
        margin: 12
        onTapped: win.view = "library"
      }
    }
    Text {
      anchors.right: parent.right
      anchors.left: headerText.right
      anchors.leftMargin: 24
      horizontalAlignment: Text.AlignRight
      elide: Text.ElideMiddle
      textFormat: Text.PlainText
      text: win.page.error || layer.error
      color: win.theme.foreground
      font.pixelSize: 13
      font.bold: true
    }
    Rectangle {
      anchors.bottom: parent.bottom
      width: parent.width
      height: 1
      color: win.theme.selection
    }
  }

  Flickable {
    id: flick
    anchors.top: header.bottom
    anchors.bottom: parent.bottom
    width: parent.width
    contentHeight: sheet.height
    boundsBehavior: Flickable.StopAtBounds
    interactive: !penNear.hovered
    clip: true

    Item {
      id: sheet
      width: flick.width
      height: Math.max(column.y + column.height, column.y + layer.contentHeight) + flick.height * 0.6

      Paper {
        x: column.x
        width: column.width
        height: parent.height
        kind: win.paper
        color: win.theme.selection
        spacing: win.lineHeight
        phase: column.y + body.ascent + 11
      }

      Column {
        id: column
        x: win.margin
        y: win.lineHeight
        width: Math.min(640, win.width - 2 * win.margin - strip.width - 12)

        Repeater {
          model: win.blocks

          delegate: Item {
            id: block
            required property var modelData
            required property int index
            readonly property string kind: modelData.kind
            readonly property real natural: kind === "text" ? edit.implicitHeight
                                          : kind === "ink" ? oldInk.contentHeight
                                          : kind === "layer" ? 0 : raw.implicitHeight

            width: column.width
            height: Math.ceil(natural / win.lineHeight) * win.lineHeight

            TextEdit {
              id: edit
              visible: block.kind === "text"
              width: parent.width
              textFormat: TextEdit.PlainText
              wrapMode: TextEdit.Wrap
              text: block.kind === "text" ? block.modelData.text : ""
              color: win.theme.foreground
              selectionColor: win.theme.selection
              selectedTextColor: win.theme.foreground
              font: body.font
              selectByMouse: true
              persistentSelection: true
              onTextChanged: if (block.kind === "text") win.page.setBlockText(block.index, text)
              onCursorRectangleChanged: if (activeFocus) {
                const y = block.y + column.y + cursorRectangle.y
                if (y < flick.contentY) flick.contentY = y
                else if (y + cursorRectangle.height > flick.contentY + flick.height)
                  flick.contentY = y + cursorRectangle.height - flick.height + 24
              }
              Component.onCompleted: if (block.index === win.focusIndex) {
                forceActiveFocus()
                cursorPosition = length
              }

              MarkdownHighlighter {
                document: edit.textDocument
                muted: win.theme.muted
                baseSize: win.textSize
                lineHeight: win.lineHeight
              }
            }

            // Ink blocks from the first test build: shown, no longer drawn into.
            InkCanvas {
              id: oldInk
              visible: block.kind === "ink"
              width: parent.width
              height: contentHeight
              source: block.kind === "ink" ? win.page.inkFile(block.index) : ""
              ink: win.theme.foreground
            }

            Text {
              id: raw
              visible: block.kind !== "text" && block.kind !== "ink" && block.kind !== "layer"
              width: parent.width
              wrapMode: Text.Wrap
              textFormat: Text.PlainText
              text: visible ? block.modelData.text : ""
              color: win.theme.muted
              font.family: "monospace"
              font.pixelSize: 13
            }
          }
        }

        // Typing after the last block when it isn't text starts a new text block.
        TextEdit {
          id: tailText
          visible: !win.endsWithText
          width: column.width
          height: visible ? win.lineHeight : 0
          textFormat: TextEdit.PlainText
          color: win.theme.foreground
          font: body.font
          onTextChanged: if (text.length > 0) {
            const t = text
            text = ""
            win.focusIndex = win.blocks.length
            win.page.appendText(t)
          }

          Text {
            visible: !tailText.activeFocus && tailText.text.length === 0
            textFormat: Text.PlainText
            text: "Type here"
            color: win.theme.muted
            font: tailText.font
          }
        }
      }
    }
  }

  // The page's ink, over text and paper alike. It covers the screen and follows
  // the scroll; strokes are kept in page coordinates.
  InkCanvas {
    id: layer
    enabled: win.view === "page"
    x: column.x
    y: flick.y
    width: column.width
    height: flick.height
    scroll: flick.contentY - column.y
    source: win.page.layerFile()
    ink: win.theme.foreground

    // Claims the pen on contact, so a stroke over text never moves the cursor.
    TapHandler {
      acceptedDevices: PointerDevice.Stylus
      gesturePolicy: TapHandler.WithinBounds
    }

    PointHandler {
      acceptedDevices: PointerDevice.Stylus
      acceptedPointerTypes: PointerDevice.Pen
      onActiveChanged: {
        const p = point.position
        if (active) {
          if (win.tool === "erase") layer.eraseAt(p.x, p.y)
          else layer.begin(p.x, p.y, point.pressure)
        } else if (win.tool === "erase") {
          layer.endErase()
        } else {
          layer.finish()
          win.page.ensureLayer()
        }
      }
      onPointChanged: if (active) {
        const p = point.position
        if (win.tool === "erase") layer.eraseAt(p.x, p.y)
        else layer.extend(p.x, p.y, point.pressure)
      }
    }
  }

  Column {
    id: strip
    anchors.right: parent.right
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10
    width: 56

    Repeater {
      model: [
        { key: "pen", glyph: "󰏫", name: "Pen" },
        { key: "erase", glyph: "󰇾", name: "Erase" }
      ]
      delegate: Rectangle {
        required property var modelData
        readonly property bool lit: win.tool === modelData.key
        width: 56
        height: 56
        radius: 12
        color: lit ? win.theme.foreground : "transparent"
        border.width: 1.5
        border.color: win.theme.foreground
        Accessible.role: Accessible.Button
        Accessible.name: modelData.name

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: parent.modelData.glyph
          font.family: "monospace"
          font.pixelSize: 24
          color: parent.lit ? win.theme.background : win.theme.foreground
        }
        TapHandler { onTapped: win.tool = parent.modelData.key }
      }
    }

    Rectangle {
      width: 56
      height: 56
      radius: 12
      color: "transparent"
      border.width: 1.5
      border.color: win.theme.foreground
      Accessible.role: Accessible.Button
      Accessible.name: "Paper: " + win.paper

      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: win.paper
        font.pixelSize: 12
        color: win.theme.foreground
      }
      TapHandler { onTapped: win.paper = win.papers[(win.papers.indexOf(win.paper) + 1) % win.papers.length] }
    }
  }

  // Two-finger tap = undo the last stroke or erase.
  MultiPointTouchArea {
    anchors.fill: parent
    mouseEnabled: false
    minimumTouchPoints: 2
    maximumTouchPoints: 2
    property real downAt: 0
    property int most: 0
    onTouchUpdated: (points) => {
      if (points.length > 0 && most === 0) downAt = Date.now()
      most = Math.max(most, points.length)
      if (points.length === 0) {
        if (most >= 2 && Date.now() - downAt < 350) layer.undo()
        most = 0
      }
    }
  }

  Loader {
    anchors.fill: parent
    z: 10
    active: win.view === "library"
    sourceComponent: Library {
      library: win.library
      theme: win.theme
      current: win.page.path
      onOpenFile: (file) => win.openFile(file)
      onClosed: win.view = "page"
    }
  }
}
