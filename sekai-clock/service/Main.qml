pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.PluginKit.Singletons

Item {
    id: svc

    property var pluginApi
    property bool use24h: true

    function setUse24h(v: bool): void { svc.use24h = !!v; }

    onPluginApiChanged: {
        if (svc.pluginApi && svc.pluginApi.pluginSettings
            && svc.pluginApi.pluginSettings.use24h !== undefined
            && svc.pluginApi.pluginSettings.use24h !== null) {
            svc.use24h = (svc.pluginApi.pluginSettings.use24h === true);
        }
    }
}