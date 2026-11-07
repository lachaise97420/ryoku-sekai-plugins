import QtQuick
import QtQuick.Controls
import Quickshell

// SekaiPop's FramerCard, in a Popup because a Ryoku plugin cannot add a layer
// surface. The framer, its work area, keys and keyboard handling are SekaiPop's.
Popup {
    id: win

    property var theme
    property var service
    property var screen

    visible: false

    readonly property real f: {
        if (!win.parent)
            return 1
        const o = win.parent.mapToItem(null, 0, 0)
        const u = win.parent.mapToItem(null, 1, 1)
        const k = Math.hypot(u.x - o.x, u.y - o.y)
        return (isFinite(k) && k > 0.01) ? k : 1
    }

    readonly property real k: {
        const roomW = win.screen ? win.screen.width : 1920
        const roomH = win.screen ? win.screen.height : 1080
        return Math.min(1, (roomW - 40) / 1010, (roomH - 40) / 720)
    }

    width: win.screen ? win.screen.width : 1920
    height: win.screen ? win.screen.height : 1080
    padding: 0
    margins: 0
    background: null
    modal: false
    dim: false
    closePolicy: Popup.NoAutoClose
    focus: true

    Connections {
        target: win.service
        function onFramingChanged() {
            if (win.service && win.service.framing !== "")
                win.open()
            else
                win.close()
        }
    }

    Component.onCompleted: {
        if (win.service && win.service.framing !== "")
            win.open()
    }

    onServiceChanged: {
        if (win.service && win.service.framing !== "")
            win.open()
    }

    function place() {
        if (!win.parent)
            return
        const scene = win.parent.mapToItem(null, 0, 0)
        win.x = (0 - scene.x) / win.f
        win.y = (0 - scene.y) / win.f
        win.width = win.screen ? win.screen.width : 1920
        win.height = win.screen ? win.screen.height : 1080
    }

    onAboutToShow: {
        win.place()
        Qt.callLater(() => {
            const f = framerLoader.item
            if (f)
                f.forceActiveFocus()
        })
    }

    // Scrim.
    Rectangle {
        anchors.fill: parent
        color: win.theme.scrim
        opacity: 0.82
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel.accepted = true
    }

    Item {
        id: holder
        width: 1010 * win.k
        height: 720 * win.k
        anchors.centerIn: parent

        Loader {
            id: framerLoader
            anchors.centerIn: parent
            active: win.service !== null
            sourceComponent: FramerCard {
                width: 1010
                height: 720
                transformOrigin: Item.TopLeft
                scale: win.k
                theme: win.theme
                service: win.service
                kind: win.service && win.service.framing !== "" ? win.service.framing : "banner"
                fresh: win.service ? win.service.framingFresh : false
                onFinished: saved => {
                    if (win.service)
                        win.service.closeFramer(saved)
                }
            }
        }
    }
}
