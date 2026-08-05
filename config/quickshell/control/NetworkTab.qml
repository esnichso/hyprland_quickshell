// Control centre — Network.
//
// Replaces nmtui, which v1 launched tiled and which swallowed the screen.
//
// The password field is INLINE in the row, not a dialog. A dialog would need a
// second surface, and this panel already holds exclusive keyboard focus.

import QtQuick
import Quickshell
import Quickshell.Networking
import "root:/"
import "root:/services"
import "root:/widgets"

Item {
    id: root

    // Set by the control centre. Scanning costs radio power, so it runs only
    // while this tab is actually on screen.
    property bool active: false

    onActiveChanged: Net.setScanning(active && Net.wifiEnabled)

    // Turning wifi on while the tab is open should start scanning too.
    Connections {
        target: Net
        function onWifiEnabledChanged() {
            Net.setScanning(root.active && Net.wifiEnabled);
        }
    }

    // Which row has its password field open. One at a time: two open editors
    // means two places to press Enter and no way to tell which is armed.
    property string editing: ""

    // Closing the editor must also move focus off it. The field is about to be
    // hidden, and focus left on a hidden item goes nowhere — the control
    // centre's Escape handler is an ancestor, so focusing this tab puts key
    // events back on a path that reaches it.
    function closeEditor() {
        editing = "";
        forceActiveFocus();
    }

    implicitHeight: col.implicitHeight + 20

    Column {
        id: col
        y: 10
        width: parent.width
        spacing: 8

        // ---- wifi master toggle ----
        Item {
            width: parent.width
            height: 30

            Glyph {
                id: wifiIcon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: Net.wifiEnabled ? Icons.wifi : Icons.wifiOff
                color: Net.wifiEnabled ? Theme.primary : Theme.textOnSurfaceVariant
                font.pixelSize: 14
            }

            Text {
                anchors.left: wifiIcon.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: Net.wifiBlocked ? "Wi-Fi — blocked by hardware switch" : "Wi-Fi"
                color: Theme.textOnSurface
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.DemiBold
            }

            Toggle {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                checked: Net.wifiEnabled
                enabled: !Net.wifiBlocked && Net.hasWifi
                onToggled: wanted => Net.setWifiEnabled(wanted)
            }
        }

        // ---- wired, pinned when the cable is in ----
        Rectangle {
            width: parent.width - 16
            x: 8
            height: 40
            radius: 9
            visible: Net.wiredConnected
            color: Qt.alpha(Theme.primary, 0.12)

            Glyph {
                id: wiredIcon
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.wired
                color: Theme.primary
                font.pixelSize: 13
            }

            Column {
                anchors.left: wiredIcon.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1

                Text {
                    text: "Wired"
                    color: Theme.textOnSurface
                    font.family: "Inter"; font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                Text {
                    text: Net.wiredDevice ? Net.wiredDevice.name : ""
                    color: Theme.textOnSurfaceVariant
                    font.family: "Inter"; font.pixelSize: 10
                }
            }

            Glyph {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: Icons.check
                color: Theme.primary
                font.pixelSize: 12
            }
        }

        // ---- states that are not a network list ----
        Text {
            width: parent.width
            visible: !Net.hasWifi
            text: "No Wi-Fi device"
            color: Theme.textOnSurfaceVariant
            font.family: "Inter"; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            topPadding: 14; bottomPadding: 14
        }

        Text {
            width: parent.width
            visible: Net.hasWifi && !Net.wifiEnabled
            text: "Wi-Fi is off"
            color: Theme.textOnSurfaceVariant
            font.family: "Inter"; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            topPadding: 14; bottomPadding: 14
        }

        Text {
            width: parent.width
            visible: Net.hasWifi && Net.wifiEnabled && Net.networks.length === 0
            text: "Scanning…"
            color: Qt.alpha(Theme.textOnSurfaceVariant, 0.7)
            font.family: "Inter"; font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            topPadding: 14; bottomPadding: 14
        }

        // ---- the networks ----
        Repeater {
            model: Net.wifiEnabled ? Net.networks : []

            NetworkRow {
                required property var modelData
                width: col.width
                network: modelData
            }
        }
    }

    // ------------------------------------------------------------- components

    component NetworkRow: Item {
        id: row

        property var network: null
        readonly property bool isEditing: root.editing === label
        readonly property string label: network ? network.name : ""
        readonly property bool connected: network !== null && network.connected
        readonly property bool busy: network !== null && network.stateChanging

        property string failure: ""

        implicitHeight: 40 + (isEditing ? 38 : 0)

        Behavior on implicitHeight {
            NumberAnimation { duration: Config.collapseMs; easing.type: Easing.OutQuint }
        }

        // NetworkManager reports the reason as an enum this repo has not
        // enumerated, so the message stays generic and the raw value is logged
        // rather than guessed at.
        Connections {
            target: row.network
            function onConnectionFailed(reason) {
                row.failure = Net.secured(row.network)
                    ? "Could not connect — check the password"
                    : "Could not connect";
                console.warn("Net: connection to", row.label, "failed, reason", reason);
            }
        }

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
            anchors.bottomMargin: row.isEditing ? 38 : 0
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: mouse => {
                if (!row.network)
                    return;

                if (mouse.button === Qt.RightButton) {
                    // Forget is only meaningful for a network with saved
                    // settings; on anything else it is a no-op that looks
                    // like a broken click.
                    if (row.network.known) {
                        row.network.forget();
                        row.failure = "";
                    }
                    return;
                }

                row.failure = "";

                if (row.connected) {
                    row.network.disconnect();
                    return;
                }

                if (Net.enterprise(row.network)) {
                    row.failure = "Enterprise networks need nmtui — not supported here";
                    return;
                }

                // A known or open network connects straight away. Only an
                // unknown secured one needs the password field.
                if (row.network.known || !Net.secured(row.network)) {
                    row.network.connect();
                    return;
                }

                root.editing = row.isEditing ? "" : row.label;
            }
        }

        SignalBars {
            id: bars
            anchors.left: parent.left
            anchors.leftMargin: 18
            y: 14
            level: Net.bars(row.network)
            color: row.connected ? Theme.primary : Theme.textOnSurfaceVariant
        }

        Column {
            anchors.left: bars.right
            anchors.leftMargin: 12
            anchors.right: trailing.left
            anchors.rightMargin: 8
            y: 8
            spacing: 1

            Row {
                spacing: 6

                Text {
                    text: row.label
                    color: Theme.textOnSurface
                    font.family: "Inter"; font.pixelSize: 12
                    font.weight: row.connected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }

                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Net.secured(row.network)
                    text: Icons.lock
                    font.pixelSize: 9
                    color: Theme.textOnSurfaceVariant
                }
            }

            Text {
                text: row.failure !== "" ? row.failure
                    : row.busy ? "Connecting…"
                    : row.connected ? "Connected"
                    : row.network && row.network.known ? `Saved · ${Net.securityLabel(row.network)}`
                    : Net.securityLabel(row.network)
                color: row.failure !== "" ? Theme.error : Theme.textOnSurfaceVariant
                font.family: "Inter"; font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Glyph {
            id: trailing
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 14
            visible: row.connected
            text: Icons.check
            color: Theme.primary
            font.pixelSize: 12
        }

        // ---- inline password ----
        Rectangle {
            visible: row.isEditing
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            height: 28
            radius: 8
            color: Qt.alpha(Theme.outline, 0.2)

            TextInput {
                id: psk
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: Text.AlignVCenter
                color: Theme.textOnSurface
                font.family: "Inter"; font.pixelSize: 12
                echoMode: TextInput.Password
                selectByMouse: true

                // Focus follows this field's own visibility. Driving it from
                // isEditingChanged instead can run before `visible` has
                // propagated, and forceActiveFocus on a hidden item is a no-op.
                onVisibleChanged: {
                    if (visible)
                        forceActiveFocus();
                    else
                        text = "";
                }

                onAccepted: {
                    if (text === "")
                        return;
                    row.network.connectWithPsk(text);
                    root.closeEditor();
                }

                // Accepted here, so Escape closes the editor and NOT the whole
                // panel. A second Escape bubbles up to the control centre,
                // which is the behaviour you want from a field inside a panel.
                Keys.onEscapePressed: event => {
                    root.closeEditor();
                    event.accepted = true;
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: psk.text === ""
                    text: "Password, then Enter"
                    color: Qt.alpha(Theme.textOnSurfaceVariant, 0.55)
                    font.family: "Inter"; font.pixelSize: 11
                }
            }
        }

    }
}
