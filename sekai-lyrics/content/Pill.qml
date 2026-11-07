import QtQuick

// SekaiPop's Pill.qml, reduced to the paths the lyrics source picker uses
// (no capsule bar, no classic Quick Panel scope): a thick navy outline with a
// white ring gap between the outline and the fill, on a flat offset shadow.
Item {
    id: root

    property var theme
    property color fillColor: root.theme ? root.theme.surface : "#2a2938"
    property real cornerRadius: height / 2
    property real ringWidth: 8
    property real innerRing: 0
    property real borderWidth: root.theme ? root.theme.borderWidth : 3
    property real shadowDx: 0
    property real shadowDy: root.theme ? root.theme.shadowOffset : 4
    property color ringColorTop: root.theme ? root.theme.ringWhite : "#ffffff"
    property color ringColorBottom: root.theme ? root.theme.ringWhite : "#ffffff"

    readonly property real capWidth: width - shadowDx
    readonly property real capHeight: height - shadowDy
    default property alias content: fill.data

    // The fixed hard shadow, and the cap that covers it when pressed.
    Rectangle {
        x: root.shadowDx
        y: root.shadowDy
        width: root.capWidth
        height: root.capHeight
        radius: root.cornerRadius
        color: root.theme ? root.theme.lineShadow : "#3d3d52"
        antialiasing: true
    }

    Item {
        id: surface
        x: 0
        y: 0
        width: root.capWidth
        height: root.capHeight

        Rectangle {
            id: face
            anchors.fill: parent
            radius: root.cornerRadius
            border.width: root.borderWidth
            border.color: root.theme ? root.theme.line : "#555473"
            antialiasing: true

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.ringColorTop }
                GradientStop { position: 1.0; color: root.ringColorBottom }
            }
        }

        Rectangle {
            id: fill
            anchors.fill: face
            anchors.margins: root.ringWidth
            radius: Math.max(0, root.cornerRadius - root.ringWidth)
            color: root.fillColor
            antialiasing: true

            Behavior on color {
                ColorAnimation { duration: 150 }
            }
        }

        // Above the fill and everything declared inside the Pill.
        Rectangle {
            anchors.fill: fill
            radius: fill.radius
            color: "transparent"
            border.width: root.innerRing
            border.color: root.ringColorTop
            visible: root.innerRing > 0
            antialiasing: true
        }
    }
}
