import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons

// Slate's Home page: the desktop beside the rail, behind every window, so it
// shows wherever nothing is open. bin/midhat-slate-home supplies the book in
// progress, today's page and recent PDFs.
PanelWindow {
  id: home

  property var content: ({ book: null, today: null, pdfs: [] })
  readonly property bool landscape: width > height
  readonly property color ink: Commons.Color.foreground
  readonly property color line: Qt.rgba(ink.r, ink.g, ink.b, 0.25)
  readonly property string family: Style.font.family

  anchors { top: true; bottom: true; left: true; right: true }
  exclusiveZone: 0
  color: Commons.Color.background
  WlrLayershell.namespace: "midhat-slate-home"
  WlrLayershell.layer: WlrLayer.Bottom
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  function refresh() {
    if (!loader.running) loader.running = true
  }

  function launch(argv) {
    Quickshell.execDetached(["uwsm-app", "--"].concat(argv))
  }

  function openBook() {
    var readers = ToplevelManager.toplevels.values.filter(function(t) { return t.appId === "rocks.koreader.KOReader" })
    if (readers.length) readers[0].activate()
    else launch(content.book ? ["koreader", content.book.file] : ["koreader"])
  }

  function when(epoch) {
    var then = new Date(epoch * 1000)
    var days = Math.floor((new Date(clock.date).setHours(0, 0, 0, 0) - new Date(then).setHours(0, 0, 0, 0)) / 86400000)
    if (days <= 0) return "today"
    if (days === 1) return "yesterday"
    return Qt.formatDate(then, "d MMM")
  }

  Process {
    id: loader
    command: ["midhat-slate-home"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try { home.content = JSON.parse(text) } catch (e) { console.warn("midhat-slate-home:", e) }
      }
    }
  }

  Component.onCompleted: refresh()

  Connections {
    target: Hyprland

    function onActiveToplevelChanged() {
      if (!Hyprland.activeToplevel) home.refresh()
    }
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }

  component Heading: Text {
    textFormat: Text.PlainText
    font.family: home.family
    font.pixelSize: 13
    font.weight: Font.DemiBold
    font.letterSpacing: 1
    font.capitalization: Font.AllUppercase
    color: home.ink
    opacity: 0.75
  }

  component Card: Rectangle {
    id: card
    signal tapped()
    default property alias body: inner.data
    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + 40
    radius: 16
    color: "transparent"
    border.width: 1
    border.color: home.line

    Item {
      id: inner
      anchors.fill: parent
      anchors.margins: 20
      implicitHeight: childrenRect.height
    }

    MouseArea {
      anchors.fill: parent
      onClicked: card.tapped()
    }
  }

  GridLayout {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: 48
    columns: home.landscape ? 2 : 1
    columnSpacing: 48
    rowSpacing: 40

    ColumnLayout {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      Layout.alignment: Qt.AlignTop
      spacing: 12

      Text {
        textFormat: Text.PlainText
        text: Qt.formatTime(clock.date, "HH:mm")
        font.family: home.family
        font.pixelSize: 64
        font.weight: Font.DemiBold
        color: home.ink
      }

      Text {
        textFormat: Text.PlainText
        Layout.bottomMargin: 28
        text: Qt.formatDate(clock.date, "dddd, d MMMM")
        font.family: home.family
        font.pixelSize: 16
        color: home.ink
        opacity: 0.75
      }

      Heading { text: "Continue reading" }

      Card {
        onTapped: home.openBook()

        RowLayout {
          width: parent.width
          spacing: 24

          Rectangle {
            visible: !!home.content.book
            Layout.preferredWidth: 96
            Layout.preferredHeight: 136
            radius: 4
            color: "transparent"
            border.width: 1
            border.color: home.ink

            Text {
              textFormat: Text.PlainText
              anchors.fill: parent
              anchors.margins: 10
              text: home.content.book ? home.content.book.title : ""
              wrapMode: Text.Wrap
              elide: Text.ElideRight
              font.family: home.family
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: home.ink
            }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 10

            Text {
              textFormat: Text.PlainText
              Layout.fillWidth: true
              text: home.content.book ? home.content.book.title : "No book yet"
              wrapMode: Text.Wrap
              maximumLineCount: 3
              elide: Text.ElideRight
              font.family: home.family
              font.pixelSize: 22
              font.weight: Font.DemiBold
              color: home.ink
            }

            Text {
              textFormat: Text.PlainText
              Layout.fillWidth: true
              text: {
                var b = home.content.book
                if (!b) return "Tap to open the Library"
                var parts = []
                if (b.author) parts.push(b.author)
                if (b.page && b.pages) parts.push("page " + b.page + " of " + b.pages)
                return parts.join(" · ")
              }
              elide: Text.ElideRight
              font.family: home.family
              font.pixelSize: 14
              color: home.ink
              opacity: 0.75
            }

            Rectangle {
              visible: !!home.content.book
              Layout.fillWidth: true
              implicitHeight: 4
              radius: 2
              color: home.line

              Rectangle {
                width: parent.width * Math.max(0, Math.min(1, home.content.book ? home.content.book.percent : 0))
                height: parent.height
                radius: 2
                color: home.ink
              }
            }
          }
        }
      }

      Heading {
        Layout.topMargin: 28
        text: "Today's page"
      }

      Card {
        onTapped: home.launch(home.content.today ? ["xournalpp", home.content.today.file] : ["xournalpp"])

        ColumnLayout {
          width: parent.width
          spacing: 6

          Text {
            textFormat: Text.PlainText
            text: home.content.today ? home.content.today.name : "Start a page"
            font.family: home.family
            font.pixelSize: 18
            font.weight: Font.DemiBold
            color: home.ink
          }

          Text {
            textFormat: Text.PlainText
            text: home.content.today ? "Xournal++ · edited " + home.when(home.content.today.time) : "Opens Xournal++"
            font.family: home.family
            font.pixelSize: 14
            color: home.ink
            opacity: 0.75
          }
        }
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      Layout.alignment: Qt.AlignTop
      Layout.topMargin: home.landscape ? 6 : 0
      spacing: 12

      Heading { text: "Recent PDFs" }

      Text {
        textFormat: Text.PlainText
        visible: home.content.pdfs.length === 0
        text: "Nothing yet"
        font.family: home.family
        font.pixelSize: 16
        color: home.ink
        opacity: 0.75
      }

      Rectangle {
        visible: home.content.pdfs.length > 0
        Layout.fillWidth: true
        implicitHeight: rows.implicitHeight
        radius: 16
        color: "transparent"
        border.width: 1
        border.color: home.line
        clip: true

        Column {
          id: rows
          width: parent.width

          Repeater {
            model: home.content.pdfs

            Item {
              required property var modelData
              required property int index
              width: rows.width
              height: 60

              Rectangle {
                visible: index > 0
                width: parent.width
                height: 1
                color: home.line
              }

              Text {
                textFormat: Text.PlainText
                anchors.left: parent.left
                anchors.right: age.left
                anchors.leftMargin: 20
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.name
                elide: Text.ElideMiddle
                font.family: home.family
                font.pixelSize: 16
                color: home.ink
              }

              Text {
                textFormat: Text.PlainText
                id: age
                anchors.right: parent.right
                anchors.rightMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.file.split("/").slice(-2)[0] + " · " + home.when(modelData.time)
                font.family: home.family
                font.pixelSize: 13
                color: home.ink
                opacity: 0.75
              }

              MouseArea {
                anchors.fill: parent
                onClicked: home.launch(["zathura", modelData.file])
              }
            }
          }
        }
      }
    }
  }
}
