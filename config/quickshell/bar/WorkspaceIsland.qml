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
    //
    // Everything Hyprland reports is shown. Hyprland only keeps a workspace
    // alive while it holds windows or is focused, so membership in this list
    // ALREADY means "interesting" — filtering it again by window count was the
    // bug that made workspace 3 invisible from workspace 1. See windowCount().
    readonly property var shown: {
        const keep = Hyprland.workspaces.values.filter(w => w && w.id > 0);
        const focusedId = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;

        // A workspace you have switched to but not yet opened anything on is
        // not in Hyprland's list on some versions. Synthesise it so the dot
        // does not vanish under your cursor.
        if (!keep.some(w => w.id === focusedId))
            keep.push({ id: focusedId, urgent: false });

        // Workspace 1 is always shown, so the island never renders empty.
        if (!keep.some(w => w.id === 1))
            keep.push({ id: 1, urgent: false });

        return keep.sort((a, b) => a.id - b.id);
    }

    // Reads the LIVE toplevel model, not lastIpcObject.
    //
    // lastIpcObject is a snapshot of `hyprctl workspaces` taken the last time
    // quickshell refreshed the workspace list — which happens on workspace
    // events, not on window events. Opening a window therefore did not update
    // the count, so a workspace you had just put a window on still read as
    // empty, and the display lagged a step behind reality: from workspace 1 you
    // saw 1 and 2, and only from 2 did 3 appear.
    //
    // toplevels is an ObjectModel that tracks windows as they open and close.
    // Anything that has to react to a window appearing must read it.
    function windowCount(w) {
        return w && w.toplevels ? w.toplevels.values.length : 0;
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
                     : occupied ? Theme.textOnSurfaceVariant
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
