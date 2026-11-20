import QtQuick
import QtQuick.Layouts
import QtCore
import Mahina
import "format.js" as Format

Window {
    id: root
    visible: true
    width: 1100
    height: 720
    minimumWidth: 760
    minimumHeight: 520
    title: "WatchBoard"
    color: Theme.background

    Settings {
        id: prefs
        category: "ui"
        property bool dark: false
        property int  tab: 0
    }

    // Mahina's *Subtle tokens are mode-independent (light). Swap in dark tints
    // so selected sidebar rows, ghost-button hovers, etc. don't glare.
    function applyMode() {
        const d = Theme.dark
        Theme.primarySubtle = d ? "#1F2B45" : "#EEF3FD"
        Theme.successSubtle = d ? "#1D2B22" : "#EEF8ED"
        Theme.warningSubtle = d ? "#33261A" : "#FEF4E7"
        Theme.errorSubtle   = d ? "#351E22" : "#FEF0F0"
        Theme.infoSubtle    = d ? "#172A3D" : "#EFF7FE"
    }
    function toggleTheme() {
        Theme.dark = !Theme.dark
        prefs.dark = Theme.dark
        applyMode()
    }

    Component.onCompleted: {
        Theme.dark = prefs.dark
        applyMode()
        sidebar.currentIndex = Math.max(0, Math.min(3, prefs.tab))
    }

    Shortcut { sequence: "Ctrl+D"; onActivated: root.toggleTheme() }
    Shortcut { sequence: "Ctrl+1"; onActivated: sidebar.currentIndex = 0 }
    Shortcut { sequence: "Ctrl+2"; onActivated: sidebar.currentIndex = 1 }
    Shortcut { sequence: "Ctrl+3"; onActivated: sidebar.currentIndex = 2 }
    Shortcut { sequence: "Ctrl+4"; onActivated: sidebar.currentIndex = 3 }
    Shortcut { sequence: "F1"; onActivated: about.open() }

    readonly property int connState: DeviceController.connectionState

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            // Brand header (Mahina's Sidebar header is text-only), then the nav.
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: false
                Layout.preferredWidth: 208
                Layout.maximumWidth: 208
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 56
                    color: Theme.panel

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp4
                        anchors.rightMargin: Theme.sp4
                        spacing: Theme.sp3

                        Logo { size: 28 }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "WatchBoard"
                                color: Theme.textPrimary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textBase
                                font.weight: Theme.weightSemibold
                                font.letterSpacing: -0.15
                            }
                            Text {
                                Layout.fillWidth: true
                                text: BoardInfo.boardName !== "" ? BoardInfo.boardName : "No board"
                                color: Theme.textSecondary
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.textXs
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // bottom + right hairlines, matching the Sidebar below
                    Rectangle { anchors { left: parent.left; right: parent.right; bottom: parent.bottom } height: 1; color: Theme.border }
                    Rectangle { anchors { top: parent.top; right: parent.right; bottom: parent.bottom } width: 1; color: Theme.border }
                }

                Sidebar {
                    id: sidebar
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.panel
                    model: [
                        { icon: Icons.house,         label: "Home" },
                        { icon: Icons.cpu,           label: "Pins" },
                        { icon: Icons.bracketsCurly, label: "Variables" },
                        { icon: Icons.terminal,      label: "Serial" }
                    ]
                    onCurrentIndexChanged: prefs.tab = currentIndex

                    Button {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Theme.sp3 }
                        variant: Button.Variant.Ghost
                        size: Button.Size.Sm
                        iconName: Theme.dark ? Icons.sun : Icons.moon
                        text: Theme.dark ? "Light theme" : "Dark theme"
                        onClicked: root.toggleTheme()
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                ConnectionBar { Layout.fillWidth: true }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: Theme.sp5
                    currentIndex: sidebar.currentIndex

                    HomePanel {}
                    PinGrid {}
                    VariablesPanel {}
                    SerialMonitor {}
                }
            }
        }

        StatusBar {
            Layout.fillWidth: true
            // Read-only state: no hand cursor, no hover tint.
            leftItems: {
                const s = root.connState
                const items = [{
                    icon: s === 2 ? Icons.plugsConnected : s === 3 ? Icons.warningCircle : Icons.plugs,
                    text: ["Disconnected", "Connecting…", "Connected", "Error"][s] ?? "Unknown",
                    color: s === 1 ? Theme.warning : s === 2 ? Theme.success : s === 3 ? Theme.error : Theme.textSecondary,
                    clickable: false
                }]
                if (s === 2 && DeviceController.activePort !== "")
                    items.push({ text: DeviceController.activePort, clickable: false })
                if (s === 2)
                    items.push({ icon: Icons.pulse, text: DeviceController.messageRate + " msg/s", clickable: false })
                return items
            }
            centerItems: root.connState === 3 && DeviceController.lastError !== ""
                         ? [{ text: DeviceController.lastError, color: Theme.error, clickable: false }] : []
            // Right side is drawn here rather than via rightItems: those size to
            // their text, so the ticking uptime would shove the version around.
            Row {
                anchors.right: parent.right
                anchors.rightMargin: Theme.sp3
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp3 * 2

                Row {
                    visible: root.connState === 2 && BoardInfo.uptimeMs > 0
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp1
                    Icon { anchors.verticalCenter: parent.verticalCenter; name: Icons.clock; size: 11; color: Theme.textSecondary }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "uptime " + Format.uptime(BoardInfo.uptimeMs)
                        color: Theme.textSecondary
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.textXs
                        font.features: { "tnum": 1 }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WatchBoard " + Qt.application.version
                    color: _ver.containsMouse ? Theme.textPrimary : Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textXs
                    MouseArea {
                        id: _ver
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: about.open()
                    }
                }
            }
        }
    }

    AboutDialog { id: about }
}
