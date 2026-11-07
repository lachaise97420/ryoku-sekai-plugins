pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "WeatherMath.js" as WM
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

Item {
    id: win

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "full"
    property real s: 1
    property real widthBudget: 0

    SekaiTheme { id: sekaiTheme }

    property var theme: sekaiTheme
    property var service
    property var settings

    readonly property var mt: theme

    Gradient {
        id: accentGradient
        GradientStop { position: 0.0; color: mt.accentMint }
        GradientStop { position: 1.0; color: mt.accentCyan }
    }

    component Water: Rectangle {
        id: water
        property var theme
        readonly property var mt: theme ? theme : win.theme
        property real level: 0
        property real corner: 10

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: parent.height * Math.max(0, Math.min(1, water.level))
        radius: water.corner
        antialiasing: true
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.36) }
            GradientStop { position: 1.0; color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.12) }
        }

        Rectangle {
            visible: water.height > water.corner
            x: water.corner * 0.7
            y: 1
            width: Math.max(0, water.width - water.corner * 1.4)
            height: 2
            radius: 1
            color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.85)
        }
    }

    component TileLabel: Text {
        property var theme
        readonly property var mt: theme ? theme : win.theme
        color: Qt.rgba(mt.pInk.r, mt.pInk.g, mt.pInk.b, 0.78)
        font.family: mt.fontFamily
        font.pixelSize: 9
        font.weight: Font.ExtraBold
        font.styleName: mt.fontStyleBold
        font.letterSpacing: 0.8
        elide: Text.ElideRight
    }

    property var _settingsShim: QtObject {
        function get(key) {
            const s = win.pluginApi ? win.pluginApi.pluginSettings : ({})
            if (key === "weather.view") return s.view !== undefined ? s.view : "days"
            if (key === "weather.location") return s.location !== undefined ? s.location : ""
            return s[key] !== undefined ? s[key] : ""
        }
        function flag(key) {
            const s = win.pluginApi ? win.pluginApi.pluginSettings : ({})
            if (key === "weather.fahrenheit") return s.fahrenheit === true
            if (key === "time.use24h") return s.use24h !== false
            return false
        }
        function set(key, value) {
            if (win.pluginApi) {
                const k = key === "weather.view" ? "view"
                    : (key === "weather.location" ? "location"
                    : (key === "weather.fahrenheit" ? "fahrenheit"
                    : (key === "time.use24h" ? "use24h" : key)))
                win.pluginApi.saveSetting(k, value)
            }
        }
    }
    onPluginApiChanged: win.settings = win._settingsShim

    // plumbing
    property real uiScale: 1
    readonly property real fullW: screen ? screen.width : 1920
    readonly property real fullH: screen ? screen.height : 1080
    readonly property real roomW: fullW
    readonly property real roomH: fullH
    property bool placed: true
    property real reveal: 0
    property real swapK: 1
    property bool gliding: false
    property bool glideOn: false
    property bool armed: true
    property bool want: true
    property bool live: true
    property bool working: true
    property bool switchedOn: true
    property bool compact: false
    property real boxX: 0
    property real boxY: 0
    property real boxW: fullW
    property real boxH: fullH
    property bool clone: false
    property var cloneSpot: null
    property bool spotReady: true
    property real spotX: -1
    property real spotY: -1
    property real spotScale: 0
    property string monitor: ""
    property string screenName: ""

    readonly property string wantedScreen: screenName

    function clearSpot() {}
    function fixSpotScale() {}
    function place(force) {}
    function saveSpot(x, y) {}

    // settings shim
    // (settings is provided by Widget.qml wrapper; here it's the pluginApi settings)
    // We'll create it below after pluginApi is set. For now, bind.

    // pop-in
    Component.onCompleted: {
        reveal = 0
        Qt.callLater(() => popIn.start())
    }
    NumberAnimation {
        id: popIn
        target: win
        property: "reveal"
        to: 1
        duration: 460
        easing.type: Easing.OutBack
        easing.overshoot: 1.9
    }

    // Full-card drag surface (Ryoku host owns placement; this only lets the
    // host's DragHandler take over on empty areas of the card).
    MouseArea {
        z: -1
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        hoverEnabled: false
        onPressed: (mouse) => { mouse.accepted = false }
    }

    // WeatherSource
    WeatherSource {
        id: wx
        settings: win.settings
        polling: win.working
    }

    Connections {
        target: wx
        function onLastFetchMsChanged() {
            win.landed()
        }
    }

    function refresh(): void {
        wx.refresh()
    }

    readonly property bool minimal: service ? service.minimal : false
    readonly property bool hasData: wx.temperatureText !== ""
    readonly property bool hourlyView: (settings && settings.get("weather.view") === "hourly")
        && win.hasData && wx.hourly.length > 0
    readonly property bool canSwitch: win.hasData && wx.hourly.length > 0
    readonly property bool night: wx.iconName.indexOf("night") >= 0

    readonly property color iconInk: mt.classic ? mt.colBorder
        : (mt.dark ? mt.accentMint : Qt.darker(mt.accentMint, 1.5))

    readonly property var temp: WM.splitTemp(win.hasData ? wx.temperatureText : "")
    readonly property var today: win.hasData && wx.forecast.length > 0 ? wx.forecast[0] : null

    readonly property var span: {
        if (!win.hasData || wx.forecast.length === 0)
            return { lo: 0, hi: 1 }
        let lo = 1e9
        let hi = -1e9
        for (const d of wx.forecast) {
            lo = Math.min(lo, WM.firstNumber(d.low))
            hi = Math.max(hi, WM.firstNumber(d.high))
        }
        return { lo: lo, hi: Math.max(hi, lo + 1) }
    }

    readonly property var windP: WM.windParts(win.hasData ? wx.windText : "")
    readonly property var windArrow: WM.windArrow(win.hasData ? wx.windText : "")
    readonly property real windNum: WM.firstNumber(win.windP.speed)
    readonly property string windUnit: String(win.windP.speed).replace(/^[\d.\s-]+/, "")
    readonly property real uv: WM.firstNumber(win.hasData ? wx.uvText : "")

    property real wave: 1
    readonly property real waveMs: 760

    NumberAnimation {
        id: waveAnim
        target: win
        property: "wave"
        from: 0
        to: 1
        duration: win.waveMs
    }

    onHourlyViewChanged: waveAnim.restart()
    onMinimalChanged: waveAnim.restart()
    onHasDataChanged: waveAnim.restart()
    onLanded: waveAnim.restart()

    property int hoverHour: -1
    property int hoverDay: -1

    readonly property string readout: {
        if (!win.hasData)
            return ""
        if (win.hourlyView && win.hoverHour >= 0 && win.hoverHour < wx.hourly.length) {
            const h = wx.hourly[win.hoverHour]
            return h.label + "  \u00b7  " + h.condition + "  \u00b7  rain " + h.rain + "%"
        }
        return ""
    }

    signal landed()

    property var wave2: 1


            Item {
                id: card
                property var theme: win.theme

                // Gliding to a preset's spot (win.glideOn, see `follow`). Off the rest of the time,
                // so dragging and placing are exact.
                Behavior on x {
                    enabled: win.glideOn
                    NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                }
                Behavior on y {
                    enabled: win.glideOn
                    NumberAnimation { duration: 520; easing.type: Easing.OutBack; easing.overshoot: 0.9 }
                }

                // Keeps the classic (white) look in the first dark mode; see Theme.classicFor.
                readonly property bool classicPanel: true

                // The same footprint as the clock's KEYS card: its content is
                // 286 x 238, and the housing adds the inset on every side plus
                // the hard shadow underneath.
                readonly property int contentW: 286
                readonly property int contentH: 238
                readonly property int inset: mt.borderWidth + mt.outerRingWidth + 10

                width: card.contentW + card.inset * 2
                height: card.contentH + card.inset * 2 + mt.shadowOffset

                scale: Math.max(0, win.reveal) * (win.placed ? 1 : 0) * (0.7 + 0.3 * Math.max(0, win.swapK))
                opacity: Math.max(0, Math.min(1, win.swapK))
                transformOrigin: Item.Center

                // A new size (a different scale, a different monitor) keeps the
                // card on screen; not while it is being dragged, then the drag
                // owns the position.


                // The housing: the same navy outline / pale ring / surface fill /
                // hard shadow as the bar, the dock, the To-Do card and the clock.
                Pill {
                    theme: win.theme
                    anchors.fill: parent
                    cornerRadius: mt.radiusOuter
                    ringWidth: mt.borderWidth + mt.outerRingWidth
                    ringColorTop: mt.pSurfaceRing
                    ringColorBottom: ringColorTop
                    fillColor: mt.pSurface
                }

                // Edit Desktop: outline, corner diamonds, a tag and a drag


                // Edit Desktop: flip between the classic and the minimal style (only while the
                // card is selected). The key shows the look it will switch TO.
                SizeKey {
                    theme: win.theme
                    shown: true
                    icon: win.minimal ? "dashboard" : "crop_square"
                    label: "STYLE  " + (win.minimal ? "MINIMAL" : "CLASSIC")
                    onToggled: { if (service) service.toggleStyle() }
                }

                // ===== the content =====
                Item {
                    id: content
                    z: 2
                    x: card.inset
                    y: card.inset
                    width: card.contentW
                    height: card.contentH

                    // ===== the two looks =====
                    // Only the one in use is built (the other is not even created), so the minimal
                    // card is also the lighter one. Style: service.style.
                    Loader {
                        active: !win.minimal
                        sourceComponent: classicFace
                    }

                    Loader {
                        active: win.minimal
                        sourceComponent: minimalFace
                    }

                    // ===== the classic style =====
                    Component {
                        id: classicFace

                        Item {
                            width: card.contentW
                            height: card.contentH

                            // ===== the plate, and the place hanging off it =====
                            Item {
                                id: head
                                width: card.contentW
                                height: 100

                                SekaiPlate {
                    theme: win.theme
                                    id: plate
                                    width: head.width
                                    height: 88

                                    // The conditions: the details of the note or row you point at.
                                    TileLabel {
                                        x: 14
                                        y: 9
                                        width: 188
                                        text: win.readout !== "" ? win.readout : condLabel.toUpperCase()
                                        color: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.82)
                                        font.pixelSize: 10
                                        font.letterSpacing: win.readout !== "" ? 0.3 : 1.3

                                        readonly property string condLabel: win.hasData ? wx.conditionText
                                            : (wx.loading ? "Loading\u2026"
                                               : (wx.failed ? wx.problemText : "No weather data"))
                                    }

                                    StickerText {
                    theme: win.theme
                                        id: tempNum
                                        x: 6
                                        y: 13
                                        text: win.hasData ? win.temp.num : "--"
                                        pixelSize: 42
                                        fillColor: plate.numberFill
                                        ringColor: plate.numberRing
                                    }

                                    StickerText {
                    theme: win.theme
                                        id: tempUnit
                                        x: tempNum.x + tempNum.width - 6
                                        y: 19
                                        text: win.hasData ? win.temp.unit : ""
                                        pixelSize: 17
                                        fillColor: plate.numberFill
                                        ringColor: plate.numberRing
                                    }

                                    // Today's high and low, stacked beside the number.
                                    Column {
                                        visible: win.today !== null
                                        x: tempUnit.x + tempUnit.width + 2
                                        y: 42
                                        spacing: 0

                                        Row {
                                            spacing: 0
                                            MaterialIcon {
                    theme: win.theme; anchors.verticalCenter: parent.verticalCenter; name: "arrow_upward"; size: 13; weight: 700; color: mt.colBorder; fill: 0 }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: win.today ? win.today.high : ""
                                                color: mt.colBorder
                                                font.family: mt.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.ExtraBold
                                                font.styleName: mt.fontStyleBold
                                            }
                                        }
                                        Row {
                                            spacing: 0
                                            MaterialIcon {
                    theme: win.theme; anchors.verticalCenter: parent.verticalCenter; name: "arrow_downward"; size: 13; weight: 700; color: mt.colBorder; fill: 0 }
                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: win.today ? win.today.low : ""
                                                color: mt.colBorder
                                                opacity: 0.8
                                                font.family: mt.fontFamily
                                                font.pixelSize: 12
                                                font.weight: Font.ExtraBold
                                                font.styleName: mt.fontStyleBold
                                            }
                                        }
                                    }

                                    // The weather as a tilted dark disc: poke it.
                                    Pill {
                    theme: win.theme
                                        id: disc
                                        x: plate.width - width - 12
                                        y: 8
                                        width: 68
                                        height: 70
                                        cornerRadius: 34
                                        ringWidth: mt.borderWidth + mt.whiteLine
                                        shadowDy: 4
                                        rotation: 6
                                        transformOrigin: Item.Center
                                        pressed: discArea.pressed
                                        fillColor: mt.chipFill

                                        property real sx: 1
                                        property real sy: 1

                                        transform: Scale {
                                            origin.x: disc.width / 2
                                            origin.y: disc.height / 2
                                            xScale: disc.sx
                                            yScale: disc.sy
                                        }

                                        WeatherGlyph {
                    theme: win.theme
                                            anchors.centerIn: parent
                                            name: wx.iconName
                                            size: 42
                                            color: mt.dark ? (win.night ? mt.accentCyan : mt.accentMint) : mt.colBorder
                                            scale: 0.5 + 0.5 * Math.min(win.wave * 1.2, 1.15)
                                        }
                                    }

                                    SequentialAnimation {
                                        id: squish
                                        ParallelAnimation {
                                            NumberAnimation { target: disc; property: "sx"; to: 1.18; duration: 80; easing.type: Easing.OutQuad }
                                            NumberAnimation { target: disc; property: "sy"; to: 0.82; duration: 80; easing.type: Easing.OutQuad }
                                        }
                                        ParallelAnimation {
                                            NumberAnimation { target: disc; property: "sx"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
                                            NumberAnimation { target: disc; property: "sy"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
                                        }
                                    }

                                    MouseArea {
                                        id: discArea
                                        x: disc.x
                                        y: disc.y
                                        width: disc.width
                                        height: disc.height
                                        acceptedButtons: Qt.LeftButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            squish.restart()
                                            puff.fire()
                                        }
                                    }

                                    Burst {
                                        theme: win.theme
                                        id: puff
                                        x: disc.x + disc.width / 2
                                        y: disc.y + disc.height / 2
                                        radius: 58
                                        count: 8
                                    }
                                }

                                // The place, hanging off the plate's lower edge.
                                Text {
                                    id: placeProbe
                                    visible: false
                                    text: placeTab.label
                                    font.family: mt.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.ExtraBold
                                    font.styleName: mt.fontStyleBold
                                }

                                Slant {
                                    id: placeTab
                                    readonly property string label: win.hasData && wx.areaText !== "" ? wx.areaText : "Weather"
                                    x: 2
                                    y: 74
                                    width: Math.min(placeProbe.implicitWidth + 44 + height * skew, 204)
                                    height: 26
                                    skew: 0.2
                                    radius: 9
                                    color: mt.chipFill
                                    borderColor: mt.pLine
                                    borderWidth: 3
                                }

                                // Text goes NEXT to the Slant (a child would lean with it).
                                Row {
                                    x: placeTab.x + placeTab.lean / 2 + 10
                                    y: placeTab.y
                                    height: placeTab.height
                                    spacing: 4

                                    MaterialIcon {
                    theme: win.theme
                                        anchors.verticalCenter: parent.verticalCenter
                                        name: "location_on"
                                        fill: 0
                                        size: 15
                                        weight: 700
                                        color: mt.dark ? mt.accentMint : mt.colBorder
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: Math.max(0, placeTab.width - placeTab.lean - 36)
                                        elide: Text.ElideRight
                                        text: placeTab.label
                                        color: mt.chipInk
                                        font.family: mt.fontFamily
                                        font.pixelSize: 11
                                        font.weight: Font.ExtraBold
                                        font.styleName: mt.fontStyleBold
                                    }
                                }

                                // The view key: Hourly <-> Days (the popup's own setting).
                                Item {
                                    visible: win.canSwitch
                                    x: head.width - 34 - 6 - 34
                                    y: 71
                                    width: 34
                                    height: 31

                                    Pill {
                    theme: win.theme
                                        anchors.fill: parent
                                        shadowDy: 3
                                        cornerRadius: 11
                                        ringWidth: mt.borderWidth + mt.whiteLine
                                        fillColor: mt.chipFill
                                        pressed: viewArea.pressed

                                        MaterialIcon {
                    theme: win.theme
                                            anchors.centerIn: parent
                                            name: win.hourlyView ? "calendar_view_day" : "schedule"
                                            fill: 0
                                            size: 17
                                            weight: 600
                                            color: mt.chipInk
                                        }
                                    }

                                    MouseArea {
                                        id: viewArea
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: settings.set("weather.view", win.hourlyView ? "days" : "hourly")
                                    }
                                }

                                // The refresh key.
                                Item {
                                    x: head.width - 34
                                    y: 71
                                    width: 34
                                    height: 31

                                    Pill {
                    theme: win.theme
                                        anchors.fill: parent
                                        shadowDy: 3
                                        cornerRadius: 11
                                        ringWidth: mt.borderWidth + mt.whiteLine
                                        fillColor: mt.chipFill
                                        pressed: refreshArea.pressed

                                        MaterialIcon {
                    theme: win.theme
                                            id: refreshIcon
                                            anchors.centerIn: parent
                                            name: "refresh"
                                            fill: 0
                                            size: 18
                                            weight: 600
                                            color: mt.chipInk

                                            RotationAnimator on rotation {
                                                from: 0
                                                to: 360
                                                duration: 900
                                                loops: Animation.Infinite
                                                running: wx.loading
                                                onRunningChanged: {
                                                    if (!running)
                                                        refreshIcon.rotation = 0
                                                }
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: refreshArea
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: win.refresh()
                                    }
                                }
                            }

                            // ===== the gauges =====
                            Row {
                                id: gauges
                                y: 106
                                visible: win.hasData
                                spacing: 8

                                // -- humidity: a tank --
                                Item {
                                    id: humTile
                                    width: 76
                                    height: 54
                                    readonly property real t: WM.clamp01((win.wave * win.waveMs - 0) / 300)
                                    readonly property real value: WM.firstNumber(win.hasData ? wx.humidityText : "")

                                    Item {
                                        anchors.fill: parent
                                        scale: (0.55 + 0.45 * WM.outBack(humTile.t, 2.2)) * (humArea.containsMouse ? 1.05 : 1)
                                        opacity: Math.min(1, humTile.t * 2.5)
                                        rotation: humArea.containsMouse ? 0 : -1.6
                                        transformOrigin: Item.Center
                                        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                                        Pill {
                    theme: win.theme
                                            anchors.fill: parent
                                            shadowDy: 4
                                            cornerRadius: 13
                                            ringWidth: 3
                                            fillColor: mt.pSurfaceHover

                                            Water {
                                                level: humTile.value / 100 * WM.outBack(humTile.t, 1.4)
                                                corner: 10
                                            }
                                            TileLabel { x: 8; y: 5; width: parent.width - 10; text: "HUMIDITY" }
                                            Text {
                                                x: 8
                                                y: 15
                                                width: parent.width - 12
                                                elide: Text.ElideRight
                                                text: win.hasData ? wx.humidityText : ""
                                                color: mt.pInk
                                                font.family: mt.fontFamily
                                                font.pixelSize: 19
                                                font.weight: Font.ExtraBold
                                                font.styleName: mt.fontStyleBold
                                            }
                                        }
                                    }
                                    MouseArea { id: humArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                }

                                // -- wind: a dial --
                                Item {
                                    id: windTile
                                    width: 120
                                    height: 54
                                    readonly property real t: WM.clamp01((win.wave * win.waveMs - 55) / 300)

                                    Item {
                                        anchors.fill: parent
                                        scale: (0.55 + 0.45 * WM.outBack(windTile.t, 2.2)) * (windArea.containsMouse ? 1.05 : 1)
                                        opacity: Math.min(1, windTile.t * 2.5)
                                        rotation: windArea.containsMouse ? 0 : 1.2
                                        transformOrigin: Item.Center
                                        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                                        Pill {
                    theme: win.theme
                                            anchors.fill: parent
                                            shadowDy: 4
                                            cornerRadius: 13
                                            ringWidth: 3
                                            fillColor: mt.pSurfaceHover

                                            TileLabel {
                                                x: 8
                                                y: 5
                                                width: parent.width - 14
                                                text: "WIND" + (win.windP.dir !== "" ? "  \u00b7  " + win.windP.dir : "")
                                            }

                                            Row {
                                                x: 8
                                                y: 15
                                                spacing: 3
                                                Text {
                                                    id: windBig
                                                    text: win.hasData ? String(win.windNum) : ""
                                                    color: mt.pInk
                                                    font.family: mt.fontFamily
                                                    font.pixelSize: 19
                                                    font.weight: Font.ExtraBold
                                                    font.styleName: mt.fontStyleBold
                                                }
                                                Text {
                                                    anchors.baseline: windBig.baseline
                                                    text: win.windUnit
                                                    color: mt.pInkSub
                                                    font.family: mt.fontFamily
                                                    font.pixelSize: 9
                                                    font.weight: Font.Bold
                                                }
                                            }

                                            // The dial: a ring with the arrow turning inside it, and a
                                            // diamond at north.
                                            Item {
                                                x: parent.width - width - 8
                                                y: 7
                                                width: 30
                                                height: 30

                                                Rectangle {
                                                    anchors.fill: parent
                                                    radius: width / 2
                                                    color: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.35)
                                                    border.width: 2
                                                    border.color: mt.pLine
                                                    antialiasing: true
                                                }
                                                DiamondDot {
                    theme: win.theme
                                                    x: (parent.width - width) / 2
                                                    y: -3
                                                    size: 6
                                                    lit: true
                                                    litColor: mt.accentMint
                                                    lineColor: mt.pLine
                                                }
                                                MaterialIcon {
                    theme: win.theme
                                                    anchors.centerIn: parent
                                                    name: win.windArrow !== null ? "arrow_upward" : "air"
                                                    fill: 0
                                                    size: 18
                                                    weight: 700
                                                    color: win.iconInk
                                                    rotation: win.windArrow !== null ? win.windArrow * WM.outBack(windTile.t, 2.4) : 0
                                                }
                                            }
                                        }
                                    }
                                    MouseArea { id: windArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                }

                                // -- UV: a meter --
                                Item {
                                    id: uvTile
                                    width: 74
                                    height: 54
                                    readonly property real t: WM.clamp01((win.wave * win.waveMs - 110) / 300)

                                    Item {
                                        anchors.fill: parent
                                        scale: (0.55 + 0.45 * WM.outBack(uvTile.t, 2.2)) * (uvArea.containsMouse ? 1.05 : 1)
                                        opacity: Math.min(1, uvTile.t * 2.5)
                                        rotation: uvArea.containsMouse ? 0 : -1.2
                                        transformOrigin: Item.Center
                                        Behavior on rotation { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                                        Pill {
                    theme: win.theme
                                            anchors.fill: parent
                                            shadowDy: 4
                                            cornerRadius: 13
                                            ringWidth: 3
                                            fillColor: mt.pSurfaceHover

                                            TileLabel { x: 8; y: 5; width: parent.width - 12; text: "UV INDEX" }
                                            Text {
                                                x: 8
                                                y: 13
                                                text: win.hasData ? wx.uvText : ""
                                                color: mt.pInk
                                                font.family: mt.fontFamily
                                                font.pixelSize: 19
                                                font.weight: Font.ExtraBold
                                                font.styleName: mt.fontStyleBold
                                            }
                                            Row {
                                                x: 9
                                                y: 34
                                                spacing: 5
                                                Repeater {
                                                    model: 5
                                                    delegate: DiamondDot {
                    theme: win.theme
                                                        required property int index
                                                        size: 6
                                                        offColor: Qt.rgba(mt.pInk.r, mt.pInk.g, mt.pInk.b, 0.2)
                                                        lit: index < WM.uvLit(win.uv)
                                                        litColor: index < 2 ? mt.accentMint : (index < 4 ? "#FFE066" : "#ff6f78")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    MouseArea { id: uvArea; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                                }
                            }

                            // ===== the forecast: hourly, a melody =====
                            Item {
                                id: hourly
                                y: 166
                                visible: win.hourlyView
                                width: card.contentW
                                height: 72

                                readonly property var readings: win.hasData ? wx.hourly : []
                                readonly property int n: hourly.readings.length
                                readonly property var pts: WM.curvePoints(hourly.readings.map(h => WM.firstNumber(h.temp)),
                                                                          20, card.contentW - 40, 40, 52)

                                // The lane the notes run along.
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 13
                                    color: mt.classic ? mt.pSurfaceHover : Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.28)
                                    border.width: 2
                                    border.color: mt.pLine
                                    antialiasing: true
                                }

                                // The curve through the notes: a navy line under a light one, like a sticker's edge.
                                Canvas {
                                    id: curve
                                    anchors.fill: parent
                                    opacity: Math.min(1, win.wave * 2)
                                    property color edge: mt.pLine
                                    property color core: mt.classic ? Qt.darker(mt.accentCyan, 1.25) : win.iconInk
                                    property var pts: hourly.pts
                                    onEdgeChanged: requestPaint()
                                    onCoreChanged: requestPaint()
                                    onPtsChanged: requestPaint()
                                    onWidthChanged: requestPaint()
                                    onHeightChanged: requestPaint()

                                    onPaint: {
                                        const ctx = getContext("2d")
                                        ctx.reset()
                                        const p = curve.pts
                                        if (!p || p.length < 2)
                                            return
                                        function trace() {
                                            ctx.beginPath()
                                            ctx.moveTo(p[0].x, p[0].y)
                                            for (let i = 1; i < p.length; i++) {
                                                const mx = (p[i - 1].x + p[i].x) / 2
                                                ctx.bezierCurveTo(mx, p[i - 1].y, mx, p[i].y, p[i].x, p[i].y)
                                            }
                                        }
                                        ctx.lineJoin = "round"
                                        ctx.lineCap = "round"
                                        trace()
                                        ctx.lineWidth = 6
                                        ctx.strokeStyle = curve.edge
                                        ctx.stroke()
                                        trace()
                                        ctx.lineWidth = 2.5
                                        ctx.strokeStyle = curve.core
                                        ctx.stroke()
                                    }
                                }

                                Repeater {
                                    model: hourly.readings

                                    delegate: Item {
                                        id: note
                                        required property var modelData
                                        required property int index

                                        readonly property var pt: hourly.pts[note.index] || { x: 0, y: 46 }
                                        readonly property bool hovered: noteArea.containsMouse
                                        readonly property real t: WM.clamp01((win.wave * win.waveMs - note.index * 60) / 300)
                                        readonly property real pop: WM.outBack(note.t, 2.2)
                                        readonly property real colW: hourly.n > 1 ? Math.min(36, (card.contentW - 40) / (hourly.n - 1)) : 36

                                        x: note.pt.x - note.colW / 2
                                        width: note.colW
                                        height: hourly.height

                                        // The column under the pointer.
                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 3
                                            radius: 10
                                            color: mt.pSurfaceHover
                                            opacity: note.hovered ? 1 : 0
                                            Behavior on opacity {
                                                NumberAnimation { duration: 120 }
                                            }
                                        }

                                        WeatherGlyph {
                    theme: win.theme
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 3
                                            name: note.modelData.iconName
                                            size: 17
                                            color: win.iconInk
                                            scale: 0.4 + 0.6 * note.pop
                                            opacity: Math.min(1, note.t * 2.5)
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: note.pt.y - 19
                                            text: note.modelData.temp
                                            color: mt.pInk
                                            font.family: mt.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                            opacity: Math.min(1, note.t * 2.5)
                                        }

                                        // The note itself: a diamond on the curve. The first is "now".
                                        Item {
                                            x: (parent.width - width) / 2
                                            y: note.pt.y - 6
                                            width: 12
                                            height: 12
                                            scale: (note.hovered ? 1.45 : (note.index === 0 ? 1.2 : 1)) * (0.3 + 0.7 * note.pop)
                                            Behavior on scale {
                                                NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2.6 }
                                            }

                                            DiamondDot {
                    theme: win.theme
                                                anchors.centerIn: parent
                                                size: 10
                                                lit: true
                                                litColor: note.index === 0 ? mt.accentMint : mt.pSurface
                                                lineColor: mt.pLine
                                            }
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 59
                                            text: note.modelData.label
                                            color: mt.pInkSub
                                            font.family: mt.fontFamily
                                            font.pixelSize: 10
                                            font.weight: Font.DemiBold
                                        }

                                        MouseArea {
                                            id: noteArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            onEntered: win.hoverHour = note.index
                                            onExited: {
                                                if (win.hoverHour === note.index)
                                                    win.hoverHour = -1
                                            }
                                        }
                                    }
                                }
                            }

                            // ===== the forecast: days, a song list =====
                            Column {
                                id: days
                                y: 166
                                visible: win.hasData && !win.hourlyView && wx.forecast.length > 0
                                width: card.contentW
                                spacing: 3

                                Repeater {
                                    model: win.hasData ? wx.forecast : []

                                    delegate: Item {
                                        id: dayRow
                                        required property var modelData
                                        required property int index
                                        width: card.contentW
                                        height: 22

                                        readonly property bool hovered: rowArea.containsMouse
                                        readonly property bool isToday: dayRow.index === 0
                                        readonly property real t: WM.clamp01((win.wave * win.waveMs - dayRow.index * 90) / 320)
                                        readonly property real lo: WM.firstNumber(dayRow.modelData.low)
                                        readonly property real hi: WM.firstNumber(dayRow.modelData.high)

                                        Item {
                                            anchors.fill: parent
                                            opacity: Math.min(1, dayRow.t * 2.5)
                                            x: (1 - WM.outBack(dayRow.t, 1.6)) * 26
                                            scale: dayRow.hovered ? 1.015 : 1
                                            Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                                            Rectangle {
                                                anchors.fill: parent
                                                radius: 11
                                                color: mt.pSurfaceHover
                                                border.width: 2
                                                border.color: dayRow.hovered ? mt.accentMint : mt.pLine
                                                antialiasing: true
                                                Behavior on border.color { ColorAnimation { duration: 120 } }

                                                // The chance of rain, filling the row from the left.
                                                Rectangle {
                                                    x: 2
                                                    y: 2
                                                    height: parent.height - 4
                                                    width: Math.max(0, (parent.width - 4) * Math.min(1, dayRow.modelData.rain / 100) * WM.outBack(dayRow.t, 1.4))
                                                    radius: 9
                                                    color: Qt.rgba(mt.accentCyan.r, mt.accentCyan.g, mt.accentCyan.b, 0.2)
                                                }
                                            }

                                            // The day, on a slanted tab (today's is the gradient one).
                                            Slant {
                                                x: 5
                                                y: 3
                                                width: 56
                                                height: 16
                                                skew: 0.2
                                                radius: 6
                                                color: dayRow.isToday ? "transparent" : mt.chipFill
                                                gradient: dayRow.isToday ? accentGradient : null
                                                borderColor: mt.pLine
                                                borderWidth: 2
                                            }
                                            Text {
                                                x: 5
                                                y: 3
                                                width: 56
                                                height: 16
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                                elide: Text.ElideRight
                                                text: dayRow.modelData.label + (!dayRow.isToday && dayRow.modelData.date ? " " + dayRow.modelData.date : "")
                                                color: dayRow.isToday ? mt.colBorder : mt.chipInk
                                                font.family: mt.fontFamily
                                                font.pixelSize: 10
                                                font.weight: Font.ExtraBold
                                                font.styleName: mt.fontStyleBold
                                            }

                                            WeatherGlyph {
                    theme: win.theme
                                                x: 66
                                                anchors.verticalCenter: parent.verticalCenter
                                                name: dayRow.modelData.iconName
                                                size: 18
                                                color: win.iconInk
                                            }

                                            Row {
                                                x: 92
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 4
                                                Text {
                                                    text: dayRow.modelData.high
                                                    color: mt.pInk
                                                    font.family: mt.fontFamily
                                                    font.pixelSize: 13
                                                    font.weight: Font.ExtraBold
                                                    font.styleName: mt.fontStyleBold
                                                }
                                                Text {
                                                    anchors.baseline: parent.children[0].baseline
                                                    text: dayRow.modelData.low
                                                    color: mt.pInkSub
                                                    font.family: mt.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.DemiBold
                                                }
                                            }

                                            // High and low on the days' shared scale.
                                            Rectangle {
                                                id: track
                                                x: 148
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 70
                                                height: 5
                                                radius: 2.5
                                                color: Qt.rgba(mt.pInk.r, mt.pInk.g, mt.pInk.b, 0.16)

                                                Rectangle {
                                                    x: (dayRow.lo - win.span.lo) / (win.span.hi - win.span.lo) * (track.width - width)
                                                    width: Math.max(14, (dayRow.hi - dayRow.lo) / (win.span.hi - win.span.lo) * track.width)
                                                    height: parent.height
                                                    radius: 2.5
                                                    gradient: accentGradient
                                                }
                                            }

                                            Row {
                                                anchors.right: parent.right
                                                anchors.rightMargin: 10
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 1
                                                MaterialIcon {
                    theme: win.theme
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    name: "water_drop"
                                                    fill: 0
                                                    size: 12
                                                    weight: 700
                                                    color: mt.pInk
                                                }
                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: dayRow.modelData.rain + "%"
                                                    color: mt.pInk
                                                    font.family: mt.fontFamily
                                                    font.pixelSize: 10
                                                    font.weight: Font.ExtraBold
                                                    font.styleName: mt.fontStyleBold
                                                }
                                            }
                                        }

                                        MouseArea {
                                            id: rowArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                            onEntered: win.hoverDay = dayRow.index
                                            onExited: {
                                                if (win.hoverDay === dayRow.index)
                                                    win.hoverDay = -1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    // ===== the minimal look =====
                    // The same card, the same 2 x 2 footprint and the same parts (plate, disc,
                    // place tab, refresh key, lane) with far less on it: the temperature, the
                    // weather, today's high and low, and the next four readings in one lane.
                    Component {
                        id: minimalFace

                        Item {
                            id: mini
                            width: card.contentW
                            height: card.contentH

                            // The plate's height (its face plus the hard shadow); the place
                            // tab and the refresh key hang off its lower edge, 14 px up.
                            readonly property real plateH: 128
                            readonly property real hangY: mini.plateH - 14
                            readonly property real laneY: 150
                            readonly property real laneH: card.contentH - mini.laneY
                            readonly property int cols: 4
                            // Big numbers fill the plate; three characters ("100", "-12") drop a size so
                            // they never run into the disc.
                            readonly property int numSize: String(win.hasData ? win.temp.num : "--").length > 2 ? 60 : 76
                            readonly property var reads: win.hasData ? wx.hourly.slice(0, mini.cols) : []

                            SekaiPlate {
                    theme: win.theme
                                id: mplate
                                width: mini.width
                                height: mini.plateH

                                // The conditions.
                                TileLabel {
                                    x: 14
                                    y: 9
                                    width: 176
                                    text: condLabel.toUpperCase()
                                    color: Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.82)
                                    font.pixelSize: 10
                                    font.letterSpacing: 1.3

                                    readonly property string condLabel: win.hasData ? wx.conditionText
                                        : (wx.loading ? "Loading\u2026"
                                           : (wx.failed ? wx.problemText : "No weather data"))
                                }

                                // The temperature, big.
                                StickerText {
                    theme: win.theme
                                    id: mNum
                                    x: 8
                                    y: 15
                                    text: win.hasData ? win.temp.num : "--"
                                    pixelSize: mini.numSize
                                    fillColor: mplate.numberFill
                                    ringColor: mplate.numberRing
                                }

                                StickerText {
                    theme: win.theme
                                    x: mNum.x + mNum.width - 6
                                    y: 27
                                    text: win.hasData ? win.temp.unit : ""
                                    pixelSize: 28
                                    fillColor: mplate.numberFill
                                    ringColor: mplate.numberRing
                                }

                                // The weather as a tilted dark disc: poke it.
                                Pill {
                    theme: win.theme
                                    id: mdisc
                                    x: mplate.width - width - 12
                                    y: 8
                                    width: 76
                                    height: 78
                                    cornerRadius: 38
                                    ringWidth: mt.borderWidth + mt.whiteLine
                                    shadowDy: 4
                                    rotation: 6
                                    transformOrigin: Item.Center
                                    pressed: mdiscArea.pressed
                                    fillColor: mt.chipFill

                                    property real sx: 1
                                    property real sy: 1

                                    transform: Scale {
                                        origin.x: mdisc.width / 2
                                        origin.y: mdisc.height / 2
                                        xScale: mdisc.sx
                                        yScale: mdisc.sy
                                    }

                                    WeatherGlyph {
                    theme: win.theme
                                        anchors.centerIn: parent
                                        name: wx.iconName
                                        size: 50
                                        color: mt.dark ? (win.night ? mt.accentCyan : mt.accentMint) : mt.colBorder
                                        scale: 0.5 + 0.5 * Math.min(win.wave * 1.2, 1.15)
                                    }
                                }

                                SequentialAnimation {
                                    id: msquish
                                    ParallelAnimation {
                                        NumberAnimation { target: mdisc; property: "sx"; to: 1.18; duration: 80; easing.type: Easing.OutQuad }
                                        NumberAnimation { target: mdisc; property: "sy"; to: 0.82; duration: 80; easing.type: Easing.OutQuad }
                                    }
                                    ParallelAnimation {
                                        NumberAnimation { target: mdisc; property: "sx"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
                                        NumberAnimation { target: mdisc; property: "sy"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 3 }
                                    }
                                }

                                MouseArea {
                                    id: mdiscArea
                                    x: mdisc.x
                                    y: mdisc.y
                                    width: mdisc.width
                                    height: mdisc.height
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        msquish.restart()
                                        mpuff.fire()
                                    }
                                }

                                Burst {
                                    theme: win.theme
                                    id: mpuff
                                    x: mdisc.x + mdisc.width / 2
                                    y: mdisc.y + mdisc.height / 2
                                    radius: 62
                                    count: 8
                                }

                                // Today's high and low, side by side under the disc.
                                Row {
                                    visible: win.today !== null
                                    x: mdisc.x + (mdisc.width - width) / 2
                                    y: 92
                                    spacing: 9

                                    Row {
                                        spacing: 0
                                        MaterialIcon {
                    theme: win.theme; anchors.verticalCenter: parent.verticalCenter; name: "arrow_upward"; size: 14; weight: 700; color: mt.colBorder; fill: 0 }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: win.today ? win.today.high : ""
                                            color: mt.colBorder
                                            font.family: mt.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                        }
                                    }
                                    Row {
                                        spacing: 0
                                        MaterialIcon {
                    theme: win.theme; anchors.verticalCenter: parent.verticalCenter; name: "arrow_downward"; size: 14; weight: 700; color: mt.colBorder; fill: 0 }
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: win.today ? win.today.low : ""
                                            color: mt.colBorder
                                            opacity: 0.8
                                            font.family: mt.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                        }
                                    }
                                }
                            }

                            // The place, hanging off the plate's lower edge.
                            Text {
                                id: mplaceProbe
                                visible: false
                                text: mplaceTab.label
                                font.family: mt.fontFamily
                                font.pixelSize: 11
                                font.weight: Font.ExtraBold
                                font.styleName: mt.fontStyleBold
                            }

                            Slant {
                                id: mplaceTab
                                readonly property string label: win.hasData && wx.areaText !== "" ? wx.areaText : "Weather"
                                x: 2
                                y: mini.hangY
                                width: Math.min(mplaceProbe.implicitWidth + 44 + height * skew, 204)
                                height: 26
                                skew: 0.2
                                radius: 9
                                color: mt.chipFill
                                borderColor: mt.pLine
                                borderWidth: 3
                            }

                            // Text goes NEXT to the Slant (a child would lean with it).
                            Row {
                                x: mplaceTab.x + mplaceTab.lean / 2 + 10
                                y: mplaceTab.y
                                height: mplaceTab.height
                                spacing: 4

                                MaterialIcon {
                    theme: win.theme
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: "location_on"
                                    fill: 0
                                    size: 15
                                    weight: 700
                                    color: mt.dark ? mt.accentMint : mt.colBorder
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(0, mplaceTab.width - mplaceTab.lean - 36)
                                    elide: Text.ElideRight
                                    text: mplaceTab.label
                                    color: mt.chipInk
                                    font.family: mt.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.ExtraBold
                                    font.styleName: mt.fontStyleBold
                                }
                            }

                            // The refresh key (the only key: the look has no Hourly / Days switch).
                            Item {
                                x: mini.width - 34
                                y: mini.hangY - 3
                                width: 34
                                height: 31

                                Pill {
                    theme: win.theme
                                    anchors.fill: parent
                                    shadowDy: 3
                                    cornerRadius: 11
                                    ringWidth: mt.borderWidth + mt.whiteLine
                                    fillColor: mt.chipFill
                                    pressed: mrefreshArea.pressed

                                    MaterialIcon {
                    theme: win.theme
                                        id: mrefreshIcon
                                        anchors.centerIn: parent
                                        name: "refresh"
                                        fill: 0
                                        size: 18
                                        weight: 600
                                        color: mt.chipInk

                                        RotationAnimator on rotation {
                                            from: 0
                                            to: 360
                                            duration: 900
                                            loops: Animation.Infinite
                                            running: wx.loading
                                            onRunningChanged: {
                                                if (!running)
                                                    mrefreshIcon.rotation = 0
                                            }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: mrefreshArea
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: win.refresh()
                                }
                            }

                            // ===== the lane: the next four readings =====
                            Item {
                                id: lane
                                y: mini.laneY
                                width: mini.width
                                height: mini.laneH

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 13
                                    color: mt.classic ? mt.pSurfaceHover : Qt.rgba(mt.colBorder.r, mt.colBorder.g, mt.colBorder.b, 0.28)
                                    border.width: 2
                                    border.color: mt.pLine
                                    antialiasing: true
                                }

                                // Nothing to show yet.
                                Text {
                                    visible: !win.hasData
                                    anchors.centerIn: parent
                                    text: wx.loading ? "Fetching the forecast\u2026" : "Press refresh to try again"
                                    color: mt.pInkSub
                                    font.family: mt.fontFamily
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }

                                // The readings: a time, a glyph and a temperature each. The
                                // first is "now" and sits on a mint tab.
                                Repeater {
                                    model: mini.reads

                                    delegate: Item {
                                        id: col
                                        required property var modelData
                                        required property int index

                                        readonly property real colW: (lane.width - 8) / mini.cols
                                        readonly property bool hovered: colArea.containsMouse
                                        readonly property real t: WM.clamp01((win.wave * win.waveMs - col.index * 70) / 300)
                                        readonly property real pop: WM.outBack(col.t, 2.2)

                                        x: 4 + col.index * col.colW
                                        y: 4
                                        width: col.colW
                                        height: lane.height - 8

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.margins: 1
                                            radius: 10
                                            color: col.index === 0 ? Qt.rgba(mt.accentMint.r, mt.accentMint.g, mt.accentMint.b, 0.26)
                                                : mt.pSurfaceHover
                                            border.width: col.index === 0 ? 2 : 0
                                            border.color: mt.pLine
                                            opacity: col.index === 0 ? 1 : (col.hovered ? 1 : 0)
                                            antialiasing: true
                                            Behavior on opacity {
                                                NumberAnimation { duration: 120 }
                                            }
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 8
                                            text: col.modelData.label
                                            color: mt.pInkSub
                                            font.family: mt.fontFamily
                                            font.pixelSize: 11
                                            font.weight: Font.DemiBold
                                            opacity: Math.min(1, col.t * 2.5)
                                        }

                                        WeatherGlyph {
                    theme: win.theme
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 24
                                            name: col.modelData.iconName
                                            size: 28
                                            color: win.iconInk
                                            scale: 0.4 + 0.6 * col.pop
                                            opacity: Math.min(1, col.t * 2.5)
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 55
                                            text: col.modelData.temp
                                            color: mt.pInk
                                            font.family: mt.fontFamily
                                            font.pixelSize: 16
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                            opacity: Math.min(1, col.t * 2.5)
                                        }

                                        MouseArea {
                                            id: colArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                        }
                                    }
                                }

                                // A reading with no forecast behind it (the service sent none):
                                // the two gauges that are left, as plain figures.
                                Row {
                                    visible: win.hasData && mini.reads.length === 0
                                    anchors.centerIn: parent
                                    spacing: 40

                                    Column {
                                        spacing: 2
                                        TileLabel { text: "HUMIDITY" }
                                        Text {
                                            text: wx.humidityText
                                            color: mt.pInk
                                            font.family: mt.fontFamily
                                            font.pixelSize: 19
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                        }
                                    }
                                    Column {
                                        spacing: 2
                                        TileLabel { text: "WIND" }
                                        Text {
                                            text: win.windP.speed
                                            color: mt.pInk
                                            font.family: mt.fontFamily
                                            font.pixelSize: 19
                                            font.weight: Font.ExtraBold
                                            font.styleName: mt.fontStyleBold
                                        }
                                    }
                                }
                            }
                        }
                    }

                }
            }

}
