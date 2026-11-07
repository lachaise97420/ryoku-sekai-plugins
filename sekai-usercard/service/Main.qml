import QtQuick
import Quickshell
import Quickshell.Io
import "Framing.js" as FR

// The user card's own pictures (banner + avatar): picked and framed like
// SekaiPop's Quick Panel pictures, but stored under this plugin's state
// directory so Ryoku's plugin rules are met. Reads SekaiPop's existing
// avatar / banner (and their framing) read-only on first run.
Item {
    id: root
    property var pluginApi

    readonly property string stateDir: {
        const xdg = Quickshell.env("XDG_STATE_HOME")
        const base = (xdg && xdg.length > 0) ? xdg : (Quickshell.env("HOME") + "/.local/state")
        return base + "/ryoku/plugins/sekai-usercard"
    }
    readonly property string picturesDir: root.stateDir + "/pictures"
    readonly property string manifestPath: root.stateDir + "/images.json"
    readonly property string script: (pluginApi ? pluginApi.pluginDir : "") + "/bin/usercard-state.sh"
    readonly property string pickScript: (pluginApi ? pluginApi.pluginDir : "") + "/bin/pick-image.sh"

    // False until the saved state has been read.
    property bool loaded: false

    property string avatar: ""
    property string banner: ""

    function pathFor(url) {
        if (!url || url.indexOf("file://") !== 0)
            return ""
        try {
            return decodeURIComponent(url.slice(7))
        } catch (e) {
            return ""
        }
    }
    readonly property string avatarPath: pathFor(avatar)
    readonly property string bannerPath: pathFor(banner)

    // ===== framing =====
    property string framingRaw: ""
    readonly property var framings: FR.parse(root.framingRaw)

    function pathOf(kind) {
        return kind === "avatar" ? root.avatarPath : (kind === "banner" ? root.bannerPath : "")
    }

    function framingFor(kind) {
        return FR.forPicture(root.framings, kind, root.pathOf(kind))
    }

    function setFraming(kind, f) {
        const next = FR.withFraming(root.framings, kind, root.pathOf(kind), f)
        root.framingRaw = FR.stringify(next)
        root.persist()
    }

    // The framer: "" while closed, else the kind it frames.
    property string framing: ""
    property bool framingFresh: false
    property int framingSeq: 0

    property var pending: null
    property var clearQueue: []

    readonly property bool busy: picker.running

    // ===== helpers =====
    function urlFor(path) {
        if (path === "")
            return ""
        return "file://" + encodeURI(path).replace(/#/g, "%23").replace(/\?/g, "%3F")
    }

    function assign(kind, path) {
        if (kind === "avatar")
            avatar = urlFor(path)
        else if (kind === "banner")
            banner = urlFor(path)
    }

    function isOwnPath(path) {
        return typeof path === "string" && path.indexOf(root.picturesDir + "/") === 0
    }

    function drop(path) {
        if (path !== "")
            Quickshell.execDetached(["sh", root.pickScript, "drop", path])
    }

    function clear(kind) {
        if (root.pending && root.pending.kind === kind)
            root.pending = null
        if (root.framing === kind) {
            root.framing = ""
            root.framingFresh = false
        }
        const prev = root.pathOf(kind)
        assign(kind, "")
        if (isOwnPath(prev))
            drop(prev)
        root.clearQueue = root.clearQueue.concat([kind])
        root.pumpClear()
        root.persist()
    }

    function pumpClear() {
        if (clearer.running || root.clearQueue.length === 0)
            return
        clearer.kind = root.clearQueue[0]
        root.clearQueue = root.clearQueue.slice(1)
        clearer.running = true
    }

    function frame(kind, fresh) {
        if (FR.KINDS.indexOf(kind) < 0 || root.pathOf(kind) === "")
            return
        root.framingFresh = fresh === true
        root.framing = kind
        root.framingSeq++
    }

    function closeFramer(saved) {
        const p = root.pending
        if (p && p.kind === root.framing) {
            root.pending = null
            if (saved === true) {
                if (p.prev !== "" && isOwnPath(p.prev))
                    drop(p.prev)
            } else {
                assign(p.kind, p.prev)
                if (isOwnPath(p.next))
                    drop(p.next)
            }
            root.persist()
        }
        root.framing = ""
        root.framingFresh = false
    }

    function pick(kind) {
        if (picker.running)
            return
        picker.kind = kind
        picker.running = true
    }

    // ===== picker process =====
    Process {
        id: picker

        property string kind: ""

        command: ["sh", root.pickScript, "pick", kind]
        stdout: StdioCollector {
            onStreamFinished: {
                const path = text.trim()
                if (path === "")
                    return
                if (root.pending && root.pending.kind === picker.kind && root.pending.next !== path)
                    drop(root.pending.next)
                const prev = root.pending && root.pending.kind === picker.kind ? root.pending.prev : root.pathOf(picker.kind)
                const prevMode = ""
                root.pending = { kind: picker.kind, prev: prev, next: path, prevMode: prevMode }
                assign(picker.kind, path)
                root.frame(picker.kind, true)
            }
        }
    }

    Process {
        id: clearer

        property string kind: ""

        command: ["sh", root.pickScript, "clear", kind]
        onExited: root.pumpClear()
    }

    // ===== persistence =====
    function snapshot() {
        return JSON.stringify({
            avatar: root.avatarPath,
            banner: root.bannerPath,
            framing: root.framingRaw
        })
    }

    function restore(text) {

        let data = null
        try {
            data = JSON.parse(text)
        } catch (e) {
            data = null
        }
        if (data) {
            if (typeof data.avatar === "string")
                avatar = urlFor(data.avatar)
            if (typeof data.banner === "string")
                banner = urlFor(data.banner)
            if (typeof data.framing === "string")
                framingRaw = data.framing
            root.loaded = true
            return
        }
        // First run: seed from SekaiPop's existing pictures and framing.
        root.seed()
    }

    function seed() {

        seedProc.running = true
    }

    Process {
        id: seedProc
        command: ["sh", root.pickScript, "seed"]
        stdout: StdioCollector {
            onStreamFinished: {

                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const sp = lines[i].indexOf(" ")
                    if (sp > 0) {
                        const k = lines[i].slice(0, sp)
                        const p = lines[i].slice(sp + 1)
                        if (k === "avatar" || k === "banner")
                            assign(k, p)
                    }
                }
                // Seed framing from SekaiPop's settings.json.
                seedFramingProc.running = true
            }
        }
    }

    Process {
        id: seedFramingProc
        command: ["cat", Quickshell.env("HOME") + "/.config/sekaipop/settings.json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)
                    if (d && typeof d["pictures.framing"] === "string")
                        framingRaw = d["pictures.framing"]
                } catch (e) { }
                root.loaded = true
                root.persist()
            }
        }
    }

    // FileView over the manifest (blockLoading so restore runs with text ready).
    FileView {
        id: manifestFile
        path: root.manifestPath
        blockLoading: true
        printErrors: false
        watchChanges: true
        onLoaded: root.restore(String(manifestFile.text()))
    }

    Component.onCompleted: {
        // Ensure the state dir exists.
        Quickshell.execDetached(["mkdir", "-p", root.stateDir, root.picturesDir])
    }

    onPluginApiChanged: {
        if (!root.loaded && pluginApi)
            Qt.callLater(() => root.restore(String(manifestFile.text())))
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
            if (saver.running) {
                saver.pending = json
                return
            }
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
