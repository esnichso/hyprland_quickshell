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

    // Reserve exactly the bar height, forever, no matter how tall the surface
    // itself gets.
    //
    // exclusionMode MUST be set. It defaults to Auto, which derives the
    // exclusive zone from the window's size and anchors "if exactly 3 anchors
    // are connected" — which is exactly this window (top, left, right). Under
    // Auto the explicit exclusiveZone below is ignored, so the reserved space
    // tracked the animating window height and every window on screen reflowed
    // each time the notch opened or a notification cleared. That is the thing
    // DESIGN.md §3 says must never happen.
    exclusionMode: ExclusionMode.Normal
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

    // FIXED height, large enough for the tallest thing the notch can become.
    //
    // This must not track the notch. A layer surface that changes size makes
    // the compositor animate the resize (hl.animation leaf "layers"), which
    // lands on top of the notch's own animation and reads as the whole bar
    // bouncing every time a panel opens or a notification clears.
    //
    // The surface is transparent and the mask restricts input to the islands,
    // so a permanently tall window costs nothing: the area below the bar is
    // click-through, and the blur layer rule sets ignore_alpha so fully
    // transparent pixels are not blurred either.
    implicitHeight: Config.bar.topMargin + Config.notch.panelHeight + Config.bar.height

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
