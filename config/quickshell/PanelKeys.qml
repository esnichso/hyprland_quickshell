// Escape closes whatever panel is open.
//
// The problem this solves: the notch, and every panel that draws inside the
// bar, lives on a layer surface with no keyboard focus. Key events never reach
// it, so there is nothing for a `Keys.onEscapePressed` to hang off — the
// dashboard could only be closed by clicking it again or pressing its bind.
//
// The fix is a surface whose ONLY job is to hold the keyboard while a panel is
// open. It is one pixel, fully transparent, has an empty input region so it
// takes no clicks, and does not exist at all when no panel is open. Layer-shell
// keyboard interactivity is independent of the input region, so a surface can
// grab keys without intercepting a single pointer event.
//
// Why not put this on the Bar: the bar is always visible, and a focus mode that
// is always on would take the keyboard away from the focused application
// permanently. Why not a full-screen shade: that would block clicks to the
// windows behind, and DESIGN.md §6 is explicit that these panels are glanceable
// rather than modal — you should still be able to read, and reach, what is
// behind them.
//
// The launcher is excluded because it holds its own exclusive focus and handles
// its own Escape. Two surfaces asking for exclusive keyboard focus at once is a
// race with no defined winner.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/services"

PanelWindow {
    id: root

    screen: Panels.focusedScreen
    visible: Panels.anyOpen && !Panels.launcher

    // No anchors: this is not laid out against an edge, it just needs to exist.
    implicitWidth: 1
    implicitHeight: 1

    color: "transparent"

    // Explicit, per the rule that a default which happens to be right is still
    // a default nobody wrote down. A one-pixel window would reserve nothing
    // under Auto either, but Auto is not a decision.
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "hypersetup-panelkeys"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Empty region: the surface accepts no pointer input at all, so the pixel
    // it occupies is not a pixel you can lose a click to.
    mask: Region {}

    Item {
        id: catcher
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: event => {
            Panels.closeAll();
            event.accepted = true;
        }
    }

    // The compositor handing this surface the keyboard is only half of it —
    // something inside the window has to hold the focus too, or the key event
    // arrives and lands on nothing.
    onVisibleChanged: if (visible) catcher.forceActiveFocus()
}
