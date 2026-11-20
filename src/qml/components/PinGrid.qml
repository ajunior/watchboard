import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic as QQC
import Mahina

Item {
    id: root
    readonly property bool helloReceived: BoardInfo.boardName !== ""

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.sp4

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp3

            Text {
                text: "Pins"
                color: Theme.textPrimary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textXl
                font.weight: Theme.weightSemibold
            }
            Text {
                visible: root.helloReceived
                text: PinModel.digitalCount + " digital · " + PinModel.analogCount + " analog"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSm
            }

            Item { Layout.fillWidth: true }

            Input {
                id: searchField
                visible: root.helloReceived
                Layout.preferredWidth: 220
                leadingIcon: Icons.magnifyingGlass
                placeholderText: "Filter pins…"
                font.pixelSize: Theme.textSm
                onTextChanged: PinModel.setFilterText(text)
                Keys.onEscapePressed: clear()
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            QQC.ScrollView {
                id: scrollView
                anchors.fill: parent
                clip: true
                visible: root.helloReceived
                contentWidth: availableWidth

                Flow {
                    width: scrollView.availableWidth
                    spacing: Theme.sp3

                    Repeater {
                        model: PinModel
                        delegate: PinItem {
                            pinId: model.pinId
                            pinMode: model.pinMode
                            pinValue: model.pinValue
                            pinIsAnalog: model.pinIsAnalog
                            pinMaxValue: model.pinMaxValue
                            pinHistory: model.pinHistory ?? []
                            pinLabel: model.pinLabel ?? ""
                            modelIndex: index
                        }
                    }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: !root.helloReceived
                icon: DeviceController.connectionState === 2 ? Icons.hourglass : Icons.plugs
                title: DeviceController.connectionState === 2 ? "Waiting for board info…" : "No pins yet"
                description: DeviceController.connectionState === 2
                    ? "The board hasn't sent its hello message."
                    : "Pick a port in the toolbar and connect a device."
            }
        }
    }
}
