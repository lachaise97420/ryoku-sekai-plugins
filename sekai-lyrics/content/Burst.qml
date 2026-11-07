import QtQuick

// SekaiPop's Burst.qml: a one-shot puff of diamonds flying out from this
// item's origin (0, 0) and fading. Put it where the burst should start and
// call fire(). Nothing runs between bursts.
Item {
    id: root

    property var theme
    property int count: 7
    property real radius: 40
    property real size: 9
    property var colors: root.theme ? root.theme.attributeColors : ["#04feee", "#00ffcb", "#ffffff"]
    // 0 = not started, 1 = finished; the diamonds are only drawn in between.
    property real t: 0

    function fire() {
        anim.restart()
    }

    NumberAnimation {
        id: anim
        target: root
        property: "t"
        from: 0
        to: 1
        duration: 600
        easing.type: Easing.OutCubic
    }

    Repeater {
        model: root.count

        delegate: DiamondDot {
            id: bit
            required property int index

            theme: root.theme
            readonly property real angle: bit.index * 2 * Math.PI / root.count - Math.PI / 2 + 0.35
            readonly property real reach: root.radius * (0.65 + 0.35 * ((bit.index * 7) % 5) / 4)

            lit: true
            size: root.size
            litColor: root.colors[bit.index % root.colors.length]
            x: Math.cos(bit.angle) * bit.reach * root.t - bit.width / 2
            y: Math.sin(bit.angle) * bit.reach * root.t - bit.height / 2
            opacity: (root.t <= 0 || root.t >= 1) ? 0 : 1 - root.t * root.t
        }
    }
}
