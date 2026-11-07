import QtQuick
import Quickshell
import Quickshell.Io

// SekaiPop's own theme, read from its state, so the widget looks exactly like
// it does in SekaiPop instead of being re-tinted by Ryoku's palette.
//
// The values below are ThemeSet.qml's derivations (dark / darker / light) over
// the six Project Sekai palettes, plus matugen when that is the chosen theme.
// State files (same ones SekaiPop writes):
//   ~/.local/state/sekaipop/theme    vs | leoneed | mmj | vbs | wxs | nightcord | mono | matugen | custom
//   ~/.local/state/sekaipop/dark     on | off
//   ~/.local/state/sekaipop/darker   on | off
//   ~/.cache/sekaipop/matugen/colors.json
Item {
    id: root

    visible: false
    width: 0
    height: 0

    property string themeId: "vs"
    property bool dark: true
    property bool darker: false
    property var matugenPal: null

    readonly property string stateDir: {
        const xdg = Quickshell.env("XDG_STATE_HOME")
        return ((xdg && xdg.length > 0) ? xdg : (Quickshell.env("HOME") + "/.local/state")) + "/sekaipop"
    }
    readonly property string cacheDir: {
        const xdg = Quickshell.env("XDG_CACHE_HOME")
        return ((xdg && xdg.length > 0) ? xdg : (Quickshell.env("HOME") + "/.cache")) + "/sekaipop"
    }

    FileView {
        id: themeFile
        path: root.stateDir + "/theme"
        blockLoading: true
        printErrors: false
        onLoaded: root.readTheme()
        onFileChanged: themeFile.reload()
    }
    FileView {
        id: darkFile
        path: root.stateDir + "/dark"
        blockLoading: true
        printErrors: false
        onLoaded: root.readDark()
        onFileChanged: darkFile.reload()
    }
    FileView {
        id: darkerFile
        path: root.stateDir + "/darker"
        blockLoading: true
        printErrors: false
        onLoaded: root.readDarker()
        onFileChanged: darkerFile.reload()
    }
    FileView {
        id: matugenFile
        path: root.cacheDir + "/matugen/colors.json"
        watchChanges: true
        printErrors: false
        onLoaded: root.readMatugen()
        onFileChanged: matugenFile.reload()
    }

    Component.onCompleted: {
        root.readTheme()
        root.readDark()
        root.readDarker()
        root.readMatugen()
    }

    function readTheme(): void {
        const t = String(themeFile.text()).trim()
        const ids = ["vs", "leoneed", "mmj", "vbs", "wxs", "nightcord", "mono", "matugen", "custom"]
        root.themeId = ids.indexOf(t) >= 0 ? t : "vs"
    }

    function readFlag(view, fallback) {
        const v = String(view.text()).trim()
        if (v === "on") return true
        if (v === "off") return false
        return fallback
    }

    function readDark(): void {
        root.dark = root.readFlag(darkFile, true)
    }

    function readDarker(): void {
        root.darker = root.readFlag(darkerFile, false)
    }

    function readMatugen(): void {
        try {
            const d = JSON.parse(String(matugenFile.text()))
            root.matugenPal = root.buildMatugen(d)
        } catch (e) {
            root.matugenPal = null
        }
    }

    // ThemeService.qml's buildMatugenPalette.
    function buildMatugen(d) {
        const dk = d && d.dark
        const lt = d && d.light
        if (!dk || !lt)
            return null
        const need = [
            [dk, ["primary", "on_primary", "primary_container", "secondary", "secondary_container", "tertiary", "inverse_primary", "outline"]],
            [lt, ["primary", "primary_container", "secondary_container", "surface", "surface_variant"]]
        ]
        for (let i = 0; i < need.length; i++)
            for (let j = 0; j < need[i][1].length; j++)
                if (!/^#[0-9a-fA-F]{6}$/.test(String(need[i][0][need[i][1][j]])))
                    return null
        return {
            border: dk.primary_container,
            A: dk.primary,
            B: dk.tertiary,
            deep: Qt.darker(Qt.color(dk.on_primary), 1.2),
            divider: lt.surface_variant,
            wallLight: dk.secondary
        }
    }

    // ThemeService.qml's six Project Sekai palettes (and Monochrome).
    readonly property var palettes: ({
        vs: { border: "#555473", A: "#04feee", B: "#00ffcb", deep: "#232235", divider: "#e4e4ec", wallLight: "#b3b2d4" },
        leoneed: { border: "#2d3775", A: "#8ea3ff", B: "#9fd8ff", deep: "#181e3f", divider: "#dee1f2", wallLight: "#a8b0de" },
        mmj: { border: "#39662d", A: "#a4ee55", B: "#7fe9a8", deep: "#223c1b", divider: "#e3f1df", wallLight: "#b6daac" },
        vbs: { border: "#561938", A: "#ff5c9a", B: "#ff96c0", deep: "#43142c", divider: "#f5dbe8", wallLight: "#e4a2c4" },
        wxs: { border: "#6a3c11", A: "#ffa51f", B: "#ffd54a", deep: "#4b2a0c", divider: "#f9e7d7", wallLight: "#eec298" },
        nightcord: { border: "#43285f", A: "#c08cf2", B: "#e2b5ff", deep: "#2b1a3d", divider: "#e8dff1", wallLight: "#c3abdb" },
        mono: { border: "#444444", A: "#f4f4f4", B: "#bdbdbd", deep: "#1a1a1a", divider: "#ececec", wallLight: "#bcbcbc" }
    })

    readonly property var pal: {
        if (root.themeId === "matugen" && root.matugenPal)
            return root.matugenPal
        return root.palettes[root.themeId] ? root.palettes[root.themeId] : root.palettes.vs
    }

    // ===== ThemeSet.qml, verbatim =====
    readonly property bool mono: pal.mono === true

    readonly property color colBorder: pal.border
    readonly property color colBg: "#ffffff"
    readonly property color accentCyan: pal.A
    readonly property color accentMint: pal.B
    readonly property color textWhite: "#ffffff"

    readonly property color surface: root.darker
        ? Qt.darker(Qt.color(pal.deep), 1.4)
        : (root.dark ? Qt.lighter(Qt.color(pal.deep), 1.18) : "#ffffff")
    readonly property color surfaceHover: root.dark ? Qt.lighter(surface, 1.35) : "#f2f2f2"
    readonly property color surfaceDivider: root.dark ? Qt.lighter(surface, 1.75) : pal.divider
    readonly property color ringWhite: root.darker
        ? Qt.lighter(surface, 2.0)
        : (root.dark ? Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, 0.08)) : "#ffffff")
    readonly property color surfaceRing: root.darker
        ? Qt.lighter(surface, 1.6)
        : (root.dark ? Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, 0.18)) : "#d9d9d9")
    readonly property color ink: root.dark ? Qt.color(pal.divider) : pal.border
    readonly property color inkSub: Qt.rgba(ink.r, ink.g, ink.b, 0.667)

    readonly property color line: root.darker
        ? Qt.darker(colBorder, 1.35)
        : (root.dark ? Qt.color(colBorder) : Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, 0.42)))
    readonly property color lineShadow: root.darker
        ? Qt.darker(colBorder, 1.8)
        : (root.dark ? Qt.darker(colBorder, 1.3) : Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, 0.30)))

    // The filled chips of the bar and popups.
    readonly property color chipFill: root.darker
        ? Qt.darker(colBorder, 1.35)
        : (root.dark ? Qt.color(colBorder) : Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, 0.14)))
    readonly property color chipInk: root.dark ? textWhite : Qt.color(colBorder)

    // Behind dialogs / the framer.
    readonly property color scrim: root.dark
        ? Qt.color(pal.deep)
        : Qt.tint(Qt.color("#ffffff"), Qt.rgba(colBorder.r, colBorder.g, colBorder.b, 0.10))

    // ===== Classic panel look =====
    readonly property bool classic: root.dark && !root.darker
    readonly property color colHover: "#f2f2f2"
    readonly property color colDivider: pal.divider
    readonly property color colOuterRing: "#d9d9d9"
    readonly property color colSubText: Qt.rgba(colBorder.r, colBorder.g, colBorder.b, 0.667)
    readonly property color pSurface: classic ? colBg : surface
    readonly property color pSurfaceHover: classic ? colHover : surfaceHover
    readonly property color pSurfaceDivider: classic ? colDivider : surfaceDivider
    readonly property color pSurfaceRing: classic ? colOuterRing : surfaceRing
    readonly property color pRingWhite: classic ? Qt.color("#ffffff") : ringWhite
    readonly property color pLine: classic ? colBorder : line
    readonly property color pLineShadow: classic ? colBorder : lineShadow
    readonly property color pInk: classic ? colBorder : ink
    readonly property color pInkSub: classic ? colSubText : inkSub

    // Shared pieces ask this: is `item` inside something that sets
    // `classicPanel: true`? Only then, and only in classic mode, they use the
    // classic colours (ThemeSet.qml's classicFor, verbatim).
    function classicFor(item) {
        if (!root.classic)
            return false
        for (let p = item; p; p = p.parent)
            if (p.classicPanel === true)
                return true
        return false
    }

    readonly property color colDeep: pal.deep

    readonly property real cardRing: root.dark ? root.borderWidth : 0
    readonly property int radiusOuter: 13
    readonly property int borderWidth: 3
    readonly property int shadowOffset: 4
    readonly property real whiteLine: 2
    readonly property int outerRingWidth: 4
    readonly property int pillHeight: 36

    // Capsule-bar hooks the shared Pill asks for; this port never draws one.
    function capsuleFor(item) { return false }
    function capsuleVerticalFor(item) { return false }
    readonly property real capChipHeight: 21
    readonly property real capVChip: 40
    readonly property real barVPillWidth: 52
    readonly property color capShade: "#000000"
    readonly property color capRim: "#000000"
    readonly property color capBody: "#ffffff"

    readonly property string fontFamily: "Noto Sans"
    readonly property string fontStyleBold: "ExtraBold"

    // The five Project Sekai card attributes (ThemeSet.qml, verbatim).
    readonly property var attributeColors: mono
        ? ["#e4e4e4", "#b0b0b0", "#f6f6f6", "#8c8c8c", "#cecece"]
        : ["#8EE3EF", "#FF9ECB", "#FFE066", "#B39DDB", "#A5E6A5"]

    // Icons (the framer and the picture row use the Solar outline set).
    readonly property string iconFont: "Material Symbols Rounded"
    readonly property real iconFill: 0
    readonly property string iconStyle: "outline"
    readonly property real iconWeight: 400
}
