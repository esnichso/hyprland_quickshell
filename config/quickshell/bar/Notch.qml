// Centre island — the notch.
//
// A state machine with animated geometry. Six states, one priority order, one
// object. Everything the shell wants to tell you arrives through here and
// leaves the same way.
//
// A new event RETARGETS the running animation from wherever it is; it never
// queues and never restarts. Every animated property uses a Behavior, which
// makes that free — anything hand-driving an animation here is a bug.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import "root:/"
import "root:/services"
import "root:/widgets"
import "root:/bar/notch"

IslandSurface {
    id: root

    // The window this notch lives in, so the focus grab has something to hold.
    property var hostWindow: null

    // Panel state is a singleton: the keybind IPC, this click handler and the
    // panels themselves all need to reach it.
    readonly property bool dashOpen: Panels.dash

    // ---- state resolution -------------------------------------------------
    readonly property string state_:
          dashOpen                                   ? "dash"
        : Notifs.popup !== null && Notifs.critical    ? "critical"
        : Osd.active                                  ? "osd"
        : Notifs.popup !== null                       ? "toast"
        : "rest"

    readonly property var geometry: ({
        rest:     { w: Config.notch.restWidth,  h: Config.bar.islandHeight,  r: Config.bar.radius },
        osd:      { w: Config.notch.osdWidth,   h: Config.bar.islandHeight,  r: Config.bar.radius },
        toast:    { w: Config.notch.toastWidth, h: Config.notch.toastHeight, r: 18 },
        critical: { w: Config.notch.toastWidth, h: Config.notch.toastHeight, r: 18 },
        dash:     { w: Config.notch.panelWidth, h: Config.notch.panelHeight, r: 20 }
    })

    readonly property var geo: geometry[state_]

    implicitWidth: geo.w
    implicitHeight: geo.h
    radius: geo.r

    // Direction is measured by AREA, so toast -> osd (wider but far shorter)
    // is correctly treated as a collapse and gets the faster curve.
    property real lastArea: geo.w * geo.h
    readonly property bool collapsing: geo.w * geo.h < lastArea
    onGeoChanged: lastArea = geo.w * geo.h

    readonly property int morphMs: collapsing ? Config.collapseMs : Config.expandMs
    readonly property int morphEasing: collapsing ? Easing.InQuint : Easing.OutQuint

    Behavior on implicitWidth {
        NumberAnimation { duration: root.morphMs; easing.type: root.morphEasing }
    }
    Behavior on implicitHeight {
        NumberAnimation { duration: root.morphMs; easing.type: root.morphEasing }
    }
    Behavior on radius {
        NumberAnimation { duration: root.morphMs; easing.type: root.morphEasing }
    }

    // Content is clipped while geometry moves — this is what makes it read as a
    // morph rather than a resize.
    clip: true

    // Toast lifetime. Critical notifications stay until acted on.
    Timer {
        id: toastTimer
        interval: Config.notch.toastMs
        running: Notifs.popup !== null && !Notifs.critical
        onTriggered: Notifs.hidePopup()
    }

    // Opens the dashboard. Declared BEFORE the panes so they stack above it,
    // and enabled only in the states whose panes hold nothing clickable.
    //
    // Both halves matter. This previously sat after the panes, which put it on
    // top of everything: clicking a notification toast hit this instead of the
    // toast's own handler, so the toast was never dismissed and a critical
    // notification -- which has no auto-dismiss timer by design -- could not be
    // got rid of at all.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.PointingHandCursor
        enabled: root.state_ === "rest" || root.state_ === "osd"
        onClicked: Panels.toggle("dashboard")
    }

    // ---- panes ------------------------------------------------------------
    // Each fades in 60ms after the geometry starts moving. Without that offset
    // the old text is still legible while the shape changes underneath it.

    component Pane: Item {
        anchors.fill: parent
        property string forState: ""
        readonly property bool current: root.state_ === forState
        opacity: current ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: Config.fadeDelayMs }
                NumberAnimation { duration: Config.fadeMs; easing.type: Easing.Linear }
            }
        }
    }

    Pane {
        forState: "rest"

        Row {
            anchors.centerIn: parent
            spacing: 9

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, Config.clock.timeFormat)
                color: Theme.onSurface
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Medium
                // Without tabular figures "14:11" is narrower than "14:00" and
                // a centred clock twitches every minute.
                font.features: ({ "tnum": 1 })
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, Config.clock.dateFormat)
                color: Theme.onSurfaceVariant
                font.family: "Inter"
                font.pixelSize: 11
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.dnd
                text: ""            // moon
                font.pixelSize: 11
            }

            // Unread count when notifications arrived while DND was on, or
            // while you were away.
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifs.count > 0
                width: unread.width + 10; height: 15; radius: 8
                color: Qt.alpha(Theme.primary, 0.22)
                Text {
                    id: unread
                    anchors.centerIn: parent
                    text: Notifs.count
                    color: Theme.primary
                    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 9
                }
            }

            // Shown until matugen has produced a palette, so "my colours look
            // wrong" is diagnosable instead of mysterious.
            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: !Theme.generated
                text: ""
                font.pixelSize: 9
                color: Theme.error
            }
        }
    }

    Pane { forState: "osd";      OsdPane   { visible: parent.current } }
    Pane { forState: "toast";    ToastPane { visible: parent.current } }
    Pane { forState: "critical"; ToastPane { visible: parent.current } }
    Pane { forState: "dash";     DashPane  { visible: parent.current } }

    SystemClock {
        id: clock
        // The clock shows HH:mm. Waking 60 times a minute to redraw the same
        // glyphs is pure battery cost.
        precision: SystemClock.Minutes
    }

    // Click anywhere outside the bar to close the dashboard. Without this the
    // only way out is the keybind, because the bar's input mask means stray
    // clicks never reach the shell at all.
    //
    // This grab is ALSO why the dashboard has no Escape key: it dismisses on a
    // focus change to any surface outside this list, so a second surface that
    // takes the keyboard closes the panel instead of serving it. See CLAUDE.md.
    HyprlandFocusGrab {
        id: grab
        windows: root.hostWindow ? [root.hostWindow] : []
        active: root.dashOpen
        onCleared: Panels.closeAll()
    }

    Connections {
        target: Notifs
        function onPopupChanged() {
            // A critical notification takes the notch even from the dashboard.
            if (Notifs.critical) Panels.closeAll();
        }
    }
}
