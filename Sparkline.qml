import QtQuick
import qs.Commons

Canvas {
  id: root

  property var points: []
  property color lineColor: Color.accent
  property real lineWidth: 1.5

  onPointsChanged: requestPaint()
  onLineColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()
  onVisibleChanged: if (visible) requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.clearRect(0, 0, width, height)
    var src = root.points
    if (!src || src.length < 2 || width < 2 || height < 2) return

    var min = Infinity
    var max = -Infinity
    var values = []
    for (var i = 0; i < src.length; i++) {
      var v = Number(src[i])
      if (!isFinite(v)) continue
      values.push(v)
      if (v < min) min = v
      if (v > max) max = v
    }
    if (values.length < 2) return
    if (min === max) max = min + 1

    var pad = 1
    var innerH = Math.max(1, height - pad * 2)
    var innerW = Math.max(1, width - pad * 2)

    ctx.beginPath()
    ctx.strokeStyle = root.lineColor
    ctx.lineWidth = root.lineWidth
    ctx.lineJoin = "round"
    ctx.lineCap = "round"
    for (var j = 0; j < values.length; j++) {
      var x = pad + (j / (values.length - 1)) * innerW
      var y = pad + (1 - (values[j] - min) / (max - min)) * innerH
      if (j === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.stroke()
  }
}
