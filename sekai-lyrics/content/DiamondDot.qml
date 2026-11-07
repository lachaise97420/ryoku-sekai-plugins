import QtQuick

// One diamond of the beat: SekaiPop's DiamondDot.qml, with the theme passed in
// instead of read from SekaiPop's Theme singleton.
Rectangle {
    id: root

    property var theme
    property bool lit: false
    property color litColor: root.theme ? root.theme.accentMint : "#00ffcb"
    property color offColor: root.theme ? root.theme.surfaceDivider : "#ffffff"
    property color lineColor: root.theme ? root.theme.line : "#555473"
    property real size: 12
    property real pop: 1

    width: root.size
    height: root.size
    radius: Math.max(2, root.size * 0.25)
    rotation: 45
    scale: root.pop
    color: root.lit ? root.litColor : root.offColor
    border.width: 2
    border.color: root.lineColor
    antialiasing: true

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    onLitChanged: {
        if (root.lit)
            root.bump()
    }

    function bump() {
        bumpAnim.restart()
    }

    NumberAnimation {
        id: bumpAnim
        target: root
        property: "pop"
        from: 1.7
        to: 1
        duration: 360
        easing.type: Easing.OutBack
        easing.overshoot: 2.2
    }
}
