import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as QQC
import Mahina

// Top toolbar: port picker + refresh on the left, connect/disconnect on the right.
// Connection state lives in the StatusBar only.
Rectangle {
    id: bar
    implicitHeight: 56
    color: Theme.panel   // not surface: a white bar runs into the (white) light-mode title bar

    readonly property int connState: DeviceController.connectionState
    readonly property bool locked: connState === 1 || connState === 2

    Rectangle {
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        height: 1
        color: Theme.border
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.sp5
        anchors.rightMargin: Theme.sp5
        spacing: Theme.sp2

        Text {
            text: "Port"
            color: Theme.textSecondary
            font.family: Theme.fontFamily
            font.pixelSize: Theme.textSm
            font.weight: Theme.weightMedium
        }

        // Editable so virtual ports (/dev/pts/N) can be typed in.
        QQC.ComboBox {
            id: portCombo
            Layout.preferredWidth: 260
            implicitHeight: 32
            model: DeviceController.portList
            enabled: !bar.locked
            editable: true
            selectTextByMouse: true
            font.family: Theme.fontFamilyMono
            font.pixelSize: Theme.textSm

            HoverHandler { id: _comboHover }

            // Reflect the port actually in use (e.g. one passed via --port).
            function syncActive() {
                if (DeviceController.activePort !== "") editText = DeviceController.activePort
            }
            Component.onCompleted: syncActive()
            Connections {
                target: DeviceController
                function onActivePortChanged() { portCombo.syncActive() }
            }

            background: Rectangle {
                color: Theme.surfaceVariant
                radius: Theme.radiusSm
                border.width: 1
                border.color: portCombo.activeFocus ? Theme.primary
                            : _comboHover.hovered && portCombo.enabled ? Theme.borderStrong
                            : Theme.border
                Behavior on border.color { ColorAnimation { duration: Theme.durationFast } }
            }

            contentItem: QQC.TextField {
                leftPadding: Theme.sp3
                rightPadding: portCombo.indicator.width + Theme.sp2
                text: portCombo.editable ? portCombo.editText : portCombo.displayText
                color: enabled ? Theme.textPrimary : Theme.textSecondary
                font: portCombo.font
                placeholderText: "port or /dev/pts/…"
                placeholderTextColor: Theme.textDisabled
                selectionColor: Theme.primarySubtle
                selectedTextColor: Theme.primary
                verticalAlignment: Text.AlignVCenter
                background: null
                enabled: portCombo.enabled
            }

            indicator: Icon {
                x: portCombo.width - width - Theme.sp3
                y: (portCombo.height - height) / 2
                name: Icons.caretDown
                size: 14
                color: Theme.textSecondary
            }

            delegate: QQC.ItemDelegate {
                id: _opt
                required property int index
                required property var modelData
                width: ListView.view ? ListView.view.width : portCombo.width
                height: 30
                highlighted: portCombo.highlightedIndex === index
                contentItem: Text {
                    text: _opt.modelData
                    color: _opt.highlighted ? Theme.primary : Theme.textPrimary
                    font.family: Theme.fontFamilyMono
                    font.pixelSize: Theme.textSm
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideMiddle
                }
                background: Rectangle {
                    radius: Theme.radiusSm
                    color: _opt.highlighted ? Theme.primarySubtle : "transparent"
                }
            }

            popup: QQC.Popup {
                y: portCombo.height + Theme.sp1
                width: portCombo.width
                padding: Theme.sp1
                implicitHeight: Math.min(contentItem.implicitHeight + 2 * Theme.sp1, 260)
                contentItem: ListView {
                    clip: true
                    implicitHeight: contentHeight
                    model: portCombo.popup.visible ? portCombo.delegateModel : null
                    currentIndex: portCombo.highlightedIndex
                }
                background: Rectangle {
                    color: Theme.surface
                    radius: Theme.radiusMd
                    border.color: Theme.border
                }
            }
        }

        Button {
            variant: Button.Variant.Ghost
            iconOnly: true
            iconName: Icons.arrowClockwise
            enabled: !bar.locked
            onClicked: DeviceController.refreshPorts()
        }

        Item { Layout.fillWidth: true }

        Button {
            text: bar.connState === 2 ? "Disconnect" : bar.connState === 1 ? "Connecting…" : "Connect"
            variant: bar.connState === 2 ? Button.Variant.Danger : Button.Variant.Filled
            iconName: bar.connState === 2 ? Icons.plugs : Icons.plugsConnected
            enabled: portCombo.editText !== "" && bar.connState !== 1
            onClicked: {
                if (bar.connState === 2)
                    DeviceController.disconnectPort()
                else
                    DeviceController.connectToPort(portCombo.editText)
            }
        }
    }
}
