import QtQuick
import QtQuick.Layouts
import Mahina

// Small tinted tag: pin modes, connection state, SIM marker.
// Mahina's Badge uses the *Subtle tokens, which are light-only (they glare in
// dark mode), so this derives the tint from the tone colour instead.
Rectangle {
    id: root

    property string text: ""
    property color  tone: Theme.textSecondary
    property string iconName: ""
    property bool   pill: false      // fully rounded (status) vs. square tag
    property bool   dot: false       // leading status dot
    property bool   pulse: false     // animate the dot

    implicitWidth:  _row.implicitWidth + (pill ? Theme.sp3 : Theme.sp2) * 2
    implicitHeight: pill ? 24 : 18
    radius: pill ? height / 2 : Theme.radiusXs
    color: Qt.alpha(tone, Theme.dark ? 0.18 : 0.12)

    readonly property color _fg: Theme.dark ? Qt.lighter(tone, 1.2) : Qt.darker(tone, 1.25)

    RowLayout {
        id: _row
        anchors.centerIn: parent
        spacing: 6

        Rectangle {
            visible: root.dot
            width: 7; height: 7; radius: 3.5
            color: root._fg
            SequentialAnimation on opacity {
                running: root.pulse
                loops: Animation.Infinite
                onRunningChanged: if (!running) parent.opacity = 1
                NumberAnimation { to: 0.25; duration: 500; easing.type: Theme.easing }
                NumberAnimation { to: 1.0;  duration: 500; easing.type: Theme.easing }
            }
        }

        Icon {
            visible: root.iconName !== ""
            name: root.iconName
            size: 12
            color: root._fg
        }

        Text {
            text: root.text
            color: root._fg
            font.family: Theme.fontFamily
            font.pixelSize: root.pill ? Theme.textXs : 10
            font.weight: Theme.weightSemibold
            font.letterSpacing: root.pill ? 0.2 : 0.6
            font.capitalization: root.pill ? Font.MixedCase : Font.AllUppercase
        }
    }
}
