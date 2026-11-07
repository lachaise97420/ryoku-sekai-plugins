pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons
import "LyricsMath.js" as LM

// SekaiPop's desktop lyrics widget, ported to Ryoku.
//
// The words of the song that is playing, sung along on the desktop. There is no
// card: the lyrics are stickers (a navy outline and a hard shadow, see
// LyricsWord.qml) lying straight on the wallpaper, so it is transparent
// everywhere except the letters.
//
//   The stack    the line being sung is big in the middle; the one before it has slid up and
//                faded, the one to come waits below, small and tilted.
//   The singing  the words of the line fill with colour as they are sung, and a diamond
//                bounces from word to word, landing on each exactly as it starts.
//   Taken over   when the next line begins while this one is still being sung, the line is
//                held just above the new line, still strong, and goes on singing.
//   The gaps     an intro or an instrumental part is three diamonds that light one by one.
//
// Everything below is LyricsWidget.qml's logic and layout, with SekaiPop's
// window / edit-mode / clone plumbing removed because the Ryoku host owns
// placement, dragging and scaling. The theme is SekaiPop's own (SekaiTheme.qml),
// not Ryoku's palette.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "full"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null

    // SekaiPop's palette, read from its own state (theme / dark / darker).
    SekaiTheme {
        id: sekaiTheme
    }

    // The room the lyrics have: the stack of lines is centred in it, the tag is
    // under it. Nothing is drawn behind it.
    implicitWidth: 720
    implicitHeight: 244

    // ===== the player =====
    // Where the track and the time come from (the bar, the dock and the lockscreen each
    // have their own MediaSource too). Only built while the widget is switched on.
    Loader {
        active: root.working

        sourceComponent: Item {
            visible: false

            MediaSource {
                id: source

                Component.onCompleted: root.media = source
                Component.onDestruction: if (root.media === source) root.media = null
            }
        }
    }

    property var media: null
    readonly property var player: root.media ? root.media.player : null
    readonly property bool present: root.player !== null && root.player !== undefined
    readonly property bool playing: root.media ? root.media.playing : false

    // Edit Desktop with nothing playing: a made-up verse, so there is something to place.
    // Ryoku has no edit mode, so this is always off; the property is kept because the
    // rest of the widget reads it exactly as SekaiPop does.
    readonly property bool demo: false
    readonly property var demoLines: []
    readonly property real demoTotal: 18

    readonly property string trackTitle: root.player ? String(root.player.trackTitle ?? "") : ""
    readonly property string trackArtist: root.player ? String(root.player.trackArtist ?? "") : ""
    readonly property string trackAlbum: root.player ? String(root.player.trackAlbum ?? "") : ""
    readonly property real trackLength: (root.player && root.player.lengthSupported) ? Number(root.player.length) : 0
    readonly property string trackUrl: {
        const md = root.player ? root.player.metadata : null
        const u = md ? md["xesam:url"] : undefined
        return typeof u === "string" ? u : ""
    }
    readonly property string trackSig: [root.trackTitle, root.trackArtist, root.trackAlbum, Math.round(root.trackLength), root.trackUrl].join("\u241f")

    // A new song restarts the clock; the length arriving a moment after the title (a browser)
    // must not, so the two are told apart.
    readonly property string identSig: [root.trackTitle, root.trackArtist, root.trackUrl].join("\u241f")

    onIdentSigChanged: {
        root.clk = LM.clockReset(0, Date.now())
        root.lastPolled = -1
        root.stalePolls = 0
        root.poll()
    }

    onTrackSigChanged: reqTimer.restart()

    onWorkingChanged: reqTimer.restart()

    // Players change the title first and the length a moment later, so wait a beat.
    Timer {
        id: reqTimer
        interval: 500
        onTriggered: {
            if (!root.working || !root.service)
                return
            if (root.trackTitle === "")
                root.service.clear()
            else
                root.service.request(root.trackArtist, root.trackTitle, root.trackAlbum, root.trackLength, root.trackUrl)
        }
    }

    // ===== the clock =====
    // The player's position is read four times a second; between the readings a clock runs
    // on its own, set by the best of the last ten readings (LyricsMath.observe).
    property var clk: LM.clockReset(0, 0)
    property real now: Date.now()
    // The last reading, and how many in a row said the same while playing (LyricsMath.pollTrust:
    // a position that does not move is not trusted, the clock runs on its own instead).
    property real lastPolled: -1
    property int stalePolls: 0

    function poll() {
        const p = root.player
        if (!p || !p.positionSupported)
            return
        p.positionChanged()
        const polled = Number(p.position)
        if (!isFinite(polled))
            return
        const trust = LM.pollTrust(root.lastPolled, polled, root.stalePolls, root.playing)
        root.lastPolled = polled
        root.stalePolls = trust.stale
        if (trust.use) {
            const stamp = Date.now()
            const before = LM.estimate(root.clk, stamp, root.playing)
            root.clk = LM.observe(root.clk, polled, stamp, root.playing)
            const jump = LM.estimate(root.clk, stamp, root.playing) - before
            // More than half a second at once is a seek (or a player that stalled). The log
            // says so, for working out why the words were off at some moment.
            if (root.playing && Math.abs(jump) > 0.5)
                console.log("[lyrics] clock moved " + (jump > 0 ? "+" : "") + jump.toFixed(2) + " s (a seek, or the player stalled)")
        }
        root.now = Date.now()
    }

    onPlayingChanged: {
        // Pause / resume: freeze the clock where it was (or restart it from there), so a
        // player that gives no position keeps its place too.
        const now = Date.now()
        root.clk = LM.clockReset(LM.estimate(root.clk, now, !root.playing), now)
        root.lastPolled = -1
        root.stalePolls = 0
        root.now = now
        root.poll()
    }

    Timer {
        interval: 250
        repeat: true
        running: root.working && root.present
        onTriggered: root.poll()
    }

    // Redraw every frame only while something on screen can still move. With no lyrics (a
    // video, a track nobody has words for, "looking for the words...") or once the last line
    // has been sung and has settled, nothing depends on the clock any more, so the window is
    // left alone instead of being redrawn at the screen's refresh rate for the rest of the
    // track. The 250 ms poll above still keeps `now` right, so a seek back, or the words
    // arriving, starts the frames again at once.
    readonly property real songEnd: {
        const n = root.lines.length
        if (n === 0)
            return 0
        // (an earlier line can be sung past a short last one, and the voice that sings along
        // can outlast its line)
        let e = Math.max(root.endOf(n - 1), root.bgEndOf(n - 1))
        if (n > 1)
            e = Math.max(e, root.endOf(n - 2))
        return e
    }
    // 3 s covers what settles after the last word: a held line lets go over 0.7 s, the
    // marker shrinks away in 0.26 s, the diamonds fly for 0.6 s.
    readonly property bool animating: root.demo || (root.lines.length > 0 && root.clockT < root.songEnd + 3)

    FrameAnimation {
        running: root.live && root.animating && (root.demo || root.playing)
        onTriggered: root.now = Date.now()
    }

    // The player's position is never newer than the sound and the sound takes a moment to leave
    // the speakers, so the words are shown this many seconds early on top of the nudge (the
    // nudge keys and `ipc lyrics nudgeAll` still move them from here).
    readonly property real playerLead: 0.2
    readonly property real clockT: root.demo
        ? (root.now / 1000) % root.demoTotal
        : LM.estimate(root.clk, root.now, root.playing) + root.playerLead + (root.service ? root.service.syncTotal / 1000 : 0)

    // ===== what is on =====
    readonly property var lines: root.demo ? root.demoLines : (root.service ? root.service.lines : [])
    // How long before a line starts the stack begins to climb to it (LyricsMath.cursor).
    readonly property real lead: 0.45
    readonly property real cursorV: LM.cursor(root.lines, root.clockT, root.lead, root.nextRush)
    readonly property int curIndex: LM.lineIndexAt(root.lines, root.clockT)
    readonly property int base: Math.round(root.cursorV)

    // How fast this song is sung, in syllables a second, learned from its own lines.
    readonly property real rate: LM.songRate(root.lines)

    // How much line i is held (0 .. 1): it is still being sung when the stack starts to climb
    // away from it (LyricsMath.leaveAt, rushOf). Such a line is held, not faded (see
    // LyricsLine.qml). A gap in the singing and the last line are never held.
    function rushAfter(i) {
        if (i < 0 || i + 1 >= root.lines.length)
            return 0
        const l = root.lines[i]
        if (l.text === "")
            return 0
        return LM.rushOf(LM.overrun(root.endOf(i), LM.leaveAt(l.t, root.lines[i + 1].t, root.lead)))
    }

    // How much the line after line i TAKES IT OVER (0 .. 1): it is still being sung when the
    // next one has begun. The stack then takes a little longer to climb and the new line lands
    // with a swell. Only changes when the line on changes, not every frame.
    function takeAfter(i) {
        if (i < 0 || i + 1 >= root.lines.length || root.lines[i].text === "")
            return 0
        return LM.rushOf(LM.overrun(root.endOf(i), root.lines[i + 1].t))
    }

    readonly property real nextRush: root.takeAfter(root.curIndex)

    // When line i has been sung by: its start plus the time its words take, never past the
    // start of the next. A line that says when it ends (an empty stamp after it) is taken at
    // its word; otherwise it is the amount of singing at the song's rate. A gap in the
    // singing lasts until the next line.
    function endOf(i) {
        const l = root.lines[i]
        if (!l)
            return 0
        const next = i + 1 < root.lines.length ? root.lines[i + 1].t : Infinity
        const room = next - l.t
        if (l.text === "")
            return l.t + (isFinite(room) ? room : 4)
        const known = (l.end !== undefined && l.end > l.t) ? l.end - l.t : undefined
        return l.t + LM.sungSpan(l.text, room, root.rate, known)
    }

    // When the voice that sings along with line i has been sung by (it can outlast the line).
    function bgEndOf(i) {
        const l = root.lines[i]
        if (!l || !l.bg)
            return 0
        return Math.max(root.endOf(i), l.bg.t + LM.sungSpan(l.bg.text, Infinity, root.rate))
    }

    // What the middle says when there are no lines to sing.
    readonly property string message: {
        if (root.demo || root.lines.length > 0)
            return ""
        switch (root.service ? root.service.status : "") {
        case "loading": return "looking for the words...";
        // "none" (no synced lyrics) and "instrumental" say nothing on purpose: a song without
        // words just shows its title under the card, no placeholder text in the middle.
        case "offline": return "can't reach the lyrics service";
        default: return "";
        }
    }

    // The small tag under the lyrics: what is playing.
    readonly property string tag: {
        if (root.demo)
            return "lyrics";
        // ipc lyrics debug: the numbers the timing is made of, instead of the title.
        if (root.service && root.service.debug)
            return "clock spread " + LM.clockSpread(root.clk) + " ms   line " + (root.curIndex + 1) + "/" + root.lines.length
                + "   " + root.rate.toFixed(1) + " syl/s   nudge " + (root.service.syncTotal / 1000).toFixed(1) + " s";
        const t = root.trackTitle
        const a = root.trackArtist
        let s = a !== "" ? (t + " - " + a) : t
        if (s.length > 56)
            s = s.slice(0, 55) + "..."
        // The lyrics were made for a cut of a different length: they may need a nudge.
        if (root.service && Math.abs(root.service.versionDiff) >= 1.5 && root.lines.length > 0)
            s += "  (lyrics for a " + Math.abs(root.service.versionDiff).toFixed(1) + " s " + (root.service.versionDiff > 0 ? "longer" : "shorter") + " cut)"
        return s
    }

    // ===== shown / hidden =====
    // The host's enabled + placed state is the switch; `shown` in SekaiPop's saved
    // state is left alone (the plugin is added/removed through Ryoku Settings).
    readonly property bool switchedOn: root.service !== null && root.service.loaded
    // Nothing to show while no player is around.
    readonly property bool want: root.switchedOn && root.present
    property real reveal: 0

    // Off while the saved state is read back, so a reload doesn't replay the pop.
    property bool armed: false

    onWantChanged: {
        if (!root.armed) {
            popIn.stop()
            fadeOut.stop()
            root.reveal = root.want ? 1 : 0
        } else if (root.want) {
            fadeOut.stop()
            popIn.restart()
        } else {
            popIn.stop()
            fadeOut.restart()
        }
    }

    NumberAnimation {
        id: popIn
        target: root
        property: "reveal"
        to: 1
        duration: 520
        easing.type: Easing.OutBack
        easing.overshoot: 1.6
    }

    NumberAnimation {
        id: fadeOut
        target: root
        property: "reveal"
        to: 0
        duration: 360
        easing.type: Easing.InCubic
    }

    Timer {
        interval: 800
        running: root.service !== null && root.service.loaded
        onTriggered: root.armed = true
    }

    // `live`: the widget is on, or still fading out.
    readonly property bool live: root.want || root.reveal > 0.001

    // The player is read while the widget is switched on (and while it fades out).
    readonly property bool working: root.switchedOn || root.reveal > 0.001

    Component.onCompleted: root.reveal = root.want ? 1 : 0

    // ===== the card =====
    Item {
        id: card

        readonly property real midY: 112
        width: 720
        height: 244

        scale: 0.72 + 0.28 * Math.max(0, root.reveal)
        opacity: Math.max(0, Math.min(1, root.reveal * 1.6))
        transformOrigin: Item.Center
        visible: opacity > 0.001

        // One Loader per line of the song, but only the lines within two of the middle
        // are built (so a long song costs nothing), and a line is built just before
        // it slides into view.
        Repeater {
            model: root.lines.length

            delegate: Loader {
                id: slot

                required property int index

                active: Math.abs(slot.index - root.base) <= 2

                sourceComponent: LyricsLine {
                    theme: sekaiTheme
                    text: root.lines[slot.index] ? root.lines[slot.index].text : ""
                    index: slot.index
                    curIndex: root.curIndex
                    lineStart: root.lines[slot.index] ? root.lines[slot.index].t : 0
                    lineEnd: root.endOf(slot.index)
                    rush: root.rushAfter(slot.index)
                    prevRush: root.rushAfter(slot.index - 1)
                    prevEnd: slot.index > 0 ? root.endOf(slot.index - 1) : 0
                    marks: (root.lines[slot.index] && root.lines[slot.index].marks) ? root.lines[slot.index].marks : []
                    bgText: (root.lines[slot.index] && root.lines[slot.index].bg) ? root.lines[slot.index].bg.text : ""
                    bgStart: (root.lines[slot.index] && root.lines[slot.index].bg) ? root.lines[slot.index].bg.t : 0
                    bgEnd: root.bgEndOf(slot.index)
                    t: root.clockT
                    d: slot.index - root.cursorV
                    playing: root.demo || root.playing
                    lineOnly: root.service ? root.service.lineOnly : false
                    maxW: card.width - 40
                    cx: card.width / 2
                    cy: card.midY
                }
            }
        }

        // A message in the middle when there is nothing to sing.
        LyricsLine {
            visible: root.message !== ""
            theme: sekaiTheme
            still: true
            text: root.message
            px: 30
            d: 0
            playing: true
            maxW: card.width - 40
            cx: card.width / 2
            cy: card.midY
        }

        // Point at the lyrics: the sync keys appear.
        HoverHandler {
            id: hover
        }

        readonly property bool keysOn: hover.hovered && !root.demo

        // Built only while pointed at (and while they fade out): four stickers are 56
        // text items that would otherwise sit there, unseen, for the whole song.
        Loader {
            id: syncKeys
            z: 3
            active: card.keysOn || syncKeys.opacity > 0.01
            opacity: card.keysOn ? 1 : 0
            visible: opacity > 0.01
            x: Math.round((card.width - width) / 2)
            y: card.height - 70

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            sourceComponent: Row {
                spacing: 16

                LyricsKey {
                    theme: sekaiTheme
                    label: "<< earlier"
                    visible: root.lines.length > 0
                    onClicked: {
                        if (root.service)
                            root.service.nudge(100)
                    }
                }

                // This song's nudge; a click clears it.
                LyricsKey {
                    theme: sekaiTheme
                    label: root.service
                        ? ((root.service.trackOffsetMs > 0 ? "+" : "") + (root.service.trackOffsetMs / 1000).toFixed(1) + " s")
                        : "0.0 s"
                    visible: root.lines.length > 0
                    onClicked: {
                        if (root.service)
                            root.service.setTrackOffset(0)
                    }
                }

                LyricsKey {
                    theme: sekaiTheme
                    label: "later >>"
                    visible: root.lines.length > 0
                    onClicked: {
                        if (root.service)
                            root.service.nudge(-100)
                    }
                }

                // Where the words come from, and what each provider found.
                LyricsKey {
                    theme: sekaiTheme
                    label: "sources"
                    onClicked: {
                        if (root.service)
                            root.service.togglePicker(root.screen ? root.screen.name : "", card.x + card.width / 2, card.y + card.height - 40)
                    }
                }
            }
        }

        // What is playing, small, under the lyrics.
        LyricsWord {
            theme: sekaiTheme
            visible: root.tag !== ""
            text: root.tag
            pixelSize: 15
            opacity: 0.78
            x: Math.round((card.width - width) / 2)
            y: card.height - height - 2
        }
    }

    // The source picker (SekaiPop's LyricsSources.qml), in a Popup because a Ryoku
    // plugin cannot add an overlay layer surface.
    LyricsSources {
        service: root.service
        theme: sekaiTheme
        screen: root.screen
        s: root.s
    }
}
