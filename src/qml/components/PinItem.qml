import QtQuick
import QtQuick.Layouts
import Mahina

Rectangle {
    id: root

    property string pinId: ""
    property string pinMode: ""
    property int pinValue: 0
    property bool pinIsAnalog: false
    property int pinMaxValue: 1023
    property var pinHistory: []
    property int modelIndex: -1
    property string pinLabel: ""

    property bool _editing: false

    // Formatted display ID, mirroring the original prefix logic
    readonly property string displayId: pinIsAnalog
        ? "A" + pinId.replace("A", "")
        : "D" + pinId

    readonly property bool _high: !pinIsAnalog && pinValue === 1
    readonly property color _tone: pinIsAnalog ? Theme.warning
                                 : pinMode === "OUTPUT" ? Theme.primary
                                 : Theme.info
    readonly property string _badgeText: pinIsAnalog ? "Analog" : pinMode.replace("_", " ")

    function startEdit() {
        nameInput.text = root.pinLabel
        root._editing = true
        nameInput.forceActiveFocus()
        nameInput.selectAll()
    }

    function commitEdit() {
        const txt = nameInput.text.trim()
        if (txt !== "" && txt !== root.displayId) {
            BoardProfile.setLabel(root.pinId, txt)
        } else {
            BoardProfile.clearLabel(root.pinId)
        }
        root._editing = false
    }

    // Analog cards span two digital columns (2 × 132 + spacing).
    width: pinIsAnalog ? 276 : 132
    height: pinIsAnalog ? 132 : 100
    color: Theme.surface
    radius: Theme.radiusMd
    border.width: 1
    border.color: root._high ? Qt.alpha(Theme.success, 0.6)
                : _hover.hovered ? Theme.borderStrong
                : Theme.border
    Behavior on border.color { ColorAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }

    HoverHandler { id: _hover }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.sp3
        spacing: Theme.sp2

        // ── Header: ID (+ label) and mode tag ───────────────────────
        RowLayout {
            visible: !root._editing
            Layout.fillWidth: true
            spacing: Theme.sp2

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.pinLabel !== "" ? root.pinLabel : root.displayId
                    color: Theme.textPrimary
                    font.family: root.pinLabel !== "" ? Theme.fontFamily : Theme.fontFamilyMono
                    font.pixelSize: root.pinLabel !== "" ? Theme.textSm : Theme.textBase
                    font.weight: Theme.weightSemibold
                    elide: Text.ElideRight

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onDoubleClicked: root.startEdit()
                    }
                }
                Text {
                    visible: root.pinLabel !== ""
                    text: root.displayId
                    color: Theme.textSecondary
                    font.family: Theme.fontFamilyMono
                    font.pixelSize: Theme.textXs
                }
            }

            Pill {
                Layout.alignment: Qt.AlignTop
                text: root._badgeText
                tone: root._tone
            }
        }

        // ── Edit mode ───────────────────────────────────────────────
        Rectangle {
            visible: root._editing
            Layout.fillWidth: true
            implicitHeight: 26
            color: Theme.surfaceVariant
            border.color: Theme.primary
            border.width: 1
            radius: Theme.radiusSm

            TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: Theme.sp2
                anchors.rightMargin: Theme.sp2
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.textPrimary
                selectionColor: Theme.primarySubtle
                selectedTextColor: Theme.primary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textSm
                font.weight: Theme.weightSemibold
                maximumLength: 20
                clip: true

                Keys.onReturnPressed: root.commitEdit()
                Keys.onEnterPressed: root.commitEdit()
                Keys.onEscapePressed: root._editing = false
                onActiveFocusChanged: if (!activeFocus && root._editing) root._editing = false
            }
        }

        Item { Layout.fillHeight: true; visible: !root.pinIsAnalog }

        // ── Digital: level + output switch ──────────────────────────
        RowLayout {
            visible: !root.pinIsAnalog
            Layout.fillWidth: true
            spacing: Theme.sp2

            Rectangle {
                width: 8; height: 8; radius: 4
                color: root._high ? Theme.success : Theme.textDisabled
                border.width: root._high ? 3 : 0
                border.color: Qt.alpha(Theme.success, 0.25)
            }
            Text {
                text: root._high ? "HIGH" : "LOW"
                color: root._high ? Theme.success : Theme.textSecondary
                font.family: Theme.fontFamilyMono
                font.pixelSize: Theme.textBase
                font.weight: Theme.weightSemibold
            }

            Item { Layout.fillWidth: true }

            // Value comes from the model, so this is a plain track + thumb
            // rather than a Toggle (whose own `checked` would fight the model).
            Rectangle {
                visible: root.pinMode === "OUTPUT" && !BoardInfo.simulated
                width: 34; height: 20; radius: 10
                color: root._high ? Theme.success : Theme.border
                Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

                Rectangle {
                    x: root._high ? parent.width - width - 3 : 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 14; height: 14; radius: 7
                    color: Theme.surface
                    Behavior on x { NumberAnimation { duration: Theme.durationNormal; easing.type: Theme.easing } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: PinModel.togglePin(root.modelIndex)
                }
            }
        }

        // ── Analog: value, volts-ish ratio, sparkline ───────────────
        RowLayout {
            visible: root.pinIsAnalog
            Layout.fillWidth: true
            spacing: Theme.sp2

            Text {
                text: root.pinValue
                color: Theme.textPrimary
                font.family: Theme.fontFamilyMono
                font.pixelSize: Theme.textXl
                font.weight: Theme.weightSemibold
                font.features: { "tnum": 1 }
            }
            Text {
                Layout.alignment: Qt.AlignBaseline
                text: "/ " + root.pinMaxValue
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMono
                font.pixelSize: Theme.textXs
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Math.round(root.pinValue / Math.max(root.pinMaxValue, 1) * 100) + "%"
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMono
                font.pixelSize: Theme.textXs
            }
        }

        Sparkline {
            visible: root.pinIsAnalog
            Layout.fillWidth: true
            Layout.fillHeight: true
            type: "area"
            color: Theme.warning
            values: root.pinHistory.length >= 2 ? root.pinHistory : [root.pinValue, root.pinValue]
        }
    }
}
