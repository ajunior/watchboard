import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs
import Mahina
import "../format.js" as Format

Item {
    id: root

    readonly property bool connected: DeviceController.connectionState === 2
    readonly property bool hasBoard: BoardInfo.boardName !== ""

    FileDialog {
        id: loadDialog
        fileMode: FileDialog.OpenFile
        nameFilters: ["WatchBoard profiles (*.json)", "All files (*)"]
        onAccepted: BoardProfile.load(selectedFile)
    }

    FileDialog {
        id: saveDialog
        fileMode: FileDialog.SaveFile
        defaultSuffix: "json"
        nameFilters: ["WatchBoard profiles (*.json)", "All files (*)"]
        onAccepted: BoardProfile.save(selectedFile)
    }

    // ── Reusable pieces ─────────────────────────────────────────────
    component Panel: Rectangle {
        color: Theme.surface
        radius: Theme.radiusMd
        border.color: Theme.border
        border.width: 1
    }

    component StatCard: Panel {
        id: stat
        property string label: ""
        property string value: "—"
        property string unit: ""
        property real ratio: -1        // 0..1 shows a meter
        property string iconName: ""

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 92

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Theme.sp4
            spacing: Theme.sp1

            RowLayout {
                spacing: Theme.sp2
                Icon { name: stat.iconName; size: 14; color: Theme.textSecondary; visible: stat.iconName !== "" }
                Text {
                    text: stat.label
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textXs
                    font.weight: Theme.weightMedium
                }
            }
            RowLayout {
                spacing: Theme.sp1
                Text {
                    text: stat.value
                    color: Theme.textPrimary
                    font.family: Theme.fontFamilyMono
                    font.pixelSize: Theme.text2xl
                    font.weight: Theme.weightSemibold
                    font.features: { "tnum": 1 }
                }
                Text {
                    Layout.alignment: Qt.AlignBaseline
                    visible: stat.unit !== "" && stat.value !== "—"
                    text: stat.unit
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSm
                }
            }
            Item { Layout.fillHeight: true }
            Rectangle {
                visible: stat.ratio >= 0
                Layout.fillWidth: true
                height: 4; radius: 2
                color: Theme.surfaceVariant
                Rectangle {
                    width: parent.width * Math.max(0, Math.min(1, stat.ratio))
                    height: parent.height; radius: 2
                    color: stat.ratio > 0.85 ? Theme.warning : Theme.primary
                    Behavior on width { NumberAnimation { duration: Theme.durationSlow; easing.type: Theme.easing } }
                }
            }
        }
    }

    component KeyText: Text {
        color: Theme.textSecondary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textSm
        Layout.preferredWidth: 80
    }
    component ValueText: Text {
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.textSm
        font.weight: Theme.weightMedium
        Layout.fillWidth: true
        elide: Text.ElideRight
    }

    // ── Layout ──────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.sp4

        // Header
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3

            Text {
                text: root.hasBoard ? BoardInfo.boardName : "No board connected"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textXl
                font.weight: Theme.weightSemibold
            }
            Pill { visible: BoardInfo.simulated; text: "Sim"; tone: Theme.primary }
            Text {
                visible: BoardProfile.loaded && BoardProfile.name !== ""
                text: "profile: " + BoardProfile.name
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSm
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Item { visible: !(BoardProfile.loaded && BoardProfile.name !== ""); Layout.fillWidth: true }

            Button {
                visible: BoardProfile.loaded
                variant: Button.Variant.Ghost
                size: Button.Size.Sm
                iconName: Icons.floppyDisk
                text: "Save"
                onClicked: BoardProfile.save()
            }
            Button {
                variant: Button.Variant.Outlined
                size: Button.Size.Sm
                iconName: BoardProfile.loaded ? Icons.floppyDisk : Icons.folderOpen
                text: BoardProfile.loaded ? "Save As…" : "Load Profile"
                onClicked: BoardProfile.loaded ? saveDialog.open() : loadDialog.open()
            }
        }

        // Stats
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3

            StatCard {
                label: "Message rate"
                iconName: Icons.pulse
                value: root.connected ? String(DeviceController.messageRate) : "—"
                unit: "msg/s"
            }
            StatCard {
                label: "Uptime"
                iconName: Icons.clock
                value: Format.uptime(BoardInfo.uptimeMs)
            }
            StatCard {
                label: "Free RAM"
                iconName: Icons.memory
                value: BoardInfo.freeRam > 0 ? String(Math.round(BoardInfo.freeRam / 1024)) : "—"
                unit: BoardInfo.minFreeRam > 0 ? "KB · min " + Math.round(BoardInfo.minFreeRam / 1024) + " KB" : "KB"
            }
            StatCard {
                label: "Flash"
                iconName: Icons.hardDrive
                value: BoardInfo.flashSize > 0
                    ? (BoardInfo.sketchSize > 0 ? String(Math.round(BoardInfo.sketchSize / 1024)) : "—")
                    : "—"
                unit: BoardInfo.flashSize > 0 ? "KB / " + Math.round(BoardInfo.flashSize / (1024 * 1024)) + " MB" : ""
                ratio: BoardInfo.flashSize > 0 && BoardInfo.sketchSize > 0 ? BoardInfo.sketchSize / BoardInfo.flashSize : -1
            }
        }

        // Details + labels
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3

            Panel {
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                Layout.alignment: Qt.AlignTop
                implicitHeight: _details.implicitHeight + Theme.sp4 * 2

                ColumnLayout {
                    id: _details
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.sp4 }
                    spacing: Theme.sp3

                    Text {
                        text: "Board"
                        color: Theme.textPrimary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSm
                        font.weight: Theme.weightSemibold
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 4
                        columnSpacing: Theme.sp4
                        rowSpacing: Theme.sp2

                        KeyText { text: "Status" }
                        ValueText {
                            text: (["Disconnected", "Connecting…", "Connected", "Error"])[DeviceController.connectionState] ?? "—"
                            color: DeviceController.connectionState === 2 ? Theme.success
                                 : DeviceController.connectionState === 3 ? Theme.error
                                 : DeviceController.connectionState === 1 ? Theme.warning
                                 : Theme.textPrimary
                        }
                        KeyText { text: "Port" }
                        ValueText { text: DeviceController.activePort || "—"; font.family: Theme.fontFamilyMono; elide: Text.ElideMiddle }

                        KeyText { text: "CPU" }
                        ValueText {
                            text: BoardInfo.cpuMhz > 0
                                ? BoardInfo.cpuMhz + " MHz" + (BoardInfo.cores > 1 ? " · " + BoardInfo.cores + " cores" : "")
                                : "—"
                        }
                        KeyText { text: "Reset" }
                        ValueText { text: BoardInfo.resetReason || "—" }

                        KeyText { text: "Pins" }
                        ValueText { text: PinModel.totalCount > 0 ? String(PinModel.totalCount) : "—" }
                        KeyText { text: "Analog" }
                        ValueText { text: PinModel.totalCount > 0 ? String(PinModel.analogCount) : "—" }

                        KeyText { text: "Digital I/O" }
                        ValueText {
                            text: PinModel.totalCount > 0
                                ? (PinModel.digitalCount - PinModel.outputCount) + " in / " + PinModel.outputCount + " out"
                                : "—"
                        }
                        Item {} Item {}
                    }
                }
            }

            Panel {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                Layout.alignment: Qt.AlignTop
                implicitHeight: _labels.implicitHeight + Theme.sp4 * 2

                ColumnLayout {
                    id: _labels
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: Theme.sp4 }
                    spacing: Theme.sp2

                    readonly property var items: { BoardProfile.revision; return BoardProfile.labelList() }

                    RowLayout {
                        spacing: Theme.sp2
                        Icon { name: Icons.tag; size: 14; color: Theme.textSecondary }
                        Text {
                            text: "Labels"
                            color: Theme.textPrimary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textSm
                            font.weight: Theme.weightSemibold
                        }
                    }

                    Repeater {
                        model: _labels.items
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: Theme.sp2
                            Text {
                                text: modelData.pinId
                                color: Theme.textSecondary
                                font.family: Theme.fontFamilyMono
                                font.pixelSize: Theme.textSm
                                font.weight: Theme.weightSemibold
                                Layout.preferredWidth: 44
                            }
                            Icon { name: Icons.arrowRight; size: 12; color: Theme.textDisabled }
                            Text {
                                text: modelData.label
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textSm
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Text {
                        visible: _labels.items.length === 0
                        Layout.fillWidth: true
                        text: "No labels yet. Double-click a pin in Pins to rename it."
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textSm
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
