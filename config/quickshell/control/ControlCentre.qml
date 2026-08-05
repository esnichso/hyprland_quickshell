// The control centre — Network · Bluetooth · Audio · Display.
//
// Replaces nmtui, blueman and pavucontrol with one surface that reads the same
// palette as everything else.
//
// The window follows the LAUNCHER's pattern exactly — full-screen transparent
// overlay, exclusive keyboard focus, click outside to close — because that
// pattern is known to work. It deliberately does NOT use HyprlandFocusGrab: the
// notch uses a grab, and a grab plus a second focus-taking surface is what broke
// the dashboard twice. One mechanism per surface.
//
// Only the visible tab is `active`. Scanning for wifi and for bluetooth devices
// both cost power, and binding every PipeWire node costs work, so each tab
// starts and stops its own expense.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/"
import "root:/services"
import "root:/widgets"

PanelWindow {
    id: root

    screen: Panels.focusedScreen
    visible: Panels.control

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // An overlay must never reserve space. Explicit because a default that
    // happens to be right is still a default nobody wrote down.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    WlrLayershell.namespace: "hypersetup-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string tab: "network"

    readonly property var tabs: [
        { id: "network",   label: "Network" },
        { id: "bluetooth", label: "Bluetooth" },
        { id: "audio",     label: "Audio" },
        { id: "display",   label: "Display" }
    ]

    onVisibleChanged: {
        if (visible)
            keys.forceActiveFocus();
        else
            root.tab = "network";   // always reopens where you expect
    }

    // Declared BEFORE the box so it sits underneath it. A catch-all MouseArea
    // after its siblings stacks above them and swallows their clicks.
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.closeAll()
    }

    // The box lives INSIDE this. QML delivers a key to the item holding focus
    // and then bubbles it up the parent chain until something accepts it, so
    // the wifi password field gets Escape first (closing the editor) and the
    // panel gets it second — with no coordination between them.
    //
    // It fills the window but handles no pointer input, so clicks fall straight
    // through to the close-everything MouseArea declared above it.
    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: event => {
            Panels.closeAll();
            event.accepted = true;
        }

        IslandSurface {
            id: box
            island: false

            width: Config.control.width

            // Anchored under the right island, which is where the status items that
            // open it live: clicking network in the bar should not send your eye
            // across the screen.
            x: parent.width - width - Config.bar.sideMargin
            y: Config.bar.topMargin + Config.bar.islandHeight + 8

            // Driven by the tab's WANTED height, not by body.height — body
            // follows this animation, so reading it back here would be a loop.
            implicitHeight: header.height
                          + Math.min(body.wanted, Config.control.maxHeight)

            Behavior on implicitHeight {
                NumberAnimation { duration: Config.expandMs; easing.type: Easing.OutQuint }
            }

            // The box takes no input of its own, so without this a click on its
            // padding falls through to the close-everything handler underneath.
            MouseArea {
                anchors.fill: parent
            }

            // ---- tab bar ----
            Item {
                id: header
                width: parent.width
                height: 44

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: root.tabs

                        Rectangle {
                            required property var modelData

                            readonly property bool selected: root.tab === modelData.id

                            implicitWidth: tabLabel.implicitWidth + 20
                            height: 26
                            radius: 8

                            color: selected ? Qt.alpha(Theme.primary, 0.22)
                                 : tabMa.containsMouse ? Theme.hoverBg
                                 : "transparent"
                            Behavior on color { ColorAnimation { duration: Config.fadeMs } }

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                color: parent.selected ? Theme.primary : Theme.textOnSurfaceVariant
                                font.family: "Inter"
                                font.pixelSize: 12
                                font.weight: parent.selected ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tab = parent.modelData.id
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.2
                }
            }

            // ---- tab content ----
            Item {
                id: body
                anchors.top: header.bottom
                width: parent.width

                // Height follows the visible tab, capped. Each tab reports its own
                // implicitHeight, so a short tab is a short panel.
                readonly property real wanted: {
                    switch (root.tab) {
                    case "bluetooth": return btTab.implicitHeight;
                    case "audio":     return audioTab.implicitHeight;
                    case "display":   return displayTab.implicitHeight;
                    default:          return netTab.implicitHeight;
                    }
                }

                // Follows the ANIMATED box height rather than `wanted`, the same
                // way the launcher's list and the picker's body do. Binding it to
                // `wanted` snapped the body to the new tab's full size while the
                // box was still easing open, and the Flickable clips to the body
                // — so switching to a taller tab drew its text below the panel's
                // bottom edge, on the bare overlay, for the whole 260ms.
                height: Math.max(0, box.height - header.height)

                Flickable {
                    anchors.fill: parent
                    contentHeight: body.wanted
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    NetworkTab {
                        id: netTab
                        width: body.width
                        visible: root.tab === "network"
                        active: root.visible && visible
                    }

                    BluetoothTab {
                        id: btTab
                        width: body.width
                        visible: root.tab === "bluetooth"
                        active: root.visible && visible
                    }

                    AudioTab {
                        id: audioTab
                        width: body.width
                        visible: root.tab === "audio"
                        active: root.visible && visible
                    }

                    DisplayTab {
                        id: displayTab
                        width: body.width
                        visible: root.tab === "display"
                        active: root.visible && visible
                    }
                }
            }
        }
    }
}
