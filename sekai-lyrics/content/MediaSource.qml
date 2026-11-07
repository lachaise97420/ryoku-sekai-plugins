import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// SekaiPop's MediaSource.qml, verbatim: the MPRIS player the lyrics follow.
// Anything that publishes itself over MPRIS shows up here (Ryotunes, Spotify,
// mpv, VLC, browsers).
Scope {
    id: root

    property var lastStarted: null

    readonly property var player: pickPlayer()

    readonly property bool present: player !== null
    readonly property bool playing: player !== null
        && player.playbackState === MprisPlaybackState.Playing

    readonly property string title: {
        if (player === null)
            return ""
        return player.trackTitle !== "" ? player.trackTitle : (player.identity ?? "")
    }
    readonly property string artist: player?.trackArtist ?? ""

    readonly property string artUrl: {
        if (player === null)
            return ""
        const direct = player.trackArtUrl ?? ""
        return direct !== "" ? direct : youtubeThumbnail()
    }

    function youtubeThumbnail() {
        const md = player.metadata
        const url = md ? md["xesam:url"] : undefined
        if (typeof url !== "string")
            return ""
        const m = url.match(/(?:[?&]v=|youtu\.be\/|\/shorts\/)([A-Za-z0-9_-]{11})/)
        return m ? "https://i.ytimg.com/vi/" + m[1] + "/mqdefault.jpg" : ""
    }

    function pickPlayer() {
        const list = Mpris.players.values

        // Rule 1: the last player that actually started playing keeps
        // the widget for as long as it's still around, playing or
        // paused.
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            if (p === lastStarted
                    && (p.playbackState === MprisPlaybackState.Playing || p.trackTitle !== ""))
                return p
        }

        let playing = null
        let paused = null
        for (let i = 0; i < list.length; i++) {
            const p = list[i]
            if (p.playbackState === MprisPlaybackState.Playing) {
                if (playing === null)
                    playing = p
            } else if (p.trackTitle !== "" && paused === null) {
                paused = p
            }
        }
        return playing !== null ? playing : paused
    }

    // Remember whichever player last switched to Playing.
    Instantiator {
        model: Mpris.players

        delegate: Connections {
            required property var modelData
            target: modelData

            function onPlaybackStateChanged() {
                if (modelData.playbackState === MprisPlaybackState.Playing)
                    root.lastStarted = modelData
            }
        }
    }
}
