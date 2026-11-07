import QtQuick
import QtQuick.Controls
import Quickshell

// SekaiPop's LyricsSources.qml: the lyrics source picker. SekaiPop opens it in
// its own full-screen overlay window; a Ryoku plugin cannot add a layer
// surface, so it is a Popup here. The card, rows, radio, badges and pop
// animation are SekaiPop's.
Popup {
    id: win

    property var service
    property var theme
    property var screen
    property real s: 1

    visible: false
    // The Ryoku host scales the whole widget from its top-left (the desktop
    // slot's holder transform). The popup is its own window and does not inherit
    // that transform, so the card is scaled by the measured factor and placed in
    // scene coordinates. At scale 1 this is exactly SekaiPop's layout.
    readonly property real f: {
        if (!win.parent)
            return 1
        const o = win.parent.mapToItem(null, 0, 0)
        const u = win.parent.mapToItem(null, 1, 1)
        const k = Math.hypot(u.x - o.x, u.y - o.y)
        return (isFinite(k) && k > 0.01) ? k : 1
    }

    width: card.implicitWidth * win.f
    height: card.implicitHeight * win.f
    padding: 0
    margins: 0
    background: null
    modal: false
    dim: false
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    function place(): void {
        if (!win.parent)
            return
        const f = win.f
        const scene = win.parent.mapToItem(null, 0, 0)
        const roomW = win.screen ? win.screen.width : 1920
        const roomH = win.screen ? win.screen.height : 1080
        const cardW = card.implicitWidth * f
        const cardH = card.implicitHeight * f
        const px = (win.service && win.service.pickerX >= 0) ? win.service.pickerX : win.parent.width / 2
        const py = (win.service && win.service.pickerY >= 0) ? win.service.pickerY + 6 : 120
        // Where the card should land, in the parent's scene; push it back in
        // when it would hang off the screen.
        const wantX = scene.x + px * f - cardW / 2
        const wantY = scene.y + py * f
        const sx = Math.max(8, Math.min(wantX, roomW - cardW - 8))
        const sy = Math.max(8, Math.min(wantY, roomH - cardH - 8))
        win.x = (sx - scene.x) / f
        win.y = (sy - scene.y) / f
    }

    Connections {
        target: win.service
        function onPickerOpenChanged() {
            if (!win.service)
                return
            if (win.service.pickerOpen)
                win.open()
            else
                win.close()
        }
    }

    Component.onCompleted: {
        if (win.service && win.service.pickerOpen)
            win.open()
    }

    onServiceChanged: {
        if (win.service && win.service.pickerOpen)
            win.open()
    }

    onAboutToShow: {
        win.place()
        card.pop()
    }

    onClosed: {
        if (win.service && win.service.pickerOpen)
            win.service.closePicker()
    }

    // One line of the list: a round radio, the name, and on the right what it found.
    component SourceRow: Item {
        id: row

        property var theme
        property string name: ""
        property string note: ""          // under the name, small
        property string kind: ""          // "word" | "synced" | "loading" | "none" | "offline" | ""
        property bool selected: false
        property bool inUse: false
        signal picked
        signal retry

        readonly property bool dim: row.kind === "none"

        height: 40

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 2
            anchors.rightMargin: 2
            radius: 9
            color: row.theme.surfaceHover
            opacity: area.containsMouse ? 1 : 0

            Behavior on opacity {
                NumberAnimation { duration: 110 }
            }
        }

        // the radio
        Rectangle {
            id: radio
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            color: "transparent"
            border.width: 2
            border.color: row.selected ? row.theme.accentCyan : Qt.rgba(row.theme.ink.r, row.theme.ink.g, row.theme.ink.b, row.dim ? 0.28 : 0.5)

            Rectangle {
                anchors.centerIn: parent
                width: 8
                height: 8
                radius: 4
                color: row.theme.accentCyan
                scale: row.selected ? 1 : 0
                opacity: row.selected ? 1 : 0

                Behavior on scale {
                    NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2 }
                }
                Behavior on opacity {
                    NumberAnimation { duration: 100 }
                }
            }
        }

        Column {
            anchors.left: radio.right
            anchors.leftMargin: 12
            anchors.right: status.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: row.name
                elide: Text.ElideRight
                color: row.theme.ink
                opacity: row.dim ? 0.45 : 1
                font.family: row.theme.fontFamily
                font.pixelSize: 15
                font.weight: row.inUse ? Font.ExtraBold : Font.DemiBold
                font.styleName: row.inUse ? row.theme.fontStyleBold : ""
            }

            Text {
                visible: row.note !== ""
                width: parent.width
                text: row.note
                elide: Text.ElideRight
                color: row.theme.inkSub
                font.family: row.theme.fontFamily
                font.pixelSize: 11
            }
        }

        // what it found
        Row {
            id: status
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                visible: row.kind === "offline"
                anchors.verticalCenter: parent.verticalCenter
                text: "Unreachable"
                color: row.theme.inkSub
                font.family: row.theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                visible: row.kind === "offline"
                anchors.verticalCenter: parent.verticalCenter
                text: "Try again"
                color: row.theme.accentCyan
                font.family: row.theme.fontFamily
                font.pixelSize: 12
                font.underline: retryArea.containsMouse

                MouseArea {
                    id: retryArea
                    anchors.fill: parent
                    anchors.margins: -5
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: row.retry()
                }
            }

            Text {
                visible: row.kind === "none"
                anchors.verticalCenter: parent.verticalCenter
                text: "Not found"
                color: row.theme.inkSub
                opacity: 0.7
                font.family: row.theme.fontFamily
                font.pixelSize: 12
            }

            Text {
                visible: row.kind === "loading"
                anchors.verticalCenter: parent.verticalCenter
                text: "asking..."
                color: row.theme.inkSub
                font.family: row.theme.fontFamily
                font.pixelSize: 12
            }

            Rectangle {
                visible: row.kind === "word" || row.kind === "synced"
                anchors.verticalCenter: parent.verticalCenter
                width: badge.implicitWidth + 16
                height: 22
                radius: 11
                color: row.kind === "word"
                    ? Qt.rgba(row.theme.accentCyan.r, row.theme.accentCyan.g, row.theme.accentCyan.b, 0.2)
                    : Qt.rgba(row.theme.ink.r, row.theme.ink.g, row.theme.ink.b, 0.12)

                Text {
                    id: badge
                    anchors.centerIn: parent
                    text: row.kind === "word" ? "WORD BY WORD" : "SYNCED"
                    color: row.kind === "word" ? row.theme.accentCyan : row.theme.ink
                    font.family: row.theme.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.8
                }
            }
        }

        MouseArea {
            id: area
            anchors.fill: parent
            z: -1
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton
            onClicked: row.picked()
        }
    }

    contentItem: Item {
        width: card.implicitWidth * win.f
        height: card.implicitHeight * win.f

        Pill {
            id: card

            theme: win.theme
            readonly property real innerWidth: 360
            cornerRadius: win.theme.radiusOuter
            ringWidth: win.theme.borderWidth
            innerRing: win.theme.cardRing
            fillColor: win.theme.surface
            implicitWidth: card.innerWidth + 10 + card.ringWidth * 2
            implicitHeight: col.implicitHeight + 10 + card.ringWidth * 2 + win.theme.shadowOffset
            width: implicitWidth
            height: implicitHeight

            property real popProgress: 1

            function pop() {
                popAnim.restart()
            }

            SequentialAnimation {
                id: popAnim
                ScriptAction { script: card.popProgress = 0 }
                PauseAnimation { duration: 40 }
                NumberAnimation {
                    target: card
                    property: "popProgress"
                    from: 0
                    to: 1
                    duration: 260
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.4
                }
            }

            opacity: Math.min(1, card.popProgress * 3)
            transform: [
                Scale {
                    origin.x: card.width / 2
                    origin.y: 0
                    xScale: 0.86 + 0.14 * card.popProgress
                    yScale: 0.86 + 0.14 * card.popProgress
                },
                Scale {
                    origin.x: 0
                    origin.y: 0
                    xScale: win.f
                    yScale: win.f
                }
            ]

            // Takes the clicks that land on the card, so they do not close it.
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            }

            Column {
                id: col
                x: 5
                y: 5
                width: card.innerWidth

                Text {
                    x: 12
                    height: 30
                    verticalAlignment: Text.AlignVCenter
                    text: "Lyrics source"
                    color: win.theme.inkSub
                    font.family: win.theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 0.6
                    font.capitalization: Font.AllUppercase
                }

                SourceRow {
                    width: col.width
                    theme: win.theme
                    name: "Auto"
                    note: win.service && win.service.source !== "" && win.service.status === "ready"
                        ? "using " + win.service.providerName(win.service.source)
                        : "the best one for each song"
                    selected: win.service ? win.service.preferred === "auto" : true
                    onPicked: {
                        if (win.service)
                            win.service.setPreferred("auto")
                    }
                }

                Repeater {
                    model: win.service ? win.service.providers : []

                    delegate: SourceRow {
                        id: line

                        required property var modelData

                        width: col.width
                        theme: win.theme
                        name: line.modelData.name
                        note: line.modelData.hint
                        selected: win.service ? win.service.preferred === line.modelData.id : false
                        inUse: win.service ? (win.service.source === line.modelData.id && win.service.status === "ready") : false
                        kind: {
                            if (!win.service)
                                return ""
                            const s = win.service.sourceStates[line.modelData.id]
                            if (s !== undefined)
                                return s
                            // from the cache: only the one that was used is known
                            return win.service.source === line.modelData.id ? win.service.sourceKind : ""
                        }
                        onPicked: {
                            if (win.service)
                                win.service.setPreferred(line.modelData.id)
                        }
                        onRetry: {
                            if (win.service)
                                win.service.refresh()
                        }
                    }
                }
            }
        }
    }
}
