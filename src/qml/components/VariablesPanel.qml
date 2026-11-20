import QtQuick
import QtQuick.Layouts
import Mahina

ColumnLayout {
    id: root
    spacing: Theme.sp4

    // Single source of truth — table and plot both index into this
    readonly property var lineColors: [
        Theme.primary, Theme.success, Theme.warning, Theme.error, Theme.info
    ]

    // Keys mapped to true when hidden; a new object is assigned on each toggle
    // so property bindings fire correctly
    property var hiddenKeys: ({})

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp3
        Text {
            text: "Variables"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textXl
            font.weight: Theme.weightSemibold
        }
        Text {
            text: WatchModel.count > 0 ? WatchModel.count + " watched · click a dot to hide its line" : ""
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSm
        }
        Item { Layout.fillWidth: true }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.sp3

        // Current values
        Rectangle {
            Layout.preferredWidth: 260
            Layout.fillHeight: true
            color: Theme.surface
            radius: Theme.radiusMd
            border.color: Theme.border
            border.width: 1
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 1
                spacing: 0

                // Header row
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    color: Theme.surfaceVariant
                    radius: Theme.radiusMd
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: Theme.radiusMd; color: parent.color }
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp4
                        anchors.rightMargin: Theme.sp4
                        Text { text: "NAME"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.textXs; font.weight: Theme.weightSemibold; font.letterSpacing: 0.6; Layout.fillWidth: true }
                        Text { text: "VALUE"; color: Theme.textSecondary; font.family: Theme.fontFamily; font.pixelSize: Theme.textXs; font.weight: Theme.weightSemibold; font.letterSpacing: 0.6 }
                    }
                }

                ListView {
                    id: list
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: WatchModel

                    delegate: Rectangle {
                        id: row
                        required property int index
                        required property var model
                        width: ListView.view.width
                        height: 34
                        color: index % 2 === 1 ? Theme.surfaceVariant : "transparent"

                        property color varColor: root.lineColors[index % root.lineColors.length]
                        property bool hidden: !!root.hiddenKeys[model.watchKey]
                        property bool isNumeric: !isNaN(Number(model.watchValue))

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.sp4
                            anchors.rightMargin: Theme.sp4
                            spacing: Theme.sp2
                            opacity: row.isNumeric && row.hidden ? 0.4 : 1.0

                            // Numeric: swatch toggles the plot line. String: dash.
                            Rectangle {
                                width: 10; height: row.isNumeric ? 10 : 2
                                radius: Theme.radiusXs
                                Layout.alignment: Qt.AlignVCenter
                                color: row.isNumeric && row.hidden ? "transparent" : row.varColor
                                border.color: row.varColor
                                border.width: row.isNumeric ? 1.5 : 0

                                MouseArea {
                                    enabled: row.isNumeric
                                    anchors.fill: parent
                                    anchors.margins: -6
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        var h = Object.assign({}, root.hiddenKeys)
                                        h[row.model.watchKey] = !h[row.model.watchKey]
                                        root.hiddenKeys = h
                                    }
                                }
                            }

                            Text {
                                text: row.model.watchKey
                                color: Theme.textPrimary
                                font.family: Theme.fontFamilyMono
                                font.pixelSize: Theme.textSm
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }

                            Text {
                                text: row.isNumeric ? Number(row.model.watchValue).toFixed(2) : row.model.watchValue
                                color: Theme.textPrimary
                                font.family: Theme.fontFamilyMono
                                font.pixelSize: Theme.textSm
                                font.weight: Theme.weightMedium
                                font.features: { "tnum": 1 }
                                horizontalAlignment: Text.AlignRight
                                Layout.maximumWidth: 110
                                elide: Text.ElideRight
                            }
                        }
                    }

                    EmptyState {
                        anchors.centerIn: parent
                        width: parent.width - Theme.sp8
                        visible: WatchModel.count === 0
                        icon: Icons.bracketsCurly
                        iconSize: 32
                        title: "No variables"
                        description: "Values sent with WB.watch() show up here."
                    }
                }
            }
        }

        // History plot — receives both the palette and the hidden-key set
        WatchPlotter {
            Layout.fillWidth: true
            Layout.fillHeight: true
            lineColors: root.lineColors
            hiddenKeys: root.hiddenKeys
        }
    }
}
