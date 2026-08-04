// Control centre — Display, backlights, night light and power profile.
//
// METAL-ONLY, all of it flagged in ROADMAP §Phase 3: a VM has no backlight, no
// keyboard LED and no power-profiles-daemon worth the name. Each control hides
// itself when its device is absent rather than showing a dead slider — a
// control that does nothing is worse than one that is not there, because you
// cannot tell it apart from one that is broken.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import "root:/"
import "root:/services"
import "root:/widgets"

Item {
    id: root

    property bool active: false

    // sysfs does not reliably emit change notifications, so Brightness is
    // polled on demand — opening this tab is one of the demands.
    onActiveChanged: {
        if (!active)
            return;
        Brightness.refresh();
        Sunset.refresh();
    }

    implicitHeight: col.implicitHeight + 20

    Column {
        id: col
        y: 10
        width: parent.width
        spacing: 12

        // ---- screen brightness ----
        Column {
            width: parent.width
            spacing: 6
            visible: Brightness.hasScreen

            Section { title: "Brightness" }

            Item {
                width: parent.width
                height: 20

                Glyph {
                    id: sunIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.sun
                    font.pixelSize: 13
                }

                Slider {
                    anchors.left: sunIcon.right
                    anchors.leftMargin: 12
                    anchors.right: brightPct.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    value: Brightness.screen / 100
                    onMoved: v => Brightness.setScreen(Math.max(1, v * 100))
                }

                Text {
                    id: brightPct
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    width: 32
                    horizontalAlignment: Text.AlignRight
                    text: `${Brightness.screen}%`
                    color: Theme.onSurfaceVariant
                    font.family: "Inter"; font.pixelSize: 11
                    font.features: ({ "tnum": 1 })
                }
            }
        }

        // ---- keyboard backlight ----
        Column {
            width: parent.width
            spacing: 6
            visible: Brightness.hasKeyboard

            Section { title: "Keyboard backlight" }

            Item {
                width: parent.width
                height: 26

                Glyph {
                    id: kbdIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.keyboard
                    font.pixelSize: 13
                }

                // A segmented control, not a slider: the hardware has three
                // steps and a continuous control would imply otherwise.
                Row {
                    anchors.left: kbdIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Segment {
                        text: "Off"
                        selected: Brightness.keyboard <= 0
                        onPicked: Brightness.setKeyboard(0)
                    }
                    Segment {
                        text: "Low"
                        selected: Brightness.keyboard > 0 && Brightness.keyboard < 66
                        onPicked: Brightness.setKeyboard(50)
                    }
                    Segment {
                        text: "High"
                        selected: Brightness.keyboard >= 66
                        onPicked: Brightness.setKeyboard(100)
                    }
                }
            }
        }

        // ---- night light ----
        Column {
            width: parent.width
            spacing: 6

            Section { title: "Night light" }

            Item {
                width: parent.width
                height: 26

                Glyph {
                    id: moonIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.moon
                    color: Sunset.enabled ? Theme.primary : Theme.onSurfaceVariant
                    font.pixelSize: 13
                }

                Text {
                    anchors.left: moonIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: Sunset.error !== "" ? Sunset.error
                        : Sunset.enabled ? `${Sunset.temperature}K`
                        : "Off"
                    color: Sunset.error !== "" ? Theme.error : Theme.onSurfaceVariant
                    font.family: "Inter"; font.pixelSize: 11
                    font.features: ({ "tnum": 1 })
                }

                Toggle {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Sunset.enabled
                    onToggled: wanted => Sunset.setEnabled(wanted)
                }
            }

            Item {
                width: parent.width
                height: 20
                visible: Sunset.enabled

                Slider {
                    anchors.left: parent.left
                    anchors.leftMargin: 44
                    anchors.right: parent.right
                    anchors.rightMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    fill: Theme.tertiary
                    // Warmest on the left reads the way the effect does: drag
                    // right for a cooler, more neutral screen.
                    value: (Sunset.temperature - Sunset.warmest)
                         / (Sunset.coolest - Sunset.warmest)
                    onMoved: v => Sunset.enable(
                        Sunset.warmest + v * (Sunset.coolest - Sunset.warmest))
                }
            }
        }

        // ---- display scale ----
        Column {
            width: parent.width
            spacing: 6

            Section { title: "Scale" }

            Item {
                width: parent.width
                height: 26

                Glyph {
                    id: scaleIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: Icons.display
                    font.pixelSize: 13
                }

                Row {
                    anchors.left: scaleIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: [1.0, 1.25, 1.5, 1.6]

                        Segment {
                            required property var modelData
                            text: String(modelData)
                            selected: Math.abs(root.currentScale - modelData) < 0.001
                            onPicked: root.setScale(modelData)
                        }
                    }
                }
            }

            Text {
                width: parent.width - 36
                x: 18
                // The 1.25-vs-1.6 question is open until this runs on the real
                // panel; CLAUDE.md says not to quietly assume either.
                text: "Applies until the next reload. Set it in conf/monitors.lua to keep it."
                color: Qt.alpha(Theme.onSurfaceVariant, 0.7)
                font.family: "Inter"; font.pixelSize: 10
                wrapMode: Text.Wrap
            }
        }

        // ---- power profile ----
        Column {
            width: parent.width
            spacing: 6

            Section { title: "Power profile" }

            Item {
                width: parent.width
                height: 26

                Glyph {
                    id: profileIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: PowerProfiles.profile === PowerProfile.PowerSaver ? Icons.leaf
                        : PowerProfiles.profile === PowerProfile.Performance ? Icons.rocket
                        : Icons.balance
                    color: Theme.primary
                    font.pixelSize: 13
                }

                Row {
                    anchors.left: profileIcon.right
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Segment {
                        text: "Saver"
                        selected: PowerProfiles.profile === PowerProfile.PowerSaver
                        onPicked: PowerProfiles.profile = PowerProfile.PowerSaver
                    }
                    Segment {
                        text: "Balanced"
                        selected: PowerProfiles.profile === PowerProfile.Balanced
                        onPicked: PowerProfiles.profile = PowerProfile.Balanced
                    }
                    Segment {
                        text: "Performance"
                        selected: PowerProfiles.profile === PowerProfile.Performance
                        enabled: PowerProfiles.hasPerformanceProfile
                        onPicked: PowerProfiles.profile = PowerProfile.Performance
                    }
                }
            }
        }
    }

    // ---- scale ---------------------------------------------------------------
    //
    // Read from Hyprland rather than remembered, so the buttons reflect what the
    // compositor is actually doing after a `hyprctl reload` or a docked monitor.

    readonly property real currentScale: {
        const m = Hyprland.focusedMonitor;
        if (!m || !m.lastIpcObject)
            return 1.0;
        const s = m.lastIpcObject.scale;
        return s === undefined ? 1.0 : s;
    }

    function setScale(s) {
        const m = Hyprland.focusedMonitor;
        if (!m || !m.name)
            return;
        Hyprland.dispatch(`keyword monitor ${m.name},preferred,auto,${s}`);
        Hyprland.refreshMonitors();
    }

    // ------------------------------------------------------------- components

    component Section: Item {
        property alias title: label.text
        width: col.width
        height: 16

        Text {
            id: label
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.onSurfaceVariant
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.4
        }
    }

    component Segment: Rectangle {
        id: seg

        property string text: ""
        property bool selected: false

        signal picked

        implicitWidth: segLabel.implicitWidth + 18
        implicitHeight: 22
        radius: 7

        color: seg.selected ? Qt.alpha(Theme.primary, 0.22)
             : segMa.containsMouse && seg.enabled ? Theme.hoverBg
             : Qt.alpha(Theme.outline, 0.14)
        opacity: seg.enabled ? 1 : 0.35

        Behavior on color { ColorAnimation { duration: Config.fadeMs } }

        Text {
            id: segLabel
            anchors.centerIn: parent
            text: seg.text
            color: seg.selected ? Theme.primary : Theme.onSurfaceVariant
            font.family: "Inter"; font.pixelSize: 11
            font.weight: seg.selected ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: segMa
            anchors.fill: parent
            hoverEnabled: true
            enabled: seg.enabled
            cursorShape: seg.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: seg.picked()
        }
    }
}
