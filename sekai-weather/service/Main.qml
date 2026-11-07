import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var pluginApi

    readonly property string stateDir: {
        const xdg = Quickshell.env("XDG_STATE_HOME")
        const base = (xdg && xdg.length > 0) ? xdg : (Quickshell.env("HOME") + "/.local/state")
        return base + "/ryoku/plugins/sekai-weather"
    }
    readonly property string script: (pluginApi ? pluginApi.pluginDir : "") + "/bin/weathercard-state.sh"

    property bool loaded: false
    property bool shown: true
    property string style: "classic"
    readonly property bool minimal: root.style === "minimal"

    function setStyle(value) {
        const v = value === "minimal" ? "minimal" : "classic"
        if (v === root.style) return
        root.style = v
        root.persist()
    }

    function toggleStyle() {
        root.setStyle(root.minimal ? "classic" : "minimal")
    }

    function setShown(value) {
        root.shown = value === true
        root.persist()
    }

    function snapshot() {
        return JSON.stringify({ shown: root.shown, style: root.style })
    }

    function restore(text) {
        try {
            const s = JSON.parse(text)
            root.shown = s.shown !== false
            if (typeof s.style === "string")
                root.style = s.style === "minimal" ? "minimal" : "classic"
        } catch (e) {}
        root.loaded = true
    }

    FileView {
        id: stateFile
        path: root.stateDir + "/weathercard.json"
        blockLoading: true
        printErrors: false
        watchChanges: true
        onLoaded: root.restore(String(stateFile.text()))
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.stateDir])
        root.restore(String(stateFile.text()))
    }

    function persist() {
        if (root.loaded) saveTimer.restart()
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
