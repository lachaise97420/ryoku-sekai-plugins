import QtQuick
import Quickshell
import Quickshell.Io

// The desktop audio visualizer's state, ported from SekaiPop's VisualizerService.qml.
// Ryoku owns placement, dragging and scaling, so position/shown/band geometry are
// dropped (or kept as no-ops for compatibility with the SekaiVisualizer). The
// look/size/colours/sensitivity and audio settings are kept and persisted.
Item {
    id: root
    property var pluginApi

    readonly property string stateDir: {
        const xdg = Quickshell.env("XDG_STATE_HOME")
        const base = (xdg && xdg.length > 0) ? xdg : (Quickshell.env("HOME") + "/.local/state")
        return base + "/ryoku/plugins/sekai-visualizer"
    }
    readonly property string script: (pluginApi ? pluginApi.pluginDir : "") + "/bin/visualizer-state.sh"

    property bool loaded: false
    property bool shown: true

    property string style: "sekai"
    // Only the card styles are exposed: the band styles (bars, aurora, dots,
    // mirror, tide, ribbons, scope, pulse) span the whole screen in SekaiPop
    // and do not fit Ryoku's tiled desktop widget model, so they are not
    // cycled here. The Sekai card and the ring stay movable cards.
    readonly property var styles: ["sekai", "ring"]
    readonly property bool isSekai: root.style === "sekai"
    readonly property bool isRing: root.style === "ring"
    readonly property bool isBand: false

    property real bandY: -1
    property bool vertical: false
    property real bandX: -1
    property string pillStyle: "none"

    property int colorMode: 0
    readonly property int colorModeCount: 3
    property int sizeIndex: 1
    property bool stayWhenPaused: true
    readonly property int sizeCount: 4
    property real sensitivity: 1.0
    property bool alwaysListen: false
    property bool analyzer: true
    property bool useAubio: true

    property int perf: 0
    readonly property int perfCount: 3
    readonly property real frameGap: root.perf >= 2 ? 0.05 : (root.perf === 1 ? 0.036 : 0.028)

    // Placement is Ryoku's; keep these as no-ops for compatibility.
    property real posX: -1
    property real posY: -1
    property real posScale: 1
    property string screenName: ""

    function setPosition(x, y, screen, scale) {
        // no-op: Ryoku owns placement
    }

    function setShown(value) {
        root.shown = value === true
        root.persist()
    }

    function setStyle(value) {
        const v = String(value).toLowerCase()
        if (root.styles.indexOf(v) < 0)
            return
        root.style = v
        root.persist()
    }

    function cycleStyle() {
        root.setStyle(root.styles[(root.styles.indexOf(root.style) + 1) % root.styles.length])
    }

    function setPillStyle(value) {
        const v = String(value).toLowerCase()
        if (v !== "none" && v !== "dots" && v !== "wave")
            return
        root.pillStyle = v
        root.persist()
    }

    function setColorMode(value) {
        const n = Math.round(Number(value))
        if (!isFinite(n))
            return
        root.colorMode = Math.max(0, Math.min(root.colorModeCount - 1, n))
        root.persist()
    }

    function setVertical(value) {
        root.vertical = value === true
        root.persist()
    }

    function toggleVertical() {
        root.setVertical(!root.vertical)
    }

    function setSize(value) {
        const n = Math.round(Number(value))
        if (!isFinite(n))
            return
        root.sizeIndex = Math.max(0, Math.min(root.sizeCount - 1, n))
        root.persist()
    }

    function cycleSize() {
        root.setSize((root.sizeIndex + 1) % root.sizeCount)
    }

    function setSensitivity(value) {
        const v = Number(value)
        if (!isFinite(v))
            return
        root.sensitivity = Math.max(0.5, Math.min(2.5, v))
        root.persist()
    }

    function setStayWhenPaused(value) {
        root.stayWhenPaused = value === true
        root.persist()
    }

    function setAlwaysListen(value) {
        root.alwaysListen = value === true
        root.persist()
    }

    function setUseAubio(value) {
        root.useAubio = value === true
        root.persist()
    }

    function setPerf(value) {
        const n = Math.round(Number(value))
        if (!isFinite(n))
            return
        root.perf = Math.max(0, Math.min(root.perfCount - 1, n))
        root.persist()
    }

    function setAnalyzer(value) {
        root.analyzer = value === true
        root.persist()
    }

    function snapshot() {
        return JSON.stringify({
            style: root.style,
            bandY: root.bandY,
            bandX: root.bandX,
            vertical: root.vertical,
            pillStyle: root.pillStyle,
            colors: root.colorMode,
            size: root.sizeIndex,
            sensitivity: root.sensitivity,
            stayWhenPaused: root.stayWhenPaused,
            alwaysListen: root.alwaysListen,
            analyzer: root.analyzer,
            useAubio: root.useAubio,
            perf: root.perf
        })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            if (typeof s.style === "string" && root.styles.indexOf(s.style) >= 0)
                root.style = s.style
            if (typeof s.bandY === "number")
                root.bandY = s.bandY
            if (typeof s.bandX === "number")
                root.bandX = s.bandX
            root.vertical = s.vertical === true
            if (s.pillStyle === "none" || s.pillStyle === "dots" || s.pillStyle === "wave")
                root.pillStyle = s.pillStyle
            if (typeof s.colors === "number")
                root.colorMode = Math.max(0, Math.min(root.colorModeCount - 1, Math.round(s.colors)))
            if (typeof s.size === "number")
                root.sizeIndex = Math.max(0, Math.min(root.sizeCount - 1, Math.round(s.size)))
            if (typeof s.sensitivity === "number")
                root.sensitivity = Math.max(0.5, Math.min(2.5, s.sensitivity))
            root.stayWhenPaused = s.stayWhenPaused !== false
            root.alwaysListen = s.alwaysListen === true
            root.analyzer = s.analyzer !== false
            root.useAubio = s.useAubio !== false
            if (typeof s.perf === "number")
                root.perf = Math.max(0, Math.min(root.perfCount - 1, Math.round(s.perf)))
        } catch (e) {
        }
        root.loaded = true
    }

    FileView {
        id: stateFile
        path: root.stateDir + "/visualizer.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onLoaded: root.restore(String(stateFile.text()))
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.stateDir])
        root.restore(String(stateFile.text()))
    }

    onPluginApiChanged: {
        // no-op
    }

    function persist() {
        if (root.loaded)
            saveTimer.restart()
    }

    Timer {
        id: saveTimer
        interval: 300
        onTriggered: saver.save(root.snapshot())
    }

    Process {
        id: saver
        property var pending: null
        function save(json) {
            if (saver.running) { saver.pending = json; return }
            saver.pending = null
            saver.exec(["sh", root.script, "save", json])
        }
        onExited: {
            if (saver.pending !== null) {
                const json = saver.pending
                saver.pending = null
                saver.exec(["sh", root.script, "save", json])
            }
        }
    }
}
