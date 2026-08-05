// Control centre — Bluetooth. Replaces blueman.
//
// Pairing that needs a PIN confirmation is NOT handled: BlueZ asks for that
// through an org.bluez.Agent1 registration, which Quickshell 0.3.0 does not
// expose. Devices that pair without confirmation work; anything that puts a
// number on a screen needs bluetoothctl. Recorded in ROADMAP.md rather than
// half-built.

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import "root:/"
import "root:/services"
import "root:/widgets"

Item {
    id: root

    property bool active: false

    // Discovery is a power cost and a privacy surface; it runs only while this
    // tab is on screen, and stops the moment you leave it.
    onActiveChanged: Bt.setDiscovering(active && Bt.enabled)

    Connections {
        target: Bt
        function onEnabledChanged() {
            Bt.setDiscovering(root.active && Bt.enabled);
        }
    }

    implicitHeight: col.implicitHeight + 20

    Column {
        id: col
        y: 10
        width: parent.width
        spacing: 8

        // ---- adapter ----
        Item {
            width: parent.width
            height: 30

            Glyph {
                id: btIcon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.bluetooth
                color: Bt.enabled ? Theme.primary : Theme.textOnSurfaceVariant
                font.pixelSize: 14
            }

            Text {
                anchors.left: btIcon.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Bt.available ? "Bluetooth" : "No Bluetooth adapter"
                color: Theme.textOnSurface
                font.family: "Inter"; font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Toggle {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                checked: Bt.enabled
                enabled: Bt.available
                onToggled: wanted => Bt.setEnabled(wanted)
            }
        }

        // ---- discovery ----
        Item {
            width: parent.width
            height: 26
            visible: Bt.enabled

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 42
                anchors.verticalCenter: parent.verticalCenter
                text: Bt.discovering ? "Scanning for devices…" : "Scan for devices"
                color: Theme.textOnSurfaceVariant
                font.family: "Inter"; font.pixelSize: 11
            }

            Toggle {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                checked: Bt.discovering
                onToggled: wanted => Bt.setDiscovering(wanted)
            }
        }

        Text {
            width: parent.width
            visible: Bt.available && !Bt.enabled
            text: "Bluetooth is off"
            color: Theme.textOnSurfaceVariant
            font.family: "Inter"; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            topPadding: 14; bottomPadding: 14
        }

        Text {
            width: parent.width
            visible: Bt.enabled && Bt.devices.length === 0
            text: "No devices"
            color: Qt.alpha(Theme.textOnSurfaceVariant, 0.7)
            font.family: "Inter"; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            topPadding: 14; bottomPadding: 14
        }

        Repeater {
            model: Bt.enabled ? Bt.devices : []

            DeviceRow {
                required property var modelData
                width: col.width
                device: modelData
            }
        }
    }

    // ------------------------------------------------------------- components

    component DeviceRow: Item {
        id: row

        property var device: null

        readonly property bool connected: device !== null && device.connected
        readonly property bool bonded: device !== null && device.bonded
        readonly property bool pairing: device !== null && device.pairing
        readonly property bool hasBattery:
            device !== null && device.connected && device.batteryAvailable

        implicitHeight: 40

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.bottomMargin: 2
            radius: 9
            color: row.connected ? Qt.alpha(Theme.primary, 0.12)
                 : ma.containsMouse ? Theme.hoverBg
                 : "transparent"
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: mouse => {
                if (!row.device)
                    return;

                if (mouse.button === Qt.RightButton) {
                    if (row.bonded)
                        row.device.forget();
                    return;
                }

                if (row.pairing) {
                    row.device.cancelPair();
                    return;
                }

                // An unbonded device must be paired before it can connect;
                // calling connect() first fails in a way that looks like the
                // device is broken.
                if (!row.bonded)
                    row.device.pair();
                else
                    Bt.toggleConnection(row.device);
            }
        }

        // BluetoothDevice.icon is a freedesktop icon NAME, so it resolves
        // through the icon theme rather than the Nerd Font.
        Image {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18
            visible: source !== ""
            source: row.device && row.device.icon
                ? Quickshell.iconPath(row.device.icon, "bluetooth")
                : ""
            sourceSize: Qt.size(36, 36)
            asynchronous: true
        }

        Glyph {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            visible: !icon.visible
            text: Icons.bluetooth
            color: row.connected ? Theme.primary : Theme.textOnSurfaceVariant
            font.pixelSize: 13
        }

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 46
            anchors.right: trailing.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: Bt.label(row.device)
                color: Theme.textOnSurface
                font.family: "Inter"; font.pixelSize: 12
                font.weight: row.connected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: row.pairing ? "Pairing… click to cancel"
                    : row.connected ? "Connected"
                    : row.bonded ? "Paired"
                    : "Click to pair"
                color: Theme.textOnSurfaceVariant
                font.family: "Inter"; font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Row {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.hasBattery
                text: row.device ? `${Math.round(row.device.battery * 100)}%` : ""
                color: Theme.textOnSurfaceVariant
                font.family: "Inter"; font.pixelSize: 11
                font.features: ({ "tnum": 1 })
            }

            Glyph {
                anchors.verticalCenter: parent.verticalCenter
                visible: row.connected
                text: Icons.check
                color: Theme.primary
                font.pixelSize: 12
            }
        }
    }
}
