import QtQuick
import QtQuick.Layouts
import Mahina

// Help → About. Versions come from AppInfo (set in main.cpp from CMake).
Dialog {
    id: dlg
    title: "About"
    preferredWidth: 540

    readonly property string repoUrl: AppInfo.repoUrl

    ColumnLayout {
        width: parent.width
        spacing: Theme.sp4

        // ── Identity: [logo name] | [version / tagline] ──────────────────────
        // The mark is sized to the text block beside it, so both halves line up.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.sp4

            RowLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.sp3
                Logo { size: Math.round(_info.implicitHeight) }
                Text {
                    text: "WatchBoard"
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.text2xl
                    font.weight: Theme.weightSemibold
                    font.letterSpacing: -0.4
                }
            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 1
                color: Theme.border
            }

            ColumnLayout {
                id: _info
                Layout.preferredWidth: 250
                Layout.alignment: Qt.AlignVCenter
                spacing: Theme.sp1
                Text {
                    text: "Version " + AppInfo.version
                    color: Theme.textPrimary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSm
                    font.weight: Theme.weightSemibold
                    font.features: { "tnum": 1 }
                }
                Text {
                    Layout.preferredWidth: 250
                    wrapMode: Text.WordWrap
                    text: "See what your microcontroller is doing in real time: pins, variables, and serial."
                    color: Theme.textSecondary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.textSm
                    lineHeight: 1.25
                }
            }
        }

        // ── Build details ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: _details.implicitHeight + Theme.sp3 * 2
            radius: Theme.radiusMd
            color: Theme.panel
            border.color: Theme.border

            ColumnLayout {
                id: _details
                anchors { fill: parent; margins: Theme.sp3; leftMargin: Theme.sp4; rightMargin: Theme.sp4 }
                spacing: Theme.sp2

                Repeater {
                    model: [
                        ["Qt",      AppInfo.qtVersion],
                        ["Mahina",  AppInfo.mahinaVersion],
                        ["License", "GPL-3.0"]
                    ]
                    delegate: Item {
                        id: row
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: _k.implicitHeight
                        Text {
                            id: _k
                            text: row.modelData[0]
                            color: Theme.textSecondary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.textSm
                        }
                        Text {
                            anchors.right: parent.right
                            text: row.modelData[1]
                            color: Theme.textPrimary
                            font.family: Theme.fontFamilyMono
                            font.pixelSize: Theme.textSm
                        }
                    }
                }
            }
        }
    }

    // Closed with the header's ×, Esc, or a click outside — no Close button.
    // Mahina's footer is a right-aligned Row; the copyright takes the width the
    // buttons leave so it sits at the left edge, under the divider.
    footer: [
        Item {
            width: Math.min(dlg.preferredWidth, dlg.width - Theme.sp8 * 2) - Theme.sp4 * 2
                   - _gh.width - _bug.width - Theme.sp2 * 2
            height: _gh.height
            Text {
                x: Theme.sp6 - Theme.sp4   // line up with the body (sp6 margin; the footer Row has sp4)
                anchors.verticalCenter: parent.verticalCenter
                text: "© 2026 Adjamilton Junior"
                color: Theme.textSecondary
                font.family: Theme.fontFamily
                font.pixelSize: Theme.textXs
            }
        },
        Button {
            id: _gh
            variant: Button.Variant.Ghost
            size: Button.Size.Sm
            iconName: Icons.githubLogo
            text: "GitHub"
            onClicked: Qt.openUrlExternally(dlg.repoUrl)
        },
        Button {
            id: _bug
            variant: Button.Variant.Ghost
            size: Button.Size.Sm
            iconName: Icons.bug
            text: "Report an issue"
            onClicked: Qt.openUrlExternally(dlg.repoUrl + "/issues/new")
        }
    ]
}
