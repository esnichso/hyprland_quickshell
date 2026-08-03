// Centre island — the notch.
//
// PHASE 1: the state machine and its geometry animation are here and working,
// but only the `rest` state has content. OSD, toast and dashboard are wired
// into the resolver and sized correctly; their content arrives in Phase 2.
//
// The machine is built first on purpose (ROADMAP §2c). A notch is a state
// machine with animated geometry, and the failure mode is one that looks right
// in screenshots and feels wrong in use — much cheaper to get right now than
// to retrofit under finished panels.

import QtQuick
import Quickshell
import "root:/"
import "root:/widgets"

IslandSurface {
    id: root

    // ---- state ------------------------------------------------------------
    // Priority order, high to low. A new event RETARGETS the running animation
    // from wherever it is; it never queues and never restarts. Every animated
    // property below uses a Behavior, which makes that free.

    property bool dashOpen: false
    property bool criticalActive: false
    property bool osdActive: false
    property bool toastActive: false

    readonly property string state_:
          dashOpen       ? "dash"
        : criticalActive ? "critical"
        : osdActive      ? "osd"
        : toastActive    ? "toast"
        : "rest"

    readonly property var geometry: ({
        rest:     { w: Config.notch.restWidth,   h: Config.bar.islandHeight, r: Config.bar.radius },
        osd:      { w: Config.notch.osdWidth,    h: Config.bar.islandHeight, r: Config.bar.radius },
        toast:    { w: Config.notch.toastWidth,  h: Config.notch.toastHeight, r: 18 },
        critical: { w: Config.notch.toastWidth,  h: Config.notch.toastHeight, r: 18 },
        dash:     { w: Config.notch.panelWidth,  h: Config.notch.panelHeight, r: 20 }
    })

    readonly property var geo: geometry[state_]

    implicitWidth: geo.w
    implicitHeight: geo.h
    radius: geo.r

    // Expanding is slower than collapsing: things that arrive should be
    // noticed, things that leave should get out of the way. Direction is
    // measured by area so a toast -> osd transition (wider but much shorter)
    // is correctly treated as a collapse.
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

    // Content is clipped while the geometry moves. This is what makes it read
    // as a morph rather than a resize.
    clip: true

    // ---- timers -----------------------------------------------------------

    Timer {
        id: osdTimer
        interval: Config.notch.osdMs
        onTriggered: root.osdActive = false
    }

    Timer {
        id: toastTimer
        interval: Config.notch.toastMs
        onTriggered: root.toastActive = false
    }

    // Called by the OSD sources in Phase 2. Restarting the timer on every
    // keypress is what keeps the OSD open while you hold the volume key.
    function showOsd() {
        osdActive = true;
        osdTimer.restart();
    }

    function showToast(critical) {
        if (critical) criticalActive = true;
        else toastActive = true;
        toastTimer.restart();
    }

    // ---- content ----------------------------------------------------------
    // Every pane is absolutely positioned and cross-fades. The fade starts
    // 60ms after the geometry does, so the old content is gone before the new
    // shape has settled.

    component Pane: Item {
        anchors.fill: parent
        property string forState: ""
        readonly property bool current: root.state_ === forState
        opacity: current ? 1 : 0
        visible: opacity > 0
        // The pause is the point: geometry starts moving, and only 60ms later
        // does the content begin to cross-fade. Without the offset the old
        // text is still legible while the shape changes underneath it, which
        // reads as a resize instead of a morph.
        Behavior on opacity {
            SequentialAnimation {
                PauseAnimation { duration: Config.fadeDelayMs }
                NumberAnimation { duration: Config.fadeMs; easing.type: Easing.Linear }
            }
        }
    }

    // rest — the clock
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
                // Tabular figures are not optional on a centred clock: with
                // proportional digits "14:11" is narrower than "14:00" and the
                // whole island twitches every minute.
                font.features: ({ "tnum": 1 })
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDateTime(clock.date, Config.clock.dateFormat)
                color: Theme.onSurfaceVariant
                font.family: "Inter"
                font.pixelSize: 11
            }

            // Do Not Disturb marker, so a suppressed notification stream is
            // never a mystery.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Config.dnd
                text: "☾"
                color: Theme.onSurfaceVariant
                font.pixelSize: 12
            }

            // Shown until matugen has generated a palette — otherwise "my
            // colours look wrong" is indistinguishable from a theming bug.
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: !Theme.generated
                text: "○"
                color: Theme.error
                font.pixelSize: 10
            }
        }
    }

    // osd / toast / dash — sized and wired, content lands in Phase 2.
    Pane {
        forState: "osd"
        Text {
            anchors.centerIn: parent
            text: "osd"
            color: Theme.onSurfaceVariant
            font.family: "Inter"; font.pixelSize: 12
        }
    }

    Pane {
        forState: "toast"
        Text {
            anchors.centerIn: parent
            text: "notification"
            color: Theme.onSurfaceVariant
            font.family: "Inter"; font.pixelSize: 12
        }
    }

    Pane {
        forState: "critical"
        Text {
            anchors.centerIn: parent
            text: "critical"
            color: Theme.error
            font.family: "Inter"; font.pixelSize: 12
        }
    }

    Pane {
        forState: "dash"
        Text {
            anchors.centerIn: parent
            text: "dashboard"
            color: Theme.onSurfaceVariant
            font.family: "Inter"; font.pixelSize: 12
        }
    }

    SystemClock {
        id: clock
        // Minute precision, not seconds: the clock shows HH:mm, so waking the
        // process 60 times a minute to redraw the same glyphs is pure battery
        // cost.
        precision: SystemClock.Minutes
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.dashOpen = !root.dashOpen
    }
}
