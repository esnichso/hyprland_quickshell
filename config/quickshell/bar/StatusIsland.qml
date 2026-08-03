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
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import "root:/"
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

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property bool micMuted:
        source && source.audio && source.audio.muted

    readonly property bool volMuted:
        sink && sink.audio && sink.audio.muted

    readonly property real volume:
        sink && sink.audio ? sink.audio.volume : 0

    // Bind the nodes we read, otherwise their audio properties stay unpopulated.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(o => o)
    }

    // Scroll anywhere on the island adjusts the default sink, even when the
    // volume glyph is hidden.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            if (!root.sink || !root.sink.audio) return;
            const step = wheel.angleDelta.y > 0 ? 0.05 : -0.05;
            root.sink.audio.volume = Math.max(0, Math.min(1, root.sink.audio.volume + step));
        }
    }

    // ---- layout -----------------------------------------------------------

    component Glyph: Text {
        font.family: "Symbols Nerd Font"
        font.pixelSize: 14
        color: Theme.onSurfaceVariant
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        Behavior on color { ColorAnimation { duration: Config.fadeMs } }
    }

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
        // PHASE 1: static glyph. Quickshell.Networking wiring is Phase 2 —
        // the module exists, but a half-bound network item that lies about
        // your connection is worse than one that is obviously a placeholder.
        Glyph {
            text: ""   // nf-fa-wifi
            color: Theme.onSurfaceVariant
        }

        // --- bluetooth (conditional) ---
        Glyph {
            visible: false   // Phase 2: show when the adapter is on
            text: ""   // nf-fa-bluetooth
        }

        // --- mic, only when muted ---
        Glyph {
            visible: root.micMuted
            text: ""   // nf-fa-microphone_slash
            color: Theme.error
        }

        // --- volume, only when muted ---
        Glyph {
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
