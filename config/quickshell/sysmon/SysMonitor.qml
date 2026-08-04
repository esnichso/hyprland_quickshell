// System monitor — CPU, memory, disk, network, battery, top processes.
//
// Not a bar module. You asked for a calm bar, and per-core graphs in the bar is
// the opposite of that; this is one keypress away instead. `btop` stays
// installed for when you want the real thing.
//
// Everything it shows comes from Sys.qml, which polls ONLY while this is open.
//
// Same window pattern as the launcher, control centre and power menu.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import Quickshell.Widgets
import "root:/"
import "root:/services"
import "root:/widgets"

PanelWindow {
    id: root

    screen: Panels.focusedScreen
    visible: Panels.sysmon

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    WlrLayershell.namespace: "hypersetup-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // The one thing that must not be forgotten: polling follows visibility.
    onVisibleChanged: {
        Sys.active = visible;
        if (visible)
            keys.forceActiveFocus();
    }

    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery:
        battery && battery.ready && battery.isLaptopBattery

    MouseArea {
        anchors.fill: parent
        onClicked: Panels.closeAll()
    }

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

            width: Config.sysmon.width
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - height) / 2)

            implicitHeight: Math.min(col.implicitHeight + 20, Config.sysmon.maxHeight)

            MouseArea {
                anchors.fill: parent
            }

            Flickable {
                anchors.fill: parent
                anchors.topMargin: 10
                anchors.bottomMargin: 10
                contentHeight: col.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: col
                    width: parent.width
                    spacing: 14

                    // ---- cpu ----
                    Group {
                        title: "CPU"
                        value: Sys.cpuPrimed ? `${Math.round(Sys.cpuUsage * 100)}%` : "—"
                        extra: Sys.cpuTemp >= 0 ? `${Sys.cpuTemp}°C` : ""
                        // Above 85°C is worth noticing on a laptop that is
                        // about to throttle.
                        extraWarn: Sys.cpuTemp >= 85

                        Sparkline {
                            width: parent.width - 36
                            x: 18
                            height: 30
                            values: Sys.cpuHistory
                            max: 1.0
                            color: Theme.primary
                        }

                        // Per-core bars. A single average hides one pinned
                        // core, which is the most common thing you open this
                        // panel to find.
                        Row {
                            x: 18
                            width: parent.width - 36
                            height: 14
                            spacing: 2

                            Repeater {
                                model: Sys.coreUsage.length

                                Item {
                                    required property int index
                                    width: (parent.width - (Sys.coreUsage.length - 1) * 2)
                                         / Math.max(1, Sys.coreUsage.length)
                                    height: parent.height

                                    Rectangle {
                                        anchors.bottom: parent.bottom
                                        width: parent.width
                                        height: Math.max(2, parent.height * Sys.coreUsage[parent.index])
                                        radius: 1
                                        color: Sys.coreUsage[parent.index] > 0.9
                                            ? Theme.error : Theme.primary
                                        opacity: 0.85
                                    }
                                }
                            }
                        }
                    }

                    // ---- memory ----
                    Group {
                        title: "Memory"
                        value: Sys.memTotal > 0
                            ? `${Sys.bytes(Sys.memUsed)} / ${Sys.bytes(Sys.memTotal)}`
                            : "—"

                        StackBar {
                            x: 18
                            width: parent.width - 36
                            total: Sys.memTotal
                            primary: Sys.memUsed
                            secondary: Sys.memCached
                        }

                        Row {
                            x: 18
                            spacing: 14
                            visible: Sys.swapTotal > 0

                            Text {
                                text: `swap ${Sys.bytes(Sys.swapUsed)} / ${Sys.bytes(Sys.swapTotal)}`
                                color: Theme.onSurfaceVariant
                                font.family: "Inter"; font.pixelSize: 10
                            }
                        }
                    }

                    // ---- disk ----
                    Group {
                        title: "Disk"
                        value: `${Sys.rate(Sys.diskRead)} read · ${Sys.rate(Sys.diskWrite)} write`

                        Repeater {
                            model: Sys.mounts

                            Item {
                                required property var modelData
                                x: 18
                                width: col.width - 36
                                height: 26

                                Text {
                                    id: mountName
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    width: parent.width * 0.5
                                    text: modelData.mount
                                    color: Theme.onSurface
                                    font.family: "Inter"; font.pixelSize: 11
                                    elide: Text.ElideMiddle
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    text: `${Sys.bytes(modelData.used)} / ${Sys.bytes(modelData.size)}`
                                    color: Theme.onSurfaceVariant
                                    font.family: "Inter"; font.pixelSize: 10
                                    font.features: ({ "tnum": 1 })
                                }

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 4
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: Qt.alpha(Theme.outline, 0.3)

                                    Rectangle {
                                        width: parent.width * Math.min(1, modelData.used / modelData.size)
                                        height: parent.height
                                        radius: parent.radius
                                        // A nearly full filesystem is the one
                                        // disk fact worth colouring.
                                        color: modelData.used / modelData.size > 0.9
                                            ? Theme.error : Theme.primary
                                    }
                                }
                            }
                        }
                    }

                    // ---- network ----
                    Group {
                        title: "Network"
                        value: `↓ ${Sys.rate(Sys.netRx)}   ↑ ${Sys.rate(Sys.netTx)}`

                        Sparkline {
                            x: 18
                            width: parent.width - 36
                            height: 26
                            values: Sys.netHistory
                            color: Theme.tertiary
                        }
                    }

                    // ---- battery ----
                    Group {
                        title: "Battery"
                        visible: root.hasBattery
                        value: root.hasBattery
                            ? `${Math.round(root.battery.percentage * 100)}%`
                            : ""

                        Column {
                            x: 18
                            width: parent.width - 36
                            spacing: 2

                            // changeRate is positive charging, negative
                            // discharging. The sign is information, so the
                            // label carries it rather than Math.abs hiding it.
                            Detail {
                                label: "Draw"
                                text: root.hasBattery
                                    ? `${Math.abs(root.battery.changeRate).toFixed(1)} W ${root.battery.changeRate > 0 ? "in" : "out"}`
                                    : ""
                            }

                            Detail {
                                label: root.hasBattery && root.battery.changeRate > 0
                                    ? "Full in" : "Empty in"
                                text: {
                                    if (!root.hasBattery)
                                        return "";
                                    const s = root.battery.changeRate > 0
                                        ? root.battery.timeToFull : root.battery.timeToEmpty;
                                    if (!isFinite(s) || s <= 0)
                                        return "—";
                                    const h = Math.floor(s / 3600);
                                    const m = Math.floor((s % 3600) / 60);
                                    return h > 0 ? `${h}h ${m}m` : `${m}m`;
                                }
                            }

                            Detail {
                                label: "Health"
                                visible: root.hasBattery && root.battery.healthSupported
                                text: root.hasBattery && root.battery.healthSupported
                                    ? `${Math.round(root.battery.healthPercentage)}%`
                                    : ""
                            }
                        }
                    }

                    // ---- processes ----
                    Group {
                        title: "Top processes"
                        value: ""

                        Repeater {
                            model: Sys.processes

                            Item {
                                required property var modelData
                                x: 18
                                width: col.width - 36
                                height: 22

                                Text {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 150
                                    text: modelData.name
                                    color: Theme.onSurface
                                    font.family: "Inter"; font.pixelSize: 11
                                    elide: Text.ElideRight
                                }

                                Text {
                                    anchors.right: memCol.left
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: `${modelData.cpu.toFixed(1)}%`
                                    color: modelData.cpu > 50 ? Theme.error : Theme.onSurfaceVariant
                                    font.family: "Inter"; font.pixelSize: 10
                                    font.features: ({ "tnum": 1 })
                                }

                                Text {
                                    id: memCol
                                    anchors.right: killBtn.left
                                    anchors.rightMargin: 12
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: `${modelData.mem.toFixed(1)}%`
                                    color: Theme.onSurfaceVariant
                                    font.family: "Inter"; font.pixelSize: 10
                                    font.features: ({ "tnum": 1 })
                                }

                                // SIGTERM, not SIGKILL. Asking a process to
                                // exit is the same courtesy hyprshutdown pays
                                // applications at logout.
                                Glyph {
                                    id: killBtn
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Icons.close
                                    font.pixelSize: 10
                                    color: killMa.containsMouse ? Theme.error : Qt.alpha(Theme.onSurfaceVariant, 0.5)

                                    MouseArea {
                                        id: killMa
                                        anchors.fill: parent
                                        anchors.margins: -6
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Sys.kill(modelData.pid)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- components

    // Every component below names its root with an id and refers to it that
    // way. `parent.parent.title` chains work until someone wraps a child in a
    // Row, and then they silently resolve to the wrong object.
    component Group: Column {
        id: group

        property string title: ""
        property string value: ""
        property string extra: ""
        property bool extraWarn: false

        width: col.width
        spacing: 6

        Item {
            width: group.width
            height: 16

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: group.title
                color: Theme.onSurfaceVariant
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.4
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Text {
                    text: group.extra
                    visible: text !== ""
                    color: group.extraWarn ? Theme.error : Theme.onSurfaceVariant
                    font.family: "Inter"; font.pixelSize: 11
                    font.features: ({ "tnum": 1 })
                }

                Text {
                    text: group.value
                    visible: text !== ""
                    color: Theme.onSurface
                    font.family: "Inter"; font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                }
            }
        }
    }

    component Detail: Item {
        id: detail

        property string label: ""
        property alias text: valueText.text

        width: parent.width
        height: 16

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: detail.label
            color: Theme.onSurfaceVariant
            font.family: "Inter"; font.pixelSize: 11
        }

        Text {
            id: valueText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.onSurface
            font.family: "Inter"; font.pixelSize: 11
            font.features: ({ "tnum": 1 })
        }
    }

    // Used / cached / free in one bar. Cache is not "used" — the kernel will
    // hand it back the moment something needs it — but it is not free either,
    // and showing it is the difference between "16 GB used" panic and the truth.
    component StackBar: Item {
        id: stack

        property real total: 0
        property real primary: 0
        property real secondary: 0

        height: 8

        // ClippingRectangle rather than a plain one: the fills inside are
        // square so they meet cleanly, and the rounded ends come from the
        // track clipping them.
        ClippingRectangle {
            anchors.fill: parent
            radius: 4
            color: Qt.alpha(Theme.outline, 0.3)

            Row {
                anchors.fill: parent

                Rectangle {
                    width: stack.total > 0
                        ? stack.width * Math.min(1, stack.primary / stack.total) : 0
                    height: parent.height
                    color: Theme.primary
                }

                Rectangle {
                    width: stack.total > 0
                        ? stack.width * Math.min(1, stack.secondary / stack.total) : 0
                    height: parent.height
                    color: Qt.alpha(Theme.primary, 0.35)
                }
            }
        }
    }
}
