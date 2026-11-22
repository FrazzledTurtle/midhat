import QtQuick

// Ruling behind the whole page: blank, lined, dotted or grid.
Item {
  id: root
  property string kind: "blank"
  property color color: "#bdbdbd"
  property real spacing: 32
  property real phase: 20

  readonly property int rows: kind === "blank" ? 0 : Math.max(0, Math.ceil((height - phase) / spacing))
  readonly property int columns: Math.floor(width / spacing)

  Repeater {
    model: root.kind === "lined" || root.kind === "grid" ? root.rows : 0
    Rectangle {
      required property int index
      y: root.phase + index * root.spacing
      width: root.width
      height: 1
      color: root.color
    }
  }

  Repeater {
    model: root.kind === "grid" ? root.columns + 1 : 0
    Rectangle {
      required property int index
      x: index * root.spacing
      width: 1
      height: root.height
      color: root.color
    }
  }

  Repeater {
    model: root.kind === "dotted" ? root.rows : 0
    Item {
      id: row
      required property int index
      y: root.phase + index * root.spacing
      width: root.width
      Repeater {
        model: root.columns + 1
        Rectangle {
          required property int index
          x: index * root.spacing - 1.5
          y: -1.5
          width: 3
          height: 3
          radius: 1.5
          color: root.color
        }
      }
    }
  }
}
