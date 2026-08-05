// Control centre — Audio. Replaces pavucontrol.
//
// Per-application volume is the reason this tab is worth the code: every
// PipeWire stream with its own slider.
//
// The live input-level meter FEATURES.md §3 asks for is not here. Reading a
// node's peak level means attaching a monitor stream, which Quickshell 0.3.0
// does not expose — see ROADMAP.md. Everything else on that list is present.

import QtQuick
import Quickshell
import "root:/"
import "root:/services"
import "root:/widgets"

Item {
    id: root

    property bool active: false

    // Binding every PipeWire node is only worth it while this tab is visible.
    // Audio.qml owns the one tracker in the shell; this just tells it when the
    // wider list is needed.
    onActiveChanged: Audio.detailed = active

    implicitHeight: col.implicitHeight + 20

    Column {
        id: col
        y: 10
        width: parent.width
        spacing: 10

        Section { title: "Output" }

        Repeater {
            model: Audio.sinks
            NodeRow {
                required property var modelData
                width: col.width
                node: modelData
                isDefault: modelData === Audio.sink
                onMakeDefault: Audio.makeDefaultSink(modelData)
            }
        }

        Text {
            width: parent.width
            visible: Audio.sinks.length === 0
            text: "No output devices"
            color: Qt.alpha(Theme.textOnSurfaceVariant, 0.7)
            font.family: "Inter"; font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }

        Section { title: "Input" }

        Repeater {
            model: Audio.sources
            NodeRow {
                required property var modelData
                width: col.width
                node: modelData
                isDefault: modelData === Audio.source
                onMakeDefault: Audio.makeDefaultSource(modelData)
            }
        }

        Text {
            width: parent.width
            visible: Audio.sources.length === 0
            text: "No input devices"
            color: Qt.alpha(Theme.textOnSurfaceVariant, 0.7)
            font.family: "Inter"; font.pixelSize: 11
            horizontalAlignment: Text.AlignHCenter
        }

        Section {
            title: "Applications"
            visible: Audio.streams.length > 0
        }

        Repeater {
            model: Audio.streams
            NodeRow {
                required property var modelData
                width: col.width
                node: modelData
                isStream: true
            }
        }
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
            color: Theme.textOnSurfaceVariant
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.4
        }
    }

    component NodeRow: Item {
        id: row

        property var node: null
        property bool isDefault: false
        property bool isStream: false

        signal makeDefault

        readonly property bool muted: node !== null && node.audio && node.audio.muted
        readonly property real volume: node !== null && node.audio ? node.audio.volume : 0

        implicitHeight: 46

        // ---- default-device radio ----
        //
        // Only for devices. A stream does not have a "default"; it has a route,
        // which is a different feature and not one this panel offers.
        Rectangle {
            id: radio
            anchors.left: parent.left
            anchors.leftMargin: 18
            y: 8
            width: 12; height: 12; radius: 6
            visible: !row.isStream
            color: "transparent"
            border.width: 1.5
            border.color: row.isDefault ? Theme.primary : Theme.outline

            Rectangle {
                anchors.centerIn: parent
                width: 6; height: 6; radius: 3
                visible: row.isDefault
                color: Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: row.makeDefault()
            }
        }

        Image {
            id: appIcon
            anchors.left: parent.left
            anchors.leftMargin: 18
            y: 6
            width: 16; height: 16
            visible: row.isStream && source !== ""
            source: {
                if (!row.isStream || !row.node)
                    return "";
                const name = Audio.iconName(row.node);
                return name ? Quickshell.iconPath(name, "application-x-executable") : "";
            }
            sourceSize: Qt.size(32, 32)
            asynchronous: true
        }

        Text {
            id: name
            anchors.left: parent.left
            anchors.leftMargin: 40
            anchors.right: pct.left
            anchors.rightMargin: 8
            y: 5
            text: Audio.label(row.node)
            color: Theme.textOnSurface
            font.family: "Inter"; font.pixelSize: 12
            font.weight: row.isDefault ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
        }

        Text {
            id: pct
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 5
            text: `${Math.round(row.volume * 100)}%`
            color: row.muted ? Theme.error : Theme.textOnSurfaceVariant
            font.family: "Inter"; font.pixelSize: 11
            font.features: ({ "tnum": 1 })
        }

        Glyph {
            id: muteBtn
            anchors.left: parent.left
            anchors.leftMargin: 18
            y: 26
            text: row.muted ? Icons.volumeOff : Icons.volume
            color: row.muted ? Theme.error : Theme.textOnSurfaceVariant
            font.pixelSize: 12

            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleNodeMute(row.node)
            }
        }

        Slider {
            anchors.left: muteBtn.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 18
            y: 22
            value: row.volume
            // Muted sliders grey out but keep their position, so unmuting
            // returns you to the level you had rather than to zero.
            enabled: !row.muted
            onMoved: v => Audio.setNodeVolume(row.node, v)
        }
    }
}
