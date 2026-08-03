// Left island — workspaces.
//
// Only interesting workspaces are drawn: any with windows, the focused one,
// and workspace 1. Empty trailing workspaces do not take up space.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/"
import "root:/widgets"

IslandSurface {
    id: root

    implicitHeight: Config.bar.islandHeight
    implicitWidth: row.implicitWidth + Config.bar.islandPadding * 2

    Behavior on implicitWidth {
        NumberAnimation { duration: Config.expandMs; easing.type: Easing.OutQuint }
    }

    // Hyprland's workspace list includes special workspaces with negative ids;
    // the scratchpad is reached by keybind, not by clicking a dot.
    readonly property var shown: {
        const all = Hyprland.workspaces.values.filter(w => w && w.id > 0);
        const focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;

        const keep = all.filter(w => windowCount(w) > 0 || w.id === focusedId || w.id === 1);

        // A workspace you have switched to but not yet opened anything on is
        // not in Hyprland's list on some versions. Synthesise it so the dot
        // does not vanish under your cursor.
        if (!keep.some(w => w.id === focusedId))
            keep.push({ id: focusedId, urgent: false });

        return keep.sort((a, b) => a.id - b.id);
    }

    function windowCount(w) {
        // lastIpcObject is the raw payload from Hyprland's IPC. Guarded
        // because its shape is not part of any stability guarantee.
        return w && w.lastIpcObject && w.lastIpcObject.windows ? w.lastIpcObject.windows : 0;
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            // Scroll moves between the workspaces that actually exist, rather
            // than stepping into empty ones you would then have to scroll back
            // out of.
            const ids = root.shown.map(w => w.id);
            const cur = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
            let i = ids.indexOf(cur);
            if (i === -1) return;
            i += wheel.angleDelta.y < 0 ? 1 : -1;
            if (i < 0 || i >= ids.length) return;
            Hyprland.dispatch(`workspace ${ids[i]}`);
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 7

        Repeater {
            model: root.shown

            Rectangle {
                id: dot

                required property var modelData

                readonly property bool focused:
                    Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === modelData.id
                readonly property bool occupied: root.windowCount(modelData) > 0
                readonly property bool urgent: modelData.urgent === true

                // The focused workspace widens into a pill. Everything else is
                // a dot: filled when it has windows, hollow when it does not.
                width: focused ? 22 : 8
                height: 8
                radius: 4
                anchors.verticalCenter: parent.verticalCenter

                color: focused ? Theme.primary
                     : urgent ? Theme.error
                     : occupied ? Theme.onSurfaceVariant
                     : "transparent"

                border.width: (focused || urgent || occupied) ? 0 : 1.5
                border.color: Theme.outline

                opacity: occupied && !focused ? 0.75 : 1.0

                Behavior on width {
                    NumberAnimation { duration: Config.collapseMs; easing.type: Easing.OutQuint }
                }
                Behavior on color {
                    ColorAnimation { duration: Config.fadeMs }
                }

                // Urgent pulses until you look at it.
                SequentialAnimation on opacity {
                    running: dot.urgent && Config.motion.enabled
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 600; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0;  duration: 600; easing.type: Easing.InOutQuad }
                }

                MouseArea {
                    anchors.fill: parent
                    // The dot is 8px; the hit target should not be.
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(`workspace ${dot.modelData.id}`)
                }
            }
        }
    }
}
