import QtQuick
import QtQuick.Window
import qs.Commons
import qs.Commons as Commons

Item {
  id: root

  property string text: ""
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.body
  property color color: Commons.Color.foreground
  property bool debugBounds: false

  readonly property int renderedFontSize: Math.max(1, Math.round(fontSize))
  // TextMetrics reports whole pixels; measuring at 8x keeps the fraction the ink needs to centre.
  readonly property int metricsScale: 8
  readonly property real tightX: glyphMetrics.tightBoundingRect.x / metricsScale
  readonly property real tightWidth: Math.max(1, glyphMetrics.tightBoundingRect.width / metricsScale)
  readonly property real paintedCenterX: glyph.x + tightX + tightWidth / 2
  readonly property real baselineY: glyph.y + glyph.baselineOffset

  TextMetrics {
    id: glyphMetrics
    font.family: root.fontFamily
    font.pixelSize: root.renderedFontSize * root.metricsScale
    text: root.text
  }

  Text {
    id: glyph
    textFormat: Text.PlainText
    // Keep the shared line box and baseline intact. Correcting only the
    // horizontal painted bounds avoids per-glyph vertical drift. The ink is
    // centred in one step, snapped to device pixels: anchoring the box centred
    // and then offsetting it rounds twice to whole logical pixels, which on a
    // 2x screen leaves the ink up to a few device pixels off.
    anchors.verticalCenter: parent.verticalCenter
    x: Math.round((root.width / 2 - (root.tightX + root.tightWidth / 2)) * Screen.devicePixelRatio) / Screen.devicePixelRatio
    text: root.text
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.renderedFontSize
    renderType: Text.NativeRendering
  }

  Rectangle {
    visible: root.debugBounds
    anchors.fill: parent
    color: "transparent"
    border.width: 1
    border.color: "#4488ff"
  }

  Rectangle {
    visible: root.debugBounds
    x: 0
    y: Math.round(root.baselineY)
    width: parent.width
    height: 1
    color: "#44ff88"
  }
}
