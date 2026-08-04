// A horizontal value slider, 0..1.
//
// Hand-built rather than QtQuick.Controls.Slider: Controls brings a style
// system that would need overriding role by role, and the result would still
// not match LevelBar, which the OSD and the media seek bar already use.
//
// `value` is NOT written by the drag. The owner sets it from the real state
// (PipeWire, brightnessctl) and the slider only reports `moved`. A slider that
// writes its own value shows a position the hardware never reached whenever a
// set fails, which is how a volume control ends up lying about the volume.

import QtQuick
import "root:/"

Item {
    id: root

    property real value: 0

    // Drawn past the track end when the value exceeds 1 — software
    // amplification, worth flagging because it distorts.
    property real max: 1.0
    property color fill: Theme.primary

    signal moved(real value)

    implicitHeight: 20

    readonly property real clamped: Math.max(0, Math.min(root.max, root.value))
    readonly property bool over: root.value > 1.0

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 4
        radius: 2
        color: Qt.alpha(Theme.outline, 0.35)
        opacity: root.enabled ? 1 : 0.4

        Rectangle {
            width: Math.round(parent.width * (root.clamped / root.max))
            height: parent.height
            radius: parent.radius
            color: root.over ? Theme.error : root.fill

            // No Behavior on width. The value follows a drag, and animating it
            // means the fill lags the cursor.
            Behavior on color { ColorAnimation { duration: Config.fadeMs } }
        }
    }

    Rectangle {
        id: knob
        width: 12
        height: 12
        radius: 6
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round((parent.width - width) * (root.clamped / root.max))
        color: root.over ? Theme.error : root.fill
        opacity: root.enabled ? 1 : 0.4
        scale: ma.pressed ? 1.25 : 1
        Behavior on scale {
            NumberAnimation { duration: Config.fadeMs; easing.type: Easing.OutQuint }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        // Vertical slop: a 4px track is not a 4px hit target.
        anchors.topMargin: -6
        anchors.bottomMargin: -6
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: mouse => report(mouse.x)
        onPositionChanged: mouse => { if (pressed) report(mouse.x); }

        function report(x) {
            const w = root.width;
            if (w <= 0)
                return;
            root.moved(Math.max(0, Math.min(1, x / w)));
        }
    }
}
