pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// SekaiPop's desktop audio visualizer, ported to Ryoku (phase 2: Sekai card +
// bars/tide/aurora/dots/mirror/ring/ribbons/scope/pulse styles + real audio tap).
// Ryoku owns placement, dragging and scaling.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "full"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null

    SekaiTheme { id: sekaiTheme }

    // ===== the player =====
    MediaSource { id: media }

    // ===== the audio (Sekai style: analyzer + cava fallback) =====
    readonly property bool anyPlaying: {
        const list = Mpris.players.values
        for (let i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing)
                return true
        }
        return false
    }

    readonly property string cavaConf: root.pluginApi ? root.pluginApi.pluginDir + "/content/cava-sekai.conf" : ""
    readonly property string analyzerScript: root.pluginApi ? root.pluginApi.pluginDir + "/content/sekai_analyzer.py" : ""

    property bool analyzerFailed: false
    readonly property bool useAnalyzer: (root.service ? root.service.isSekai : true) && (root.service ? root.service.analyzer : true) && !analyzerFailed
    // For phase 2 we only drive the Sekai card; non-Sekai styles use the pcEngine (cava-pc).
    readonly property bool isSekai: root.service ? root.service.isSekai : true
    readonly property bool isRing: root.service ? root.service.isRing : false
    readonly property bool isBand: root.service ? root.service.isBand : false

    readonly property bool wantAudio: (root.service ? root.service.shown : true)
        && (root.service ? root.service.alwaysListen : false || anyPlaying)

    Connections {
        target: root.service
        function onAnalyzerChanged() { root.analyzerFailed = false }
        function onUseAubioChanged() {
            root.analyzerFailed = false
            analyzerProc.running = false
            engineRestart.restart()
        }
    }

    Timer {
        id: engineRestart
        interval: 300
        onTriggered: { analyzerProc.running = Qt.binding(() => root.wantAudio && root.useAnalyzer) }
    }

    function parseBands(line) {
        const parts = line.split(";")
        const out = []
        for (let i = 0; i < parts.length; i++) {
            const v = parseFloat(parts[i])
            if (!isNaN(v)) out.push(v)
        }
        return out
    }

    Process {
        id: analyzerProc
        running: root.pluginApi !== null && root.wantAudio && root.useAnalyzer
        command: root.pluginApi ? ["nice", "-n", "5", "python3", root.pluginApi.pluginDir + "/content/sekai_analyzer.py", "--engine", (root.service && root.service.useAubio) ? "auto" : "numpy"] : []

        property double startedAt: 0

        stdout: SplitParser {
            onRead: data => {
                let f = null
                try { f = JSON.parse(data) } catch (e) { return }
                levelEngine.feed(f)
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("Visualizer: " + data)
        }
        onRunningChanged: {
            if (analyzerProc.running) analyzerProc.startedAt = Date.now()
            else levelEngine.raw = []
        }
        onExited: (code, status) => {
            if ((code === 1 || code === 3 || code === 4 || code === 127)
                    && Date.now() - analyzerProc.startedAt < 8000) {
                console.warn("Visualizer: analyzer did not start (exit " + code + "), using cava")
                root.analyzerFailed = true
            }
        }
    }

    Process {
        id: cava
        running: root.pluginApi !== null && root.wantAudio && root.isSekai && !root.useAnalyzer
        command: root.pluginApi ? ["setpriv", "--pdeathsig", "TERM", "nice", "-n", "5", "cava", "-p", root.pluginApi.pluginDir + "/content/cava-sekai.conf"] : []

        stdout: SplitParser {
            onRead: data => levelEngine.raw = root.parseBands(data)
        }
        onRunningChanged: {
            if (!cava.running) levelEngine.raw = []
        }
    }

    // ===== levels engine (Sekai) =====
    VisualizerEngine {
        id: levelEngine
        active: true
        demo: !root.wantAudio
        analyzer: root.useAnalyzer
        sensitivity: root.service ? root.service.sensitivity : 1.0
        frameGap: root.service ? (root.service.perf >= 2 ? 0.05 : (root.service.perf === 1 ? 0.036 : 0.028)) : 0.028
    }

    // ===== pc engine (non-Sekai styles) =====
    readonly property string pcCavaConf: root.pluginApi ? root.pluginApi.pluginDir + "/content/cava-pc.conf" : ""

    Process {
        id: pcCava
        running: root.pluginApi !== null && root.wantAudio && !root.isSekai
        command: root.pluginApi ? ["setpriv", "--pdeathsig", "TERM", "nice", "-n", "5", "cava", "-p", root.pluginApi.pluginDir + "/content/cava-pc.conf"] : []
        stdout: SplitParser {
            onRead: data => pcEngine.raw = root.parseBands(data)
        }
        onRunningChanged: { if (!pcCava.running) pcEngine.raw = [] }
    }

    ShaderVisualizerEngine {
        id: pcEngine
        raw: []
        active: !root.isSekai && (root.service ? root.service.shown : true)
        demo: !root.wantAudio
        sensitivity: root.service ? root.service.sensitivity : 1.0
        frameGap: root.service ? (root.service.perf >= 2 ? 0.05 : (root.service.perf === 1 ? 0.028 : 0)) : 0
    }

    // ===== cover =====
    VisualizerCover {
        id: cover
        artUrl: media.artUrl
        enabled: !root.isSekai && (root.isRing || (root.service ? root.service.colorMode === 0 : false))
    }

    readonly property int sizeIndex: root.service ? root.service.sizeIndex : 1
    readonly property var sizePair: {
        const sizes = [[264, 236], [320, 276], [420, 350], [520, 430]]
        return sizes[sizeIndex] ?? sizes[1]
    }

    implicitWidth: isSekai ? sizePair[0] : (isBand ? 400 : styleSize)
    implicitHeight: isSekai ? sizePair[1] : (isBand ? 240 : styleSize)





    // styleSize helper on service? add below via property
    // Actually compute here:
    // ring/band sizes
    readonly property int styleSize: {
        const si = sizeIndex
        const ringSizes = [260, 340, 420, 520]
        const bandHeights = [180, 240, 300, 380]
        return (root.service && root.service.isRing) ? (ringSizes[si] ?? 340) : (bandHeights[si] ?? 240)
    }

    // fix implicit for non-sekai
    // override:
    // (recompute implicitWidth/Height properly)
    // We'll set them via the card below instead; keep implicit for host measurement:
    // Use a fixed default for non-sekai to avoid NaN:
    // (already set above; adjust if needed)

    readonly property color neutralInk: sekaiTheme.dark ? Qt.color("#ffffff") : Qt.color(sekaiTheme.colBorder)

    readonly property var themePalette: {
        const A = sekaiTheme.accentCyan, B = sekaiTheme.accentMint, P = sekaiTheme.irisColorPink
        switch (root.service ? root.service.style : "sekai") {
            case "ring": return [A, B, Qt.lighter(A, 1.25)]
            case "dots": return [neutralInk, A, P]
            default: return [A, B, P]
        }
    }
    readonly property var attrPalette: {
        const a = sekaiTheme.attributeColors
        const st = root.service ? root.service.style : "sekai"
        switch (st) {
            case "dots": return [neutralInk, Qt.color(a[1]), Qt.color(a[2])]
            case "bars":
            case "mirror": return [Qt.color(a[0]), Qt.color(a[3]), Qt.color(a[1])]
            default: return [Qt.color(a[0]), Qt.color(a[1]), Qt.color(a[3])]
        }
    }
    readonly property var shapeColors: {
        const mode = root.service ? root.service.colorMode : 0
        if (mode === 2) return themePalette
        if (mode === 0 && cover.palette) {
            const c = cover.palette
            const st = root.service ? root.service.style : "sekai"
            return st === "dots" ? [neutralInk, c[0], c[1]] : c
        }
        return attrPalette
    }

    // ===== card =====
    Item {
        id: card
        width: root.isSekai ? root.sizePair[0] : (root.isBand ? (root.service && root.service.vertical ? root.styleSize : (root.screen ? root.screen.width : 800)) : root.styleSize)
        height: root.isSekai ? root.sizePair[1] : (root.service && root.service.vertical ? (root.screen ? root.screen.height : 600) : root.styleSize)

        property real reveal: 0
        property real bump: 1

        // Sekai card: pop-in
        scale: root.isSekai ? (bump * Math.max(0, reveal)) : 1
        opacity: root.isSekai ? Math.max(0, Math.min(1, reveal)) : Math.max(0, Math.min(1, reveal))
        transformOrigin: Item.Center

        Component.onCompleted: {
            reveal = 0
            Qt.callLater(() => popIn.start())
        }
        NumberAnimation { id: popIn; target: card; property: "reveal"; to: 1; duration: 460; easing.type: Easing.OutBack; easing.overshoot: 1.9 }

        // Sekai style
        SekaiVisualizer {
            anchors.fill: parent
            visible: root.isSekai
            theme: sekaiTheme
            service: root.service
            engine: levelEngine
            media: media
            interactive: true
            active: true
        }

        // non-Sekai: rotor + styles
        Item {
            id: rotor
            anchors.centerIn: parent
            width: (root.service && root.service.vertical) ? card.height : card.width
            height: (root.service && root.service.vertical) ? card.width : card.height
            rotation: (root.service && root.service.vertical) ? ((card.x + card.width/2 < (root.screen ? root.screen.width : 800)/2) ? 90 : -90) : 0
            visible: !root.isSekai

            Item {
                id: flip
                anchors.fill: parent
                transform: Scale {
                    origin.x: flip.width / 2
                    origin.y: flip.height / 2
                    xScale: (root.service && root.service.vertical && (card.x + card.width/2 < (root.screen ? root.screen.width : 800)/2)) ? -1 : 1
                    yScale: (root.isBand && !(root.service && root.service.vertical) && (card.y + card.height/2 < (root.screen ? root.screen.height : 600)/2)) ? -1 : 1
                }

                Loader {
                    anchors.fill: parent
                    active: !root.isSekai
                    sourceComponent: Item {
                        Item {
                            id: coverItem
                            width: 512; height: 512
                            visible: root.isRing
                            Image {
                                anchors.fill: parent
                                source: root.isRing ? cover.coverUrl : ""
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(512, 512)
                                asynchronous: true
                                smooth: true
                            }
                        }
                        ShaderEffectSource {
                            id: coverTexture
                            sourceItem: coverItem
                            hideSource: true
                            visible: false
                        }

                        Loader {
                            anchors.fill: parent
                            active: root.service && root.service.style === "bars"
                            sourceComponent: ShaderBarsVisualizer {
                                anchors.fill: parent
                                points: pcEngine.raw
                                fullWidth: rotor.width
                                color1: root.shapeColors[0]
                                color2: root.shapeColors[1]
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            active: root.service && root.service.style === "tide"
                            sourceComponent: TideVisualizer {
                                anchors.fill: parent
                                engine: pcEngine
                                color1: root.shapeColors[0]
                                color2: root.shapeColors[1]
                                color3: root.shapeColors[2]
                                ink: sekaiTheme.colBorder
                                lite: root.service ? root.service.perf >= 2 : false
                            }
                        }

                        Loader {
                            anchors.fill: parent
                            active: root.service && root.service.style !== "bars" && root.service.style !== "tide" && root.service.style !== "sekai"
                            sourceComponent: ShaderVisualizerLayer {
                                anchors.fill: parent
                                style: root.service ? root.service.style : "aurora"
                                engine: pcEngine
                                ink: sekaiTheme.colBorder
                                color1: root.shapeColors[0]
                                color2: root.shapeColors[1]
                                color3: root.shapeColors[2]
                                cover: coverTexture
                                hasCover: cover.coverUrl !== "" ? 1 : 0
                                lite: root.service && root.service.perf >= 2 ? 1 : 0
                            }
                        }
                    }
                }
            }
        }

        // corner buttons (hover) - size + style
        property bool btnShown: false
        property string chipText: ""

        HoverHandler {
            onHoveredChanged: {
                if (hovered) card.btnShown = true
                else hideTimer.restart()
            }
        }
        Timer { id: hideTimer; interval: 900; onTriggered: card.btnShown = false }

        Row {
            id: btnRow
            z: 20
            spacing: 6
            x: card.width - btnRow.width + 10
            y: -12
            visible: opacity > 0.01
            opacity: card.btnShown ? 1 : 0
            scale: card.btnShown ? 1 : 0.6
            transformOrigin: Item.Center
            Behavior on opacity { NumberAnimation { duration: 140 } }
            Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 } }

            // style cycle
            Pill {
                theme: sekaiTheme
                width: 30; height: 34
                cornerRadius: 10; ringWidth: 3
                pressed: styleArea.pressed
                fillGradient: Gradient {
                    GradientStop { position: 0.0; color: sekaiTheme.accentMint }
                    GradientStop { position: 1.0; color: sekaiTheme.accentCyan }
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    theme: sekaiTheme
                    name: "style"
                    size: 18; weight: 600
                    color: sekaiTheme.colBorder
                }
                MouseArea {
                    id: styleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.service) root.service.cycleStyle() }
                }
            }

            // size cycle
            Pill {
                theme: sekaiTheme
                width: 30; height: 34
                cornerRadius: 10; ringWidth: 3
                pressed: sizeArea.pressed
                fillGradient: Gradient {
                    GradientStop { position: 0.0; color: sekaiTheme.accentMint }
                    GradientStop { position: 1.0; color: sekaiTheme.accentCyan }
                }
                MaterialIcon {
                    anchors.centerIn: parent
                    theme: sekaiTheme
                    name: "aspect_ratio"
                    size: 18; weight: 600
                    color: sekaiTheme.colBorder
                }
                MouseArea {
                    id: sizeArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { if (root.service) root.service.cycleSize() }
                }
            }
        }

        Pill {
            theme: sekaiTheme
            id: nameChip
            z: 19
            visible: card.btnShown
            x: btnRow.x - nameChip.width - 4
            y: btnRow.y + (btnRow.height - nameChip.height) / 2
            width: nameText.implicitWidth + 24
            height: 30
            cornerRadius: 10
            ringWidth: 3
            fillColor: sekaiTheme.chipFill

            Text {
                id: nameText
                anchors.centerIn: parent
                text: {
                    const svc = root.service
                    const styleName = svc ? svc.style.toUpperCase() : "SEKAI"
                    const sizeNames = ["S", "M", "L", "XL"]
                    const sizeName = sizeNames[root.sizeIndex] ?? "M"
                    return styleName + "  ·  " + sizeName
                }
                color: sekaiTheme.chipInk
                font.family: sekaiTheme.fontFamily
                font.pixelSize: 11
                font.weight: Font.ExtraBold
                font.styleName: sekaiTheme.fontStyleBold
            }
        }
    }
}
