// Escape closes whatever panel is open.
//
// The problem this solves: the notch, and every panel that draws inside the
// bar, lives on a layer surface with no keyboard focus. Key events never reach
// it, so there is nothing for a `Keys.onEscapePressed` to hang off — the
// dashboard could only be closed by clicking it again or pressing its bind.
//
// This is a surface whose ONLY job is to hold the keyboard while a panel is
// open. One pixel, fully transparent, with an empty input region so it takes no
// clicks at all. Layer-shell keyboard interactivity is independent of the input
// region, so a surface can grab keys without intercepting a single pointer
// event — the panels stay glanceable and clickable-through, which DESIGN.md §6
// asks for.
//
// TWO THINGS THIS MUST GET RIGHT, both learned by getting them wrong:
//
// 1. It must be in Notch.qml's HyprlandFocusGrab window list. That grab is what
//    closes the dashboard when you click away from it, and it fires on ANY
//    focus change to a surface outside its list. Taking the keyboard from
//    outside the list therefore closed the panel the instant it opened — the
//    dashboard flashed and vanished. It registers itself on Panels.keyWindow so
//    the grab can whitelist it.
//
// 2. It stays MAPPED at all times and toggles keyboardFocus instead of
//    visibility. If it mapped at the same moment the grab activated, the two
//    would race: the grab commits its surface list before this surface exists,
//    and the surface then takes focus from outside a list it should have been
//    in. Always-mapped is a pixel of overlay that accepts no input; the race is
//    worth more than the pixel.
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

    // No `screen`. Keyboard focus is per-seat, not per-output, so which monitor
    // this pixel sits on is meaningless — and binding it to the focused screen
    // would tear the surface down and rebuild it on every monitor change, which
    // is exactly the map/unmap race note 2 exists to avoid.

    // Always mapped — see note 2 above. What changes is whether it asks for the
    // keyboard, not whether it exists.
    visible: true

    readonly property bool grabbing: Panels.anyOpen && !Panels.launcher

    // No anchors: this is not laid out against an edge, it just needs to exist.
    implicitWidth: 1
    implicitHeight: 1

    color: "transparent"

    // Explicit, per the rule that a default which happens to be right is still
    // a default nobody wrote down.
    exclusionMode: ExclusionMode.Ignore

    // Deliberately NOT "hypersetup-panel": conf/rules.lua blurs that namespace
    // by prefix, and there is nothing here worth asking the GPU to blur.
    WlrLayershell.namespace: "hypersetup-keys"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: grabbing ? WlrKeyboardFocus.Exclusive
                                          : WlrKeyboardFocus.None

    // Empty region: the surface accepts no pointer input at all, so the pixel
    // it occupies is not a pixel you can lose a click to, and a click outside
    // an open panel still reaches the focus grab and dismisses it.
    mask: Region {}

    Component.onCompleted: Panels.keyWindow = root

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
    onGrabbingChanged: if (grabbing) catcher.forceActiveFocus()
}
