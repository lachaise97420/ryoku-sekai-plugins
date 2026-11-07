import QtQuick

// SekaiPop's LyricsKey.qml: a small key under the lyrics (the sync keys), a
// sticker word that grows a little when you point at it and gives a click.
Item {
    id: root

    property var theme
    property string label: ""
    signal clicked

    implicitWidth: word.implicitWidth
    implicitHeight: word.implicitHeight
    width: implicitWidth
    height: implicitHeight

    scale: area.pressed ? 0.94 : (area.containsMouse ? 1.1 : 1)
    transformOrigin: Item.Center

    Behavior on scale {
        NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2 }
    }

    LyricsWord {
        id: word
        theme: root.theme
        text: root.label
        pixelSize: 15
        fillColor: area.containsMouse ? (root.theme ? root.theme.accentMint : "#00ffcb") : "#FFFFFF"
    }

    MouseArea {
        id: area
        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onClicked: root.clicked()
    }
}
