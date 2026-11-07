import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io

// SekaiPop's desktop user card (UserCardWidget.qml), ported to Ryoku.
//
// The card itself, without SekaiPop's window / edit-mode / clone plumbing:
// the host owns placement, dragging and scaling. Everything inside is the
// classic white/navy card: banner, greeting chip, avatar sticker, name, host,
// three stat keys, today lane, burst on click, hover tilt, minute clock.
Item {
    id: win

    property var theme
    property var service
    property var screen

    readonly property var mt: theme

    implicitWidth: 320
    implicitHeight: 276

    signal customizeRequested()

    // ===== who you are =====
    readonly property string userName: Quickshell.env("USER") || "user"
    property string hostName: ""

    readonly property string shellName: {
        const n = (Quickshell.env("SHELL") || "").split("/").pop()
        return n !== "" ? n : "sh"
    }

    readonly property string deskName: Quickshell.env("XDG_CURRENT_DESKTOP") || "Wayland"

    Process {
        running: true
        command: ["uname", "-n"]
        stdout: StdioCollector {
            onStreamFinished: win.hostName = text.trim()
        }
    }

    property real uptimeSecs: -1

    Process {
        id: uptimeProc
        running: true
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = parseFloat(text.split(" ")[0])
                if (isFinite(s))
                    win.uptimeSecs = s
            }
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: {
            if (!uptimeProc.running)
                uptimeProc.running = true
        }
    }

    readonly property string uptimeText: {
        if (win.uptimeSecs < 0)
            return "--"
        const m = Math.floor(win.uptimeSecs / 60)
        const h = Math.floor(m / 60)
        const d = Math.floor(h / 24)
        if (d > 0)
            return d + "d " + (h % 24) + "h"
        if (h > 0)
            return h + "h " + (m % 60) + "m"
        return m + "m"
    }

    SystemClock {
        id: clock
        enabled: true
        precision: SystemClock.Minutes
    }

    readonly property date now: clock.date
    readonly property int hours24: win.now.getHours()
    readonly property int mins: win.now.getMinutes()
    readonly property real dayFrac: (win.hours24 * 60 + win.mins) / 1440

    readonly property string greeting: win.hours24 >= 5 && win.hours24 < 12 ? "GOOD MORNING"
        : win.hours24 >= 12 && win.hours24 < 17 ? "GOOD AFTERNOON"
        : win.hours24 >= 17 && win.hours24 < 21 ? "GOOD EVENING"
        : "NIGHT OWL"

    // ===== reveal =====
    property real reveal: 0
    property bool placed: true
    property real swapK: 1
    readonly property real uiScale: 1

    NumberAnimation {
        id: popIn
        target: win
        property: "reveal"
        to: 1
        duration: 460
        easing.type: Easing.OutBack
        easing.overshoot: 1.9
    }

    Component.onCompleted: {
        win.reveal = 0
        Qt.callLater(() => popIn.start())
    }

    // ===== components =====
    component MaskedPhoto: Item {
        id: mp

        property url source: ""
        property var framing: null
        property real radius: 10
        property real bleed: 2
        property real frameWidth: mt.borderWidth
        property real frameRadius: mp.radius + mp.frameWidth
        property color frameColor: mt.pLine

        readonly property bool ready: img.status === Image.Ready
        readonly property real texel: win.uiScale * (win.screen ? win.screen.devicePixelRatio : 1)
        readonly property real oversample: 2

        Item {
            id: photoLayer
            x: -mp.bleed
            y: -mp.bleed
            width: mp.width + mp.bleed * 2
            height: mp.height + mp.bleed * 2
            visible: mp.ready

            layer.enabled: true
            layer.smooth: true
            layer.textureSize: Qt.size(Math.max(1, Math.ceil(width * mp.texel * mp.oversample)),
                                       Math.max(1, Math.ceil(height * mp.texel * mp.oversample)))
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: photoMask
            }

            FramedImage {
                id: img
                anchors.fill: parent
                source: mp.source
                framing: mp.framing
                clipped: false
                decodeScale: mp.texel * mp.oversample
            }
        }

        Item {
            id: photoMask
            x: photoLayer.x
            y: photoLayer.y
            width: photoLayer.width
            height: photoLayer.height
            visible: false

            layer.enabled: true
            layer.smooth: true
            layer.textureSize: photoLayer.layer.textureSize

            Rectangle {
                anchors.fill: parent
                radius: mp.radius + mp.bleed
                color: "black"
                antialiasing: true
            }
        }

        Rectangle {
            visible: mp.ready
            z: 2
            x: -mp.frameWidth
            y: -mp.frameWidth
            width: mp.width + mp.frameWidth * 2
            height: mp.height + mp.frameWidth * 2
            radius: mp.frameRadius
            color: "transparent"
            border.width: mp.frameWidth
            border.color: mp.frameColor
            antialiasing: true
        }
    }

    component StatKey: Item {
        id: sk

        property string label: ""
        property string value: ""
        property bool gradientFill: false
        property real tilt: 0

        width: 90
        height: 58
        rotation: sk.tilt
        transformOrigin: Item.Center

        onValueChanged: {
            keyPill.pressed = true
            keyRelease.restart()
        }

        Timer {
            id: keyRelease
            interval: 90
            onTriggered: keyPill.pressed = false
        }

        Gradient {
            id: keyFill
            GradientStop { position: 0.0; color: mt.accentMint }
            GradientStop { position: 1.0; color: mt.accentCyan }
        }

        Pill {
            id: keyPill
            theme: win.theme
            anchors.fill: parent
            cornerRadius: 15
            ringWidth: mt.borderWidth + mt.whiteLine
            shadowDx: 3
            shadowDy: 4
            fillColor: mt.chipFill
            fillGradient: sk.gradientFill ? keyFill : null

            Column {
                anchors.centerIn: parent
                width: parent.width - 6
                spacing: 1

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: sk.label
                    color: sk.gradientFill ? mt.colBorder : mt.chipInk
                    opacity: 0.7
                    font.family: mt.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                    font.letterSpacing: 1.5
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: sk.value
                    color: sk.gradientFill ? mt.colBorder : mt.chipInk
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 10
                    font.family: mt.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                }
            }
        }
    }

    component SparkDiamond: Rectangle {
        id: sp

        property int order: 0
        property real size: 12
        property bool solid: false
        property real pop: 1

        width: sp.size
        height: sp.size
        radius: sp.size / 4
        rotation: 45
        scale: sp.pop
        color: sp.solid ? mt.colBorder : "#ffffff"
        border.width: 2
        border.color: mt.colBorder
        antialiasing: true

        SequentialAnimation {
            id: sparkTick

            PauseAnimation { duration: sp.order * 50 }

            NumberAnimation {
                target: sp
                property: "pop"
                from: 1.7
                to: 1
                duration: 380
                easing.type: Easing.OutBack
                easing.overshoot: 2.2
            }
        }

        Connections {
            target: win
            function onMinsChanged() {
                sparkTick.restart()
            }
        }
    }

    // ===== the card =====
    Item {
        id: card

        readonly property bool classicPanel: true

        readonly property int contentW: 286
        readonly property int contentH: 238
        readonly property int inset: mt.borderWidth + mt.outerRingWidth + 10

        width: card.contentW + card.inset * 2
        height: card.contentH + card.inset * 2 + mt.shadowOffset

        readonly property real tilt: 2.5
        readonly property int stagger: 6

        readonly property color glow: mt.dark ? mt.accentMint : mt.colBorder

        scale: Math.max(0, win.reveal) * (win.placed ? 1 : 0) * (0.7 + 0.3 * Math.max(0, win.swapK))
        opacity: Math.max(0, Math.min(1, win.swapK))
        transformOrigin: Item.Center

        function isOverAvatar(px, py) {
            const p = avatarSlot.mapFromItem(hoverArea, px, py)
            return p.x >= 0 && p.y >= 0 && p.x <= avatarSlot.width && p.y <= avatarSlot.height
        }

        readonly property bool avatarHover: hoverArea.containsMouse && card.isOverAvatar(hoverArea.mouseX, hoverArea.mouseY)
        property bool avatarDown: false

        function popBurst() {
            hitAnim.restart()
            burstAnim.restart()
        }

        Pill {
            id: housing
            theme: win.theme
            anchors.fill: parent
            cornerRadius: mt.radiusOuter
            ringWidth: mt.borderWidth + mt.outerRingWidth
            ringColorTop: mt.pSurfaceRing
            ringColorBottom: ringColorTop
            fillColor: mt.pSurface
        }

        Item {
            id: content
            z: 2
            x: card.inset
            y: card.inset
            width: card.contentW
            height: card.contentH

            // ===== the banner =====
            Pill {
                id: banner
                theme: win.theme
                z: 1
                width: card.contentW
                height: 88
                cornerRadius: 16
                ringWidth: mt.borderWidth
                fillGradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: mt.accentMint }
                    GradientStop { position: 1.0; color: mt.accentCyan }
                }

                MaskedPhoto {
                    id: bannerPhoto
                    anchors.fill: parent
                    source: win.service ? win.service.banner : ""
                    framing: win.service ? win.service.framingFor("banner") : null
                    radius: Math.max(0, banner.cornerRadius - banner.ringWidth)
                    frameWidth: banner.borderWidth
                    frameRadius: banner.cornerRadius
                    frameColor: banner.classicScope ? mt.pLine : mt.line
                }

                Item {
                    anchors.fill: parent
                    visible: !(bannerPhoto.ready)

                    SparkDiamond { order: 0; size: 14; x: 118; y: 44 }
                    SparkDiamond { order: 1; size: 9;  x: 146; y: 56; solid: true }
                    SparkDiamond { order: 2; size: 12; x: 172; y: 44 }
                    SparkDiamond { order: 3; size: 8;  x: 198; y: 54; solid: true }
                    SparkDiamond { order: 4; size: 15; x: 226; y: 46 }
                    SparkDiamond { order: 5; size: 9;  x: 252; y: 54; solid: true }
                    SparkDiamond { order: 6; size: 10; x: 28;  y: 14 }
                    SparkDiamond { order: 7; size: 8;  x: 66;  y: 22; solid: true }
                    SparkDiamond { order: 8; size: 11; x: 100; y: 12 }
                }
            }

            // The greeting: a tilted navy chip on the banner's top-right.
            Pill {
                id: greetChip
                theme: win.theme
                z: 3
                width: greetText.implicitWidth + 26
                height: 30
                x: card.contentW - greetChip.width - 14
                y: 10
                cornerRadius: 10
                ringWidth: mt.borderWidth + mt.whiteLine
                fillColor: mt.chipFill
                rotation: 3
                transformOrigin: Item.Center

                Text {
                    id: greetText
                    anchors.centerIn: parent
                    text: win.greeting
                    color: mt.chipInk
                    font.family: mt.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                    font.letterSpacing: 1.2
                }
            }

            // ===== the avatar sticker =====
            Item {
                id: avatarSlot
                z: 4
                x: 10
                y: 46
                width: 87
                height: 88
                transformOrigin: Item.Center

                property real lift: card.avatarHover ? 1.05 : 1
                property real hit: 1

                rotation: card.avatarHover ? 3 : -4
                scale: avatarSlot.lift * avatarSlot.hit

                Behavior on rotation {
                    NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
                }

                Behavior on lift {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 }
                }

                SequentialAnimation {
                    id: hitAnim
                    NumberAnimation { target: avatarSlot; property: "hit"; to: 0.88; duration: 70; easing.type: Easing.OutQuad }
                    NumberAnimation { target: avatarSlot; property: "hit"; to: 1; duration: 380; easing.type: Easing.OutBack; easing.overshoot: 3.2 }
                }

                Pill {
                    id: avatarPill
                    theme: win.theme
                    anchors.fill: parent
                    cornerRadius: 26
                    ringWidth: mt.borderWidth
                    shadowDx: 3
                    shadowDy: 4
                    fillColor: mt.chipFill
                    pressed: card.avatarDown

                    Text {
                        anchors.centerIn: parent
                        visible: !avatarPhoto.ready
                        text: win.userName.charAt(0).toUpperCase()
                        color: card.glow
                        font.family: mt.fontFamily
                        font.pixelSize: 46
                        font.weight: Font.ExtraBold
                        font.styleName: mt.fontStyleBold
                    }

                    MaskedPhoto {
                        id: avatarPhoto
                        anchors.fill: parent
                        source: win.service ? win.service.avatar : ""
                        framing: win.service ? win.service.framingFor("avatar") : null
                        radius: Math.max(0, avatarPill.cornerRadius - avatarPill.ringWidth)
                        frameWidth: avatarPill.borderWidth
                        frameRadius: avatarPill.cornerRadius
                        frameColor: avatarPill.classicScope ? mt.pLine : mt.line
                    }
                }
            }

            // The burst
            Item {
                id: burst
                z: 6
                x: 53
                y: 90
                visible: burst.t < 1

                property real t: 1

                NumberAnimation {
                    id: burstAnim
                    target: burst
                    property: "t"
                    from: 0
                    to: 1
                    duration: 560
                    easing.type: Easing.OutCubic
                }

                Repeater {
                    model: 8

                    Rectangle {
                        required property int index

                        readonly property real ang: (index * 45 + 22.5) * Math.PI / 180
                        readonly property real dist: 36 + burst.t * (index % 2 === 0 ? 62 : 44)

                        width: index % 2 === 0 ? 12 : 9
                        height: width
                        radius: 3
                        rotation: 45
                        x: Math.cos(ang) * dist - width / 2
                        y: Math.sin(ang) * dist - height / 2
                        scale: 1.15 - burst.t * 0.85
                        opacity: 1 - burst.t * burst.t
                        color: index % 3 === 0 ? mt.accentMint : (index % 3 === 1 ? mt.accentCyan : "#ffffff")
                        border.width: 2
                        border.color: mt.colBorder
                        antialiasing: true
                    }
                }
            }

            // ===== the name =====
            Text {
                x: 112
                y: 91
                z: 2
                width: card.contentW - 112
                elide: Text.ElideRight
                text: win.userName
                color: mt.pInk
                font.family: mt.fontFamily
                font.pixelSize: 22
                font.weight: Font.ExtraBold
                font.styleName: mt.fontStyleBold
            }

            Text {
                x: 112
                y: 119
                z: 2
                width: card.contentW - 112
                elide: Text.ElideRight
                text: win.hostName !== "" ? "@" + win.hostName : ""
                color: mt.pInkSub
                font.family: mt.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            // ===== three keys in a shallow V =====
            Item {
                id: keyRow
                y: 140
                width: card.contentW
                height: 64

                StatKey {
                    x: 0
                    y: 0
                    label: "UPTIME"
                    value: win.uptimeText
                    tilt: -card.tilt
                }

                StatKey {
                    x: 98
                    y: card.stagger
                    gradientFill: true
                    label: "SHELL"
                    value: win.shellName
                }

                StatKey {
                    x: 196
                    y: 0
                    label: "DESKTOP"
                    value: win.deskName
                    tilt: card.tilt
                }
            }

            // ===== the lane =====
            Item {
                id: lane
                y: 208
                width: card.contentW
                height: 30

                Pill {
                    id: pct
                    theme: win.theme
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 56
                    height: 30
                    cornerRadius: 10
                    ringWidth: 3
                    fillColor: mt.chipFill
                    rotation: 3
                    transformOrigin: Item.Center

                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: Math.round(win.dayFrac * 100) + "%"
                        color: card.glow
                        font.family: mt.fontFamily
                        font.pixelSize: 15
                        font.weight: Font.ExtraBold
                        font.styleName: mt.fontStyleBold
                    }
                }

                Text {
                    id: laneCap
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    text: "TODAY"
                    color: mt.pInkSub
                    font.family: mt.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.ExtraBold
                    font.styleName: mt.fontStyleBold
                    font.letterSpacing: 1.5
                }

                Item {
                    id: track
                    anchors.left: laneCap.right
                    anchors.leftMargin: 10
                    anchors.right: pct.left
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -2
                    height: 20

                    readonly property real headSize: 12
                    readonly property real pos: track.width * win.dayFrac
                    readonly property real headX: Math.min(track.width - track.headSize, Math.max(0, track.pos - track.headSize / 2))

                    readonly property bool sweeps: win.hours24 !== 0 || win.mins !== 0

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 12
                        radius: 6
                        color: mt.pSurfaceDivider
                        border.width: 2
                        border.color: mt.pLine
                    }

                    Rectangle {
                        x: 2
                        anchors.verticalCenter: parent.verticalCenter
                        height: 8
                        radius: 4
                        width: Math.max(0, track.headX + track.headSize / 2 - 2)

                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: mt.accentMint }
                            GradientStop { position: 1.0; color: mt.accentCyan }
                        }

                        Behavior on width {
                            enabled: track.sweeps
                            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2 }
                        }
                    }

                    Repeater {
                        model: 3

                        Rectangle {
                            required property int index
                            x: track.width * (index + 1) / 4 - 1.5
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 12
                            radius: 1.5
                            color: mt.pLine
                            opacity: 0.45
                        }
                    }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: track.headSize
                        height: track.headSize
                        radius: 3
                        rotation: 45
                        color: mt.accentMint
                        border.width: 2
                        border.color: mt.pLine
                        x: track.headX

                        Behavior on x {
                            enabled: track.sweeps
                            NumberAnimation { duration: 260; easing.type: Easing.OutBack; easing.overshoot: 2.5 }
                        }
                    }
                }
            }
        }

        // ===== full-card mouse area (hover + avatar click) =====
        MouseArea {
            id: hoverArea
            z: 10
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            cursorShape: card.avatarHover ? Qt.PointingHandCursor : Qt.ArrowCursor

            onPressed: (mouse) => { card.avatarDown = card.isOverAvatar(mouse.x, mouse.y) }
            onReleased: card.avatarDown = false
            onCanceled: card.avatarDown = false

            onClicked: mouse => {
                if (card.isOverAvatar(mouse.x, mouse.y))
                    card.popBurst()
            }
        }

        // ===== customization key (hover only) =====
        Pill {
            id: customKey
            theme: win.theme
            z: 12
            x: 10
            y: 10
            width: 34
            height: 30
            cornerRadius: 10
            ringWidth: mt.borderWidth + mt.whiteLine
            shadowDx: 3
            shadowDy: 3
            fillColor: mt.pSurface
            opacity: hoverArea.containsMouse ? 1 : 0
            scale: hoverArea.containsMouse ? 1 : 0.6
            rotation: -3
            transformOrigin: Item.Center

            Behavior on opacity {
                NumberAnimation { duration: 160 }
            }
            Behavior on scale {
                NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 }
            }

            MaterialIcon {
                anchors.centerIn: parent
                theme: win.theme
                name: "palette"
                size: 16
                color: mt.pInk
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: win.customizeRequested()
            }
        }
    }
}
