// The canvas everything sits on: parchment with a fine grid, like the
// measuring paper of an instrument. Drawn once per size.
import QtQuick

Canvas {
    id: c
    property color base: app.cBg
    property color line: app.cGrid
    property int step: 8
    renderStrategy: Canvas.Immediate

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.fillStyle = base
        ctx.fillRect(0, 0, width, height)
        ctx.strokeStyle = line
        ctx.lineWidth = 1
        ctx.beginPath()
        for (var x = 0.5; x < width; x += step) { ctx.moveTo(x, 0); ctx.lineTo(x, height) }
        for (var y = 0.5; y < height; y += step) { ctx.moveTo(0, y); ctx.lineTo(width, y) }
        ctx.stroke()
    }
}
