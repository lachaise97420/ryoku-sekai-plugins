pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "full"
    property real s: 1
    property real widthBudget: 0
    property bool open: false
    property real reveal: 0
    property bool tabActive: false
    signal requestClose()

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property real uiScale: Math.max(0.85, Math.min(1.35, root.s))

    // ── Ryoku palette ──
    property var pal: ({})
    FileView {
        id: colorsFile
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/colors.json"
        watchChanges: true
        printErrors: false
        onLoaded: root._parseColors()
        onFileChanged: { colorsFile.reload(); }
    }
    function _parseColors(): void {
        try {
            var t = colorsFile.text();
            root.pal = (t && t.length) ? (JSON.parse(t) || {}) : ({});
        } catch (e) {
            root.pal = ({});
        }
    }
    Component.onCompleted: root._parseColors()

    // SekaiPop theme tokens
    QtObject {
        id: sekaiTheme
        property color accentMint: (root.pal && root.pal.tertiary) ? root.pal.tertiary : Theme.accent
        property color accentCyan: (root.pal && root.pal.primary) ? root.pal.primary : Theme.accent
        property color colBorder: (root.pal && root.pal.primaryContainer) ? root.pal.primaryContainer : Theme.border
        property color colOuterRing: "#d9d9d9"
        property color ringWhite: "#ffffff"
        property int whiteLine: 2
        property string fontFamily: "Noto Sans"
        property string fontStyleBold: "ExtraBold"
        property color chipFill: (root.pal && root.pal.surfaceContainer) ? root.pal.surfaceContainer : Theme.tileBg
        property color chipInk: (root.pal && root.pal.onSurface) ? root.pal.onSurface : Theme.bright
        property color pSurfaceDivider: (root.pal && root.pal.surfaceVariant) ? root.pal.surfaceVariant : Theme.tileBg
        property color pLine: (root.pal && root.pal.outline) ? root.pal.outline : Theme.border
        property color pLineShadow: (root.pal && root.pal.outline) ? root.pal.outline : Theme.border
    }

    // ── Clock state ──
    property var now: new Date()
    readonly property int hh: root.now.getHours()
    readonly property int mm: root.now.getMinutes()
    readonly property int ss: root.now.getSeconds()
    readonly property bool pm: root.hh >= 12
    readonly property bool use24h: root.service ? root.service.use24h : true

    readonly property string hhStr: {
        var h = root.use24h ? root.hh : (root.hh % 12 === 0 ? 12 : root.hh % 12);
        return (h < 10 ? "0" : "") + h;
    }
    readonly property string mmStr: (root.mm < 10 ? "0" : "") + root.mm

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.now = new Date()
    }

    // ── Persistence ──
    Process {
        id: persistProc
        command: []
    }
    function toggleFormat(): void {
        var next = !root.use24h;
        if (root.service) root.service.setUse24h(next);
        persistProc.command = ["/usr/bin/ryoku-plugins-place", "sekai-clock", "settings", JSON.stringify({ "use24h": next })];
        persistProc.running = true;
    }

    TapHandler {
        onTapped: root.toggleFormat()
    }

    implicitWidth: Math.round(114 * root.uiScale)
    implicitHeight: Math.round(228 * root.uiScale)

    // ── Components (hoisted) ──
    component GlyphRing: Item {
        id: gr
        property var sekaiTheme
        property string value: "0"
        property color ink: "#000000"
        property real radius: 5
        property real dx: 0
        property real dy: 0
        property int steps: 8
        Repeater {
            model: gr.steps
            Text {
                required property int index
                x: gr.dx + Math.cos(index * 2 * Math.PI / gr.steps) * gr.radius
                y: gr.dy + Math.sin(index * 2 * Math.PI / gr.steps) * gr.radius
                width: gr.width
                height: gr.height
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: gr.value
                color: gr.ink
                font.family: gr.sekaiTheme ? gr.sekaiTheme.fontFamily : "Noto Sans"
                font.pixelSize: Math.round(84 * (gr.width > 0 ? gr.width / 56.0 : 1))
                font.weight: Font.ExtraBold
                font.styleName: gr.sekaiTheme ? gr.sekaiTheme.fontStyleBold : "ExtraBold"
            }
        }
    }

    component StickerDigit: Item {
        id: sd
        property var sekaiTheme
        property string value: "0"
        property color fillColor: sekaiTheme ? sekaiTheme.accentMint : "#ffffff"
        property bool ghost: false
        property real tilt: 0
        property real pop: 1
        property real popScale: 1

        width: Math.round(56 * popScale)
        height: Math.round(96 * popScale)
        rotation: sd.tilt
        scale: sd.pop
        transformOrigin: Item.Center

        onValueChanged: popAnim.restart()

        NumberAnimation {
            id: popAnim
            target: sd
            property: "pop"
            from: 0.82
            to: 1
            duration: 340
            easing.type: Easing.OutBack
            easing.overshoot: 2.4
        }

        GlyphRing { anchors.fill: parent; sekaiTheme: sd.sekaiTheme; value: sd.value; ink: sd.sekaiTheme ? sd.sekaiTheme.colBorder : "#000000"; radius: 6 * sd.popScale; dx: 3 * sd.popScale; dy: 4 * sd.popScale }
        GlyphRing { anchors.fill: parent; sekaiTheme: sd.sekaiTheme; value: sd.value; ink: sd.sekaiTheme ? sd.sekaiTheme.colBorder : "#000000"; radius: 6 * sd.popScale }
        GlyphRing { anchors.fill: parent; sekaiTheme: sd.sekaiTheme; value: sd.value; ink: "#ffffff"; radius: 3.2 * sd.popScale }
        GlyphRing { anchors.fill: parent; sekaiTheme: sd.sekaiTheme; value: sd.value; ink: sd.ghost ? (sd.sekaiTheme ? sd.sekaiTheme.colOuterRing : "#d9d9d9") : sd.fillColor; radius: 0; steps: 1 }
    }

    component BeatDiamond: Rectangle {
        id: bd
        property var sekaiTheme
        property bool lit: false
        property color litColor: sekaiTheme ? sekaiTheme.accentMint : "#ffffff"
        property color offColor: sekaiTheme ? sekaiTheme.pSurfaceDivider : "#ffffff"
        property color lineColor: sekaiTheme ? sekaiTheme.pLine : "#000000"
        property int size: 12
        property real pop: 1

        width: size
        height: size
        radius: Math.round(3 * root.uiScale)
        rotation: 45
        scale: bd.pop
        color: bd.lit ? bd.litColor : bd.offColor
        border.width: 2
        border.color: bd.lineColor

        onLitChanged: {
            if (bd.lit)
                beatPop.restart()
        }

        NumberAnimation {
            id: beatPop
            target: bd
            property: "pop"
            from: 1.7
            to: 1
            duration: 360
            easing.type: Easing.OutBack
            easing.overshoot: 2.2
        }
    }

    component AmPmChip: Rectangle {
        id: chip
        property var sekaiTheme
        property string label: "AM"
        property real uiScale: 1
        width: Math.round(36 * uiScale)
        height: Math.round(28 * uiScale)
        radius: Math.round(9 * uiScale)
        rotation: 3
        color: sekaiTheme ? sekaiTheme.accentMint : "#ffffff"
        border.width: 2
        border.color: sekaiTheme ? sekaiTheme.colBorder : "#000000"
        Rectangle {
            z: -1
            x: 2 * chip.uiScale
            y: 3 * chip.uiScale
            width: chip.width
            height: chip.height
            radius: chip.radius
            color: sekaiTheme ? sekaiTheme.pLineShadow : "#000000"
            opacity: 0.6
        }
        Text {
            anchors.centerIn: parent
            text: chip.label
            color: sekaiTheme ? sekaiTheme.colBorder : "#000000"
            font.family: sekaiTheme ? sekaiTheme.fontFamily : "Noto Sans"
            font.pixelSize: Math.round(11 * chip.uiScale)
            font.weight: Font.ExtraBold
            font.styleName: sekaiTheme ? sekaiTheme.fontStyleBold : "ExtraBold"
        }
    }

    // ── STACK layout ──
    Column {
        anchors.centerIn: parent
        spacing: Math.round(4 * root.uiScale)

        Row {
            spacing: Math.round(2 * root.uiScale)
            StickerDigit {
                sekaiTheme: sekaiTheme
                value: root.hhStr.charAt(0)
                fillColor: sekaiTheme.accentMint
                ghost: !root.use24h && root.hhStr.charAt(0) === "0"
                tilt: -6
                popScale: root.uiScale
            }
            StickerDigit {
                sekaiTheme: sekaiTheme
                value: root.hhStr.charAt(1)
                fillColor: sekaiTheme.accentMint
                tilt: -2.4
                popScale: root.uiScale
            }
        }

        Row {
            spacing: Math.round(28 * root.uiScale)
            anchors.horizontalCenter: parent.horizontalCenter
            BeatDiamond {
                sekaiTheme: sekaiTheme
                lit: root.ss % 2 === 0
                litColor: sekaiTheme.accentMint
                size: Math.round(12 * root.uiScale)
            }
            BeatDiamond {
                sekaiTheme: sekaiTheme
                lit: root.ss % 2 !== 0
                litColor: sekaiTheme.accentCyan
                size: Math.round(12 * root.uiScale)
            }
        }

        Row {
            spacing: Math.round(2 * root.uiScale)
            StickerDigit {
                sekaiTheme: sekaiTheme
                value: root.mmStr.charAt(0)
                fillColor: sekaiTheme.accentCyan
                tilt: 2.4
                popScale: root.uiScale
            }
            StickerDigit {
                sekaiTheme: sekaiTheme
                value: root.mmStr.charAt(1)
                fillColor: sekaiTheme.accentCyan
                tilt: 6
                popScale: root.uiScale
            }
        }

        AmPmChip {
            visible: !root.use24h
            sekaiTheme: sekaiTheme
            label: root.pm ? "PM" : "AM"
            uiScale: root.uiScale
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}