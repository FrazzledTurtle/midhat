import QtQuick
import Quickshell.Networking
import qs.Ui
import qs.Commons
import qs.Commons as Commons

// One bar icon for Wi-Fi, Bluetooth and Sound. Its card shows each with a
// switch or slider; › opens that one's full panel, hosted here unseen.
Panel {
  id: root
  moduleName: "midhat.status"
  ipcTarget: "midhat.status"

  readonly property var network: networkHost.item
  readonly property var bluetooth: bluetoothHost.item
  readonly property var audio: audioHost.item

  readonly property bool wifiOn: Networking.wifiEnabled
  readonly property var wifiNetwork: network ? network.connectedWifiNetwork : null
  readonly property bool bluetoothOn: !!bluetooth && !!bluetooth.adapter && bluetooth.adapter.enabled
  readonly property var bluetoothDevice: bluetooth && bluetooth.connectedDevices.length > 0 ? bluetooth.connectedDevices[0] : null
  readonly property bool muted: !!audio && audio.outputMuted

  readonly property int rowHeight: Style.space(48)
  readonly property color dimColor: Qt.darker(root.barForeground, 1.4)

  function openFull(panel) {
    root.close()
    if (panel) panel.open()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Item {
    id: hosts
    anchors.fill: parent
    opacity: 0

    Loader { id: networkHost; anchors.fill: parent; source: Qt.resolvedUrl("../../panels/network/Panel.qml") }
    Loader { id: bluetoothHost; anchors.fill: parent; source: Qt.resolvedUrl("../../panels/bluetooth/Panel.qml") }
    Loader { id: audioHost; anchors.fill: parent; source: Qt.resolvedUrl("../../panels/audio/Panel.qml") }
  }

  Binding { target: root.network; property: "bar"; value: root.bar; when: !!root.network }
  Binding { target: root.network; property: "moduleName"; value: "midhat.network"; when: !!root.network }
  Binding { target: root.bluetooth; property: "bar"; value: root.bar; when: !!root.bluetooth }
  Binding { target: root.bluetooth; property: "moduleName"; value: "midhat.bluetooth"; when: !!root.bluetooth }
  Binding { target: root.audio; property: "bar"; value: root.bar; when: !!root.audio }
  Binding { target: root.audio; property: "moduleName"; value: "midhat.audio"; when: !!root.audio }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.network ? root.network.icon : ""
    onPressed: root.toggle()

    Rectangle {
      visible: !!root.bluetoothDevice
      width: Style.space(5)
      height: width
      radius: width / 2
      color: root.barForeground
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.margins: Style.space(3)
    }

    Rectangle {
      visible: root.muted
      width: Style.space(2)
      height: parent.height * 0.7
      rotation: 45
      color: root.barForeground
      anchors.centerIn: parent
    }
  }

  KeyboardPanel {
    id: card
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: card.fittedContentWidth(Style.space(340))
    contentHeight: card.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: column
        anchors.fill: parent
        spacing: Style.space(6)

        StatusRow {
          title: "Wi-Fi"
          detail: !root.wifiOn ? "Off" : (root.wifiNetwork ? String(root.wifiNetwork.name || "") : "Not connected")
          switchVisible: true
          switchOn: root.wifiOn
          onSwitchToggled: if (root.network) root.network.toggleNetwork()
          onMoreRequested: root.openFull(root.network)
        }

        StatusRow {
          title: "Bluetooth"
          detail: !root.bluetoothOn ? "Off" : (root.bluetoothDevice ? String(root.bluetoothDevice.deviceName || root.bluetoothDevice.name || "") : "On")
          switchVisible: !!root.bluetooth && !!root.bluetooth.adapter
          switchOn: root.bluetoothOn
          onSwitchToggled: if (root.bluetooth) root.bluetooth.toggleBluetooth()
          onMoreRequested: root.openFull(root.bluetooth)
        }

        Item {
          width: parent.width
          height: root.rowHeight

          Text {
            id: soundTitle
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(84)
            text: "Sound"
            color: root.barForeground
            font.pixelSize: Style.font.body
            font.bold: true
          }

          PanelSlider {
            anchors.left: soundTitle.right
            anchors.right: muteButton.left
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            bar: root.bar
            value: root.audio ? root.audio.outputVolume : 0
            onMoved: function(v) { if (root.audio) root.audio.setOutputVolume(v) }
          }

          Text {
            id: muteButton
            anchors.right: soundMore.left
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(40)
            height: root.rowHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: root.muted ? "󰝟" : "󰕾"
            color: root.barForeground
            font.pixelSize: Style.font.icon

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: if (root.audio) root.audio.toggleOutputMute()
            }
          }

          Text {
            id: soundMore
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Style.space(32)
            height: root.rowHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "›"
            color: root.dimColor
            font.pixelSize: Style.font.title

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.openFull(root.audio)
            }
          }
        }
      }
    }
  }

  component StatusRow: Item {
    id: row
    property string title: ""
    property string detail: ""
    property bool switchVisible: false
    property bool switchOn: false
    signal switchToggled()
    signal moreRequested()

    width: parent ? parent.width : 0
    height: root.rowHeight

    Text {
      id: rowTitle
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(84)
      text: row.title
      color: root.barForeground
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      anchors.left: rowTitle.right
      anchors.right: rowSwitch.left
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      text: row.detail
      elide: Text.ElideRight
      color: root.dimColor
      font.pixelSize: Style.font.body

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: row.moreRequested()
      }
    }

    ToggleSwitch {
      id: rowSwitch
      visible: row.switchVisible
      anchors.right: rowMore.left
      anchors.verticalCenter: parent.verticalCenter
      checked: row.switchOn
      foreground: root.barForeground
      onToggled: row.switchToggled()
    }

    Text {
      id: rowMore
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: Style.space(32)
      height: root.rowHeight
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      text: "›"
      color: root.dimColor
      font.pixelSize: Style.font.title

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: row.moreRequested()
      }
    }
  }
}
