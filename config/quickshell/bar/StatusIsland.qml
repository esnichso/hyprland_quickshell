// Right island — tray, network, bluetooth, audio, battery.
//
// Items marked conditional render only when they are NOT in the boring state,
// so the island stays short. Battery and network are always visible; that was
// an explicit requirement.
//
// Icons are Nerd Font glyphs. ttf-nerd-fonts-symbols is a hard dependency —
// without it every icon is a replacement box.

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray
import "root:/"
import "root:/services"
import "root:/widgets"

IslandSurface {
    id: root

    implicitHeight: Config.bar.islandHeight
    implicitWidth: row.implicitWidth + Config.bar.islandPadding * 2

    Behavior on implicitWidth {
        NumberAnimation { duration: Config.expandMs; easing.type: Easing.OutQuint }
    }

    // ---- data -------------------------------------------------------------

    readonly property var battery: UPower.displayDevice

    // A VM and a desktop have no battery. Removing the item entirely is
    // deliberate: v1 shipped a bar that showed "0%" forever because it was
    // built against a VM that had no BAT0.
    readonly property bool hasBattery:
        battery && battery.ready && battery.isLaptopBattery

    readonly property int batteryPct:
        hasBattery ? Math.round(battery.percentage * 100) : 0

    readonly property bool charging:
        hasBattery && (battery.state === UPowerDeviceState.Charging
                    || battery.state === UPowerDeviceState.FullyCharged)

    readonly property bool batteryLow: hasBattery && !charging && batteryPct <= 20
    readonly property bool batteryCritical: hasBattery && !charging && batteryPct <= 10

    // Audio comes from the Audio singleton, which owns the one PwObjectTracker
    // in the shell. A second tracker on the same nodes is redundant work and an
    // easy way to end up with two components disagreeing about the volume.
    readonly property bool micMuted: Audio.micMuted
    readonly property bool volMuted: Audio.muted

    // Scroll anywhere on the island adjusts the default sink, even when the
    // volume glyph is hidden. The OSD appears because Audio's volume changed,
    // not because this handler asked for it.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => Audio.stepVolume(wheel.angleDelta.y > 0 ? 0.05 : -0.05)
    }

    // ---- layout -----------------------------------------------------------

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 9

        // --- system tray ---
        Row {
            spacing: 8
            visible: Config.modules.tray && SystemTray.items.values.length > 0
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: SystemTray.items

                Item {
                    required property var modelData
                    width: 14
                    height: 14
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        source: modelData.icon
                        sourceSize: Qt.size(14, 14)
                        smooth: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -5
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        cursorShape: Qt.PointingHandCursor
                        // Right-click needs a DBusMenu popup, which is Phase 2.
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton) modelData.activate();
                            else modelData.secondaryActivate();
                        }
                    }
                }
            }
        }

        // --- divider ---
        Rectangle {
            width: 1
            height: 14
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.outline
            opacity: 0.3
            visible: Config.modules.tray && SystemTray.items.values.length > 0
        }

        // --- network ---
        //
        // Wired outranks wifi: if the cable is in, that is the connection you
        // are on. Net.mode resolves the four states in one place so this and
        // the control centre cannot disagree.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Net.mode === "wifi" ? bars.implicitWidth : netGlyph.implicitWidth
            height: Config.bar.islandHeight

            SignalBars {
                id: bars
                anchors.centerIn: parent
                visible: Net.mode === "wifi"
                level: Net.bars(Net.active)
                color: Theme.onSurfaceVariant
            }

            Glyph {
                id: netGlyph
                anchors.centerIn: parent
                visible: Net.mode !== "wifi"
                text: Net.mode === "wired" ? Icons.wired
                    : Net.mode === "off" ? Icons.wifiOff
                    : Icons.wifiOff
                // Down is the only one worth colouring: off is a choice you
                // made, down is something that broke.
                color: Net.mode === "down" ? Theme.error : Theme.onSurfaceVariant
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggle("control")
            }
        }

        // --- bluetooth (conditional) ---
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            // Hidden when the adapter is off, which is the boring state. An
            // absent adapter (a VM) hides it too.
            visible: Config.modules.bluetooth && Bt.enabled
            text: Icons.bluetooth
            color: Bt.anyConnected ? Theme.primary : Theme.onSurfaceVariant

            MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.toggle("control")
            }
        }

        // --- mic, only when muted ---
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.micMuted
            text: ""   // nf-fa-microphone_slash
            color: Theme.error
        }

        // --- volume, only when muted ---
        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.volMuted
            text: ""   // nf-fa-volume_off
            color: Theme.error
        }

        // --- battery ---
        Row {
            spacing: 5
            visible: root.hasBattery
            anchors.verticalCenter: parent.verticalCenter

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                text: root.charging ? "" : ""   // bolt : battery
                color: root.batteryCritical ? Theme.error
                     : root.batteryLow ? Theme.error
                     : root.charging ? Theme.primary
                     : Theme.onSurfaceVariant

                SequentialAnimation on opacity {
                    running: root.batteryCritical && Config.motion.enabled
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutQuad }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `${root.batteryPct}%`
                color: root.batteryLow ? Theme.error
                     : root.charging ? Theme.primary
                     : Theme.onSurface
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.Medium
                font.features: ({ "tnum": 1 })
                Behavior on color { ColorAnimation { duration: Config.fadeMs } }
            }
        }
    }
}
