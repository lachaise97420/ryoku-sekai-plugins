import QtQuick

// SekaiPop's PicturesRow.qml, the banner and avatar tiles from Edit Desktop's
// THEME board (the phone wallpaper is left out: Ryoku has no Quick Panel phone).
// Each shows what it is now (its picture, framed, or "none yet", or "can't find
// its file") and has keys to change it, frame it (FramerCard) and remove it
// (two clicks: "Remove?"). Design: docs/PICTURE-FRAMING.md.
Item {
    id: root

    // SekaiPop's theme and picture service, handed in by the widget.
    property var theme
    property var service
    readonly property var mt: theme

    // The board this row sits on is the classic white panel.
    readonly property bool classicPanel: true

    implicitWidth: 414
    implicitHeight: 170

    // A remove waiting for its second click ("" = none), forgotten after 3 s.
    property string asking: ""
    Timer {
        id: askTimer
        interval: 3000
        onTriggered: root.asking = ""
    }
    function ask(kind) {
        root.asking = kind
        askTimer.restart()
    }
    // The chooser is a normal window: the picture row's popup steps aside first,
    // so it opens where you can use it. The framer follows the pick.
    function pick(kind) {
        root.service.pick(kind)
    }

    function remove(kind) {
        root.asking = ""
        root.service.clear(kind)
    }

    // ===== a small key: icon, or icon + word; "ask" is the Remove? one =====
    component SmallKey: Item {
        id: sk
        property string icon: ""
        property string text: ""
        property bool ask: false
        property string tip: ""
        signal clicked()

        implicitWidth: (sk.text === "" ? 28 : skRow.implicitWidth + 18) + 2
        implicitHeight: 28 + 2
        opacity: sk.enabled ? 1 : 0.35

        Rectangle {
            x: sk.ask ? 3 : 2
            y: sk.ask ? 3 : 2
            width: sk.width - 2
            height: 28
            radius: 14
            color: root.mt.pLineShadow
        }
        Rectangle {
            width: sk.width - 2
            height: 28
            x: skArea.pressed ? 2 : 0
            y: skArea.pressed ? 2 : 0
            radius: 14
            color: sk.ask ? root.mt.pSurfaceHover : root.mt.pSurface
            border.width: sk.ask ? 3 : 2.5
            border.color: sk.ask ? root.mt.colBorder : root.mt.pLine
            Rectangle {
                visible: !sk.ask
                anchors.fill: parent
                anchors.margins: 2.5
                radius: height / 2
                color: "transparent"
                border.width: 2
                border.color: root.mt.pRingWhite
            }
            Row {
                id: skRow
                anchors.centerIn: parent
                spacing: 5
                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    theme: root.theme
                    name: sk.icon
                    size: 15
                    color: sk.ask ? root.mt.colBorder : root.mt.pInk
                }
                Text {
                    visible: sk.text !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: sk.text
                    color: sk.ask ? root.mt.colBorder : root.mt.pInk
                    font.family: root.mt.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.styleName: root.mt.fontStyleBold
                }
            }
        }
        MouseArea {
            id: skArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: sk.clicked()
        }
    }

    // ===== a tile's housing; lit while its picture is in the framer =====
    component Tile: Item {
        id: tile
        property string kind: ""
        property string label: ""
        default property alias content: tileInner.data
        readonly property bool focused: root.service.framing === tile.kind
        opacity: root.service.framing !== "" && !tile.focused ? 0.45 : 1
        height: 138

        Rectangle {
            x: tile.focused ? 6 : 4
            y: tile.focused ? 4 : 3
            width: tile.width - (tile.focused ? 6 : 4)
            height: tile.height - (tile.focused ? 4 : 3)
            radius: 18
            color: root.mt.pLineShadow
        }
        Rectangle {
            width: tile.width - (tile.focused ? 6 : 4)
            height: tile.height - (tile.focused ? 4 : 3)
            radius: 18
            color: tile.focused ? "transparent" : root.mt.pSurface
            border.width: tile.focused ? 4 : 3
            border.color: tile.focused ? root.mt.colBorder : root.mt.pLine
            gradient: tile.focused ? tileLit : null
            Gradient {
                id: tileLit
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: root.mt.accentMint }
                GradientStop { position: 1; color: root.mt.accentCyan }
            }
            Rectangle {
                anchors.fill: parent
                anchors.margins: tile.focused ? 4 : 3
                radius: 15
                color: "transparent"
                border.width: tile.focused ? 4 : 3
                border.color: root.mt.pRingWhite
            }
            Item {
                id: tileInner
                anchors.fill: parent
                anchors.margins: 9
            }
        }
        Rectangle {
            visible: tile.focused
            x: 14
            y: -13
            width: framingTag.implicitWidth + 18
            height: 22
            radius: 11
            color: root.mt.colBorder
            Text {
                id: framingTag
                anchors.centerIn: parent
                text: "Framing"
                color: "#ffffff"
                font.family: root.mt.fontFamily
                font.pixelSize: 11
                font.weight: Font.ExtraBold
                font.styleName: root.mt.fontStyleBold
            }
        }
    }

    // ===== what a picture slot shows when there is no picture =====
    component Empty: Row {
        property string text: ""
        property string icon: "image"
        anchors.centerIn: parent
        spacing: 7
        MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            theme: root.theme
            name: parent.icon
            size: 16
            color: root.mt.pInkSub
        }
        Text {
            visible: parent.text !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: parent.text
            color: root.mt.pInkSub
            font.family: root.mt.fontFamily
            font.pixelSize: 13
            font.weight: Font.ExtraBold
            font.styleName: root.mt.fontStyleBold
        }
    }

    // ===== the footer of a tile: its name and keys =====
    component Footer: Item {
        id: foot
        property string kind: ""
        property string label: ""
        // "set" | "empty" | "missing"
        property string pic: "set"
        property bool canFrame: foot.pic === "set"
        property bool canRemove: foot.pic !== "empty"
        property bool focused: false
        width: parent ? parent.width : 0
        height: 30

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, keyRow.x - 6)
            elide: Text.ElideRight
            text: foot.label
            color: foot.focused ? root.mt.colBorder : root.mt.pInk
            font.family: root.mt.fontFamily
            font.pixelSize: 14
            font.weight: Font.ExtraBold
            font.styleName: root.mt.fontStyleBold
        }
        Row {
            id: keyRow
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
            // Remove? (the second click removes)
            SmallKey {
                visible: root.asking === foot.kind
                icon: "delete"
                text: "Remove?"
                ask: true
                onClicked: root.remove(foot.kind)
            }
            SmallKey {
                visible: root.asking !== foot.kind
                icon: "image"
                text: foot.pic === "set" || foot.kind === "phone" ? "" : "Pick"
                onClicked: root.pick(foot.kind)
            }
            SmallKey {
                visible: root.asking !== foot.kind && (foot.pic === "set" || foot.kind === "phone")
                enabled: foot.canFrame
                icon: "crop"
                onClicked: root.service.frame(foot.kind, false)
            }
            SmallKey {
                visible: root.asking !== foot.kind && (foot.pic !== "empty" || foot.kind === "phone")
                enabled: foot.canRemove
                icon: "delete"
                onClicked: root.ask(foot.kind)
            }
        }
    }

    Row {
        x: 4
        y: 16
        spacing: 14

        // ===== Banner =====
        Tile {
            id: bannerTile
            kind: "banner"
            width: 216
            readonly property string pic: root.service.banner === "" ? "empty" : (bannerImg.status === Image.Error ? "missing" : "set")

            Column {
                spacing: 8
                Rectangle {
                    width: 192
                    height: 77
                    color: root.mt.pSurfaceDivider
                    topLeftRadius: 24
                    topRightRadius: 24
                    bottomLeftRadius: 16
                    bottomRightRadius: 16
                    border.width: bannerTile.pic === "missing" ? 2 : (bannerTile.focused ? 3 : 0)
                    border.color: bannerTile.focused ? root.mt.colBorder : root.mt.pLine
                    RoundClip {
                        anchors.fill: parent
                        radii: [24, 24, 16, 16]
                        visible: bannerTile.pic === "set"
                        FramedImage {
                            id: bannerImg
                            anchors.fill: parent
                            source: root.service.banner
                            framing: root.service.framingFor("banner")
                        }
                    }
                    Empty {
                        visible: bannerTile.pic !== "set"
                        icon: bannerTile.pic === "missing" ? "hide_image" : "image"
                        text: bannerTile.pic === "missing" ? "Can't find its file" : "No banner yet"
                    }
                }
                Footer {
                    kind: "banner"
                    label: "Banner"
                    pic: bannerTile.pic
                    focused: bannerTile.focused
                }
            }
        }

        // ===== Avatar =====
        Tile {
            id: avatarTile
            kind: "avatar"
            // A little wider than the canvas's 170, so "Avatar" fits beside its three keys.
            width: 180
            readonly property string pic: root.service.avatar === "" ? "empty" : (avatarImg.status === Image.Error ? "missing" : "set")

            Column {
                width: 162
                spacing: 8
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 77
                    height: 77
                    radius: 38.5
                    color: root.mt.pSurfaceDivider
                    border.width: avatarTile.pic === "missing" ? 2 : (avatarTile.focused ? 3 : 0)
                    border.color: avatarTile.focused ? root.mt.colBorder : root.mt.pLine
                    RoundClip {
                        anchors.fill: parent
                        radii: [38.5, 38.5, 38.5, 38.5]
                        visible: avatarTile.pic === "set"
                        FramedImage {
                            id: avatarImg
                            anchors.fill: parent
                            source: root.service.avatar
                            framing: root.service.framingFor("avatar")
                        }
                    }
                    Empty {
                        visible: avatarTile.pic !== "set"
                        icon: avatarTile.pic === "missing" ? "hide_image" : "account_circle"
                        text: ""
                    }
                }
                Footer {
                    kind: "avatar"
                    label: avatarTile.pic === "empty" ? "No avatar" : "Avatar"
                    pic: avatarTile.pic
                    focused: avatarTile.focused
                }
            }
        }

    }
}
