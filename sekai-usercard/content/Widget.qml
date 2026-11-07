pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.PluginKit
import Ryoku.PluginKit.Singletons

// SekaiPop's desktop user card, ported to Ryoku.
//
// The card is SekaiPop's own (UserCard.qml): white/navy sticker, banner,
// greeting chip, avatar, name, host, three stat keys, today lane, burst on
// click, hover tilt. The host owns placement, dragging and scaling, so the
// window/edit-mode/clone plumbing of UserCardWidget.qml is dropped.
//
// Customizing the picture (banner / avatar) is SekaiPop's PicturesRow and
// FramerCard, exposed from the card through a hover key, in a Popup because
// a Ryoku plugin cannot add a layer surface.
Item {
    id: root

    property var pluginApi
    property var screen
    property bool active: false
    property string density: "full"
    property real s: 1
    property real widthBudget: 0

    readonly property var service: pluginApi ? pluginApi.mainInstance : null

    SekaiTheme {
        id: sekaiTheme
    }

    implicitWidth: 320
    implicitHeight: 276

    UserCard {
        id: card
        theme: sekaiTheme
        service: root.service
        screen: root.screen
        onCustomizeRequested: pictures.openAt(card)
    }

    // ===== picture customization popup =====
    PicturesPopup {
        id: pictures
        theme: sekaiTheme
        service: root.service
        screen: root.screen
        anchorItem: card
    }

    // ===== framer popup =====
    FramerPopup {
        id: framer
        theme: sekaiTheme
        service: root.service
        screen: root.screen
    }
}
