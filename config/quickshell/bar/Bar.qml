// The bar surface.
//
// A full-width transparent layer-shell window holding three islands. The window
// itself is invisible; the islands are the only thing drawn, and the `mask`
// makes everything between them click-through so the gaps behave like desktop
// rather than like an invisible wall.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/"

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    // Fixed forever. This must never animate — the notch overlays content when
    // it expands rather than pushing it, because reflowing every window on
    // every notification is intolerable (DESIGN.md §3).
    exclusiveZone: Config.bar.height

    color: "transparent"

    // Must match the layer rules in conf/rules.lua. Verify against
    // `hyprctl layers` in a running session; a mismatch here means blur
    // silently never applies, which is how v1 lost an afternoon.
    WlrLayershell.namespace: "hypersetup-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Only the three islands take clicks. Without this the transparent gaps
    // between them would swallow clicks meant for the window underneath.
    //
    // The notch's region grows with it, so an expanded dashboard is clickable
    // for its whole area without the bar ever becoming a full-width blocker.
    mask: Region {
        Region { item: workspaces }
        Region { item: notch }
        Region { item: status }
    }

    // The bar surface is only as tall as the bar, but the dashboard grows
    // beyond it. Without extending the window, the panel is clipped at 46px.
    implicitHeight: Math.max(Config.bar.height,
                             notch.y + notch.implicitHeight + Config.bar.topMargin)

    WorkspaceIsland {
        id: workspaces
        anchors.left: parent.left
        anchors.leftMargin: Config.bar.sideMargin
        anchors.top: parent.top
        anchors.topMargin: Config.bar.topMargin
        visible: Config.modules.workspaces
    }

    Notch {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Config.bar.topMargin
        hostWindow: root
    }

    StatusIsland {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: Config.bar.sideMargin
        anchors.top: parent.top
        anchors.topMargin: Config.bar.topMargin
    }
}
