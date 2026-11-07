import QtQuick
import QtQuick.Controls
import Quickshell

// SekaiPop's PicturesRow (banner + avatar), in a Popup because a Ryoku
// plugin cannot add a layer surface. The row, its tiles, keys and framer
// trigger are SekaiPop's.
Popup {
    id: win

    property var theme
    property var service
    property var screen
    property var anchorItem

    visible: false

    readonly property int designW: 446
    readonly property int designH: 202

    readonly property real f: {
        if (!win.parent)
            return 1
        const o = win.parent.mapToItem(null, 0, 0)
        const u = win.parent.mapToItem(null, 1, 1)
        const k = Math.hypot(u.x - o.x, u.y - o.y)
        return (isFinite(k) && k > 0.01) ? k : 1
    }

    width: win.designW * win.f
    height: win.designH * win.f
    padding: 0
    margins: 0
    background: null
    modal: false
    dim: false
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    property var _anchor: null

    function openAt(item) {
        win._anchor = item
        win.place()
        win.open()
    }

    function place() {
        const item = win._anchor
        if (!item)
            return
        const f = win.f
        const scene = item.mapToItem(null, 0, 0)
        const roomW = win.screen ? win.screen.width : 1920
        const roomH = win.screen ? win.screen.height : 1080
        const cardW = win.designW * f
        const cardH = win.designH * f
        const px = scene.x + item.width * f / 2
        const py = scene.y + item.height * f + 8 * f
        const sx = Math.max(8, Math.min(px - cardW / 2, roomW - cardW - 8))
        const sy = (py + cardH > roomH - 8) ? (scene.y - cardH - 8 * f) : py
        const r = win.parent.mapToItem(null, 0, 0)
        win.x = (sx - r.x) / f
        win.y = (sy - r.y) / f
    }

    onAboutToShow: win.place()

    Connections {
        target: win.service
        function onBusyChanged() {
            if (win.service && win.service.busy)
                win.close()
        }
    }

    // The classic white board the row sits on.
    Item {
        id: card
        width: win.designW
        height: win.designH
        transformOrigin: Item.TopLeft
        scale: win.f

        Pill {
            anchors.fill: parent
            theme: win.theme
            cornerRadius: win.theme.radiusOuter
            ringWidth: win.theme.borderWidth + win.theme.outerRingWidth
            ringColorTop: win.theme.pSurfaceRing
            ringColorBottom: ringColorTop
            fillColor: win.theme.pSurface

            Loader {
                id: rowLoader
                x: 16
                y: 8
                active: win.service !== null
                sourceComponent: PicturesRow {
                    theme: win.theme
                    service: win.service
                }
            }
        }
    }
}
