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
import "root:/services"

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

    // Escape closes an open panel.
    //
    // The HyprlandFocusGrab in Notch.qml ALREADY routes the keyboard to this
    // window while the dashboard is open — that is why you cannot type into the
    // window behind it. The key events were arriving and being dropped: a QML
    // window delivers them to whichever item holds active focus, and nothing in
    // the bar had ever asked for it.
    //
    // So this is an Item inside the EXISTING window, not a surface of its own.
    // Two earlier attempts added a second focus-taking surface; both broke the
    // dashboard, because the grab dismisses on focus leaving its window list.
    // There is nothing to fight here — the grab's window and the window holding
    // the key handler are the same window.
    //
    // Zero-size on purpose. Key delivery does not depend on geometry, and an
    // item with no size cannot participate in stacking or swallow a click.
    Item {
        id: keys
        focus: true

        Keys.onEscapePressed: event => {
            // Not accepted when nothing is open, so Escape is never quietly
            // eaten in a state where the shell has no business with it.
            if (!Panels.anyOpen)
                return;
            Panels.closeAll();
            event.accepted = true;
        }
    }

    // Focus is taken when the panel opens rather than held permanently: the
    // grab is what makes the keyboard reachable at all, and it only exists
    // while the dashboard is up.
    Connections {
        target: Panels
        function onDashChanged() {
            if (Panels.dash)
                keys.forceActiveFocus();
        }
    }

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

    // Tray tooltip.
    //
    // Drawn HERE rather than inside StatusIsland, for the reason the comment on
    // implicitHeight above gives: this window is already tall enough for the
    // notch, so a tooltip below the island needs no new surface and no resize.
    // Inside the island it would be clipped by the rounded rect or would push
    // the surface taller, and a layer surface that changes size gets animated
    // by the compositor on top of whatever the shell is animating.
    //
    // It is outside the input mask, so it is drawn but not clickable — which is
    // exactly what a tooltip should be. Nothing here can swallow a click meant
    // for the window underneath.
    Rectangle {
        id: trayTip

        readonly property var entry: status.trayHovered
        readonly property string head:
            entry ? (entry.tooltipTitle && entry.tooltipTitle !== ""
                        ? entry.tooltipTitle : entry.title) : ""
        readonly property string body:
            entry && entry.tooltipDescription ? entry.tooltipDescription : ""

        anchors.right: status.right
        anchors.top: status.bottom
        anchors.topMargin: 8

        implicitWidth: Math.min(tipCol.implicitWidth + 20, 360)
        implicitHeight: tipCol.implicitHeight + 14
        radius: 10
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Qt.alpha(Theme.outline, 0.35)

        // Fade only. Nothing moves: a tooltip that slides draws the eye to the
        // motion rather than to the text it came to show.
        visible: opacity > 0
        opacity: head !== "" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Config.fadeMs } }

        Column {
            id: tipCol
            anchors.centerIn: parent
            spacing: 2

            Text {
                text: trayTip.head
                color: Theme.textOnSurface
                font.family: "Inter"; font.pixelSize: 12; font.weight: Font.Medium
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 340)
            }

            Text {
                visible: trayTip.body !== ""
                text: trayTip.body
                color: Theme.textOnSurfaceVariant
                font.family: "Inter"; font.pixelSize: 11
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 340)
            }
        }
    }
}
