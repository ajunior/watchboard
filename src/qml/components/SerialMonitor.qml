import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as QQC
import QtQuick.Dialogs
import Mahina

ColumnLayout {
    id: root
    spacing: Theme.sp4

    readonly property bool connected: DeviceController.connectionState === 2

    // Sent-line history, newest last; Up/Down walk it like a shell.
    property var history: []
    property int historyPos: -1     // -1 = editing a fresh line
    property string draft: ""

    function send() {
        const line = sendField.text
        if (!DeviceController.sendLine(line)) return
        if (history.length === 0 || history[history.length - 1] !== line)
            history = history.concat([line]).slice(-50)
        historyPos = -1
        draft = ""
        sendField.clear()
        logView.positionViewAtEnd()
    }
    function recall(step) {
        if (history.length === 0) return
        if (historyPos === -1) {
            if (step > 0) return
            draft = sendField.text
            historyPos = history.length - 1
        } else {
            historyPos += step
            if (historyPos >= history.length) {
                historyPos = -1
                sendField.text = draft
                return
            }
            historyPos = Math.max(0, historyPos)
        }
        sendField.text = history[historyPos]
        sendField.cursorPosition = sendField.text.length
    }

    FileDialog {
        id: saveDialog
        fileMode: FileDialog.SaveFile
        defaultSuffix: "log"
        nameFilters: ["Log files (*.log)", "Text files (*.txt)", "All files (*)"]
        onAccepted: SerialLog.saveLog(selectedFile)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp3

        Text {
            text: "Serial monitor"
            color: Theme.textPrimary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textXl
            font.weight: Theme.weightSemibold
        }
        Text {
            text: logView.count > 0 ? logView.count + " lines" : ""
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSm
        }

        Item { Layout.fillWidth: true }

        Button {
            variant: Button.Variant.Outlined
            size: Button.Size.Sm
            iconName: Icons.floppyDisk
            text: "Save"
            enabled: logView.count > 0
            onClicked: saveDialog.open()
        }
        Button {
            variant: Button.Variant.Ghost
            size: Button.Size.Sm
            iconName: Icons.broom
            text: "Clear"
            enabled: logView.count > 0
            onClicked: SerialLog.clear()
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Theme.surface
        radius: Theme.radiusMd
        border.color: Theme.border
        border.width: 1

        ListView {
            id: logView
            anchors.fill: parent
            anchors.margins: 1
            anchors.topMargin: Theme.sp2
            anchors.bottomMargin: Theme.sp2
            model: SerialLog
            clip: true

            QQC.ScrollBar.vertical: QQC.ScrollBar {
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: Theme.borderStrong
                    opacity: parent.active ? 1 : 0.5
                }
            }

            // Stick to bottom as new entries arrive; if user scrolls up, don't force back
            onCountChanged: {
                if (atYEnd || count <= 1)
                    Qt.callLater(positionViewAtEnd)
            }

            delegate: Rectangle {
                id: line
                required property var model
                width: logView.width
                height: 22
                readonly property bool rx: model.direction === 0
                // RX green, TX orange: distinct hues so direction reads at a glance,
                // and TX rows get a faint tint so they stand out while scrolling.
                readonly property color dirColor: rx ? Theme.success : Theme.warning
                color: _lineHover.hovered ? Theme.surfaceVariant
                     : rx ? "transparent" : Qt.alpha(Theme.warning, Theme.dark ? 0.10 : 0.08)

                HoverHandler { id: _lineHover }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.sp4
                    anchors.rightMargin: Theme.sp4
                    spacing: Theme.sp2

                    Text {
                        text: line.model.timestamp
                        color: Theme.textDisabled
                        font.family: Theme.fontFamilyMono
                        font.pixelSize: 12
                        font.features: { "tnum": 1 }
                    }
                    Icon {
                        name: line.rx ? Icons.arrowDownLeft : Icons.arrowUpRight
                        size: 14
                        color: line.dirColor
                    }
                    Text {
                        Layout.fillWidth: true
                        text: line.model.content
                        color: Theme.textPrimary
                        font.family: Theme.fontFamilyMono
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: logView.count === 0
                icon: Icons.terminal
                iconSize: 32
                title: "No serial traffic yet"
                description: "Lines sent and received on the port appear here."
            }
        }
    }

    // ── Send to board ────────────────────────────────────────────────
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.sp2

        Input {
            id: sendField
            Layout.fillWidth: true
            leadingIcon: Icons.caretRight
            enabled: root.connected
            font.family: Theme.fontFamilyMono
            font.pixelSize: Theme.textSm
            placeholderText: root.connected ? "Send a line to the board  (Enter to send, ↑↓ history)"
                                            : "Connect to a board to send data"
            Keys.onReturnPressed: root.send()
            Keys.onEnterPressed: root.send()
            Keys.onUpPressed: root.recall(-1)
            Keys.onDownPressed: root.recall(1)
        }
        Button {
            variant: Button.Variant.Filled
            iconName: Icons.paperPlaneRight
            text: "Send"
            enabled: root.connected && sendField.text !== ""
            onClicked: { root.send(); sendField.forceActiveFocus() }
        }
    }
}
