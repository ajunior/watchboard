import QtQuick
import QtQuick.Layouts
import Mahina

Rectangle {
    id: plotterRoot
    color: Theme.surface
    radius: Theme.radiusMd
    border.color: Theme.border
    border.width: 1

    // Exposed so a parent can pass a shared palette (e.g. VariablesPanel)
    property var lineColors: [
        Theme.primary, Theme.success, Theme.warning, Theme.error, Theme.info
    ]

    // Keys mapped to true are skipped in both scaling and drawing
    property var hiddenKeys: ({})

    EmptyState {
        anchors.centerIn: parent
        visible: WatchModel.sampleCount < 2
        icon: Icons.chartLine
        iconSize: 32
        title: "Nothing to plot yet"
        description: "Numeric variables are charted over time."
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sp4
        spacing: Theme.sp3

        RowLayout {
            spacing: Theme.sp2
            Icon { name: Icons.chartLine; size: 14; color: Theme.textSecondary }
            Text {
                text: "Plotter"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSm
                font.weight: Theme.weightSemibold
            }
        }

        Canvas {
            id: chart
            Layout.fillWidth: true
            Layout.fillHeight: true

            property var lineColors: plotterRoot.lineColors
            property var hiddenKeys: plotterRoot.hiddenKeys

            onHiddenKeysChanged: requestPaint()

            Connections {
                target: WatchModel
                function onPlotDataChanged() { chart.requestPaint() }
            }

            Connections {
                target: Theme
                function onDarkChanged() { chart.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                var samples = WatchModel.plotSamples()
                var n = samples.length
                if (n < 2) return

                var keys = WatchModel.watchKeys()
                if (keys.length === 0) return

                var tMin = samples[0].t
                var tMax = samples[n - 1].t
                var tRange = Math.max(tMax - tMin, 1)

                var hidden = chart.hiddenKeys
                var vMin = Infinity, vMax = -Infinity
                for (var i = 0; i < n; i++) {
                    var vs = samples[i].v
                    for (var k = 0; k < keys.length; k++) {
                        if (hidden[keys[k]]) continue
                        var val = vs[keys[k]]
                        if (typeof val === "number") {
                            if (val < vMin) vMin = val
                            if (val > vMax) vMax = val
                        }
                    }
                }
                if (!isFinite(vMin)) return

                var vRange = vMax - vMin
                if (vRange < 0.001) {
                    vMin -= 0.5; vMax += 0.5; vRange = 1
                } else {
                    vMin -= vRange * 0.08
                    vMax += vRange * 0.08
                    vRange = vMax - vMin
                }

                var ml = 52, mr = 8, mt = 8, mb = 20
                var cw = width  - ml - mr
                var ch = height - mt - mb

                function xp(t) { return ml + (t - tMin) / tRange * cw }
                function yp(v) { return mt + (1 - (v - vMin) / vRange) * ch }

                var gridLines = 4
                for (var gi = 0; gi <= gridLines; gi++) {
                    var gy = mt + gi / gridLines * ch
                    var gv = vMax - gi / gridLines * vRange

                    ctx.beginPath()
                    ctx.strokeStyle = Theme.border
                    ctx.lineWidth = 1
                    ctx.moveTo(ml, gy)
                    ctx.lineTo(ml + cw, gy)
                    ctx.stroke()

                    ctx.fillStyle = Theme.textSecondary
                    ctx.font = "10px '" + Theme.fontFamilyMono + "'"
                    ctx.textAlign = "right"
                    ctx.textBaseline = "middle"
                    ctx.fillText(gv.toFixed(1), ml - 4, gy)
                }

                var colors = chart.lineColors
                for (var ki = 0; ki < keys.length; ki++) {
                    var key = keys[ki]
                    if (hidden[key]) continue
                    ctx.beginPath()
                    ctx.strokeStyle = colors[ki % colors.length]
                    ctx.lineWidth = 1.75
                    ctx.lineJoin = "round"

                    var first = true
                    for (var si = 0; si < n; si++) {
                        var sv = samples[si].v[key]
                        if (typeof sv !== "number") continue
                        var x = xp(samples[si].t)
                        var y = yp(sv)
                        if (first) { ctx.moveTo(x, y); first = false }
                        else ctx.lineTo(x, y)
                    }
                    ctx.stroke()
                }

                ctx.fillStyle = Theme.textSecondary
                ctx.font = "10px '" + Theme.fontFamilyMono + "'"
                ctx.textBaseline = "alphabetic"
                ctx.textAlign = "left"
                ctx.fillText("−" + (tRange / 1000).toFixed(0) + "s", ml, height - 4)
                ctx.textAlign = "right"
                ctx.fillText("now", ml + cw, height - 4)
            }
        }
    }
}
