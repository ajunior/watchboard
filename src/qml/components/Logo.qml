import QtQuick
import QtQuick.Layouts

// WatchBoard mark — rendered from assets/logo.svg so the in-app logo and the
// window icon share one source.
Image {
    property int size: 26
    Layout.preferredWidth: size
    Layout.preferredHeight: size
    width: size
    height: size
    source: "qrc:/qt/qml/WatchBoard/assets/logo.svg"
    sourceSize: Qt.size(size * Screen.devicePixelRatio, size * Screen.devicePixelRatio)
    smooth: true
    mipmap: true
}
