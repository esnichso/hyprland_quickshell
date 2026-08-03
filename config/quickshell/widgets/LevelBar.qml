// A progress / level bar.
//
// Called LevelBar, not Bar: bar/Bar.qml is the status bar surface and it
// imports this directory, so a type called Bar here would shadow it.

import QtQuick
import "root:/"

Rectangle {
    id: root

    // 0-1. Values above 1 clamp visually but callers can still colour them.
    property real value: 0
    property color fillColor: Theme.primary
    property bool animate: true

    implicitHeight: 4
    radius: height / 2
    color: Qt.alpha(Theme.outline, 0.45)

    Rectangle {
        width: Math.max(0, Math.min(1, root.value)) * parent.width
        height: parent.height
        radius: parent.radius
        color: root.fillColor

        Behavior on width {
            enabled: root.animate && Config.motion.enabled
            NumberAnimation { duration: 140; easing.type: Easing.OutQuint }
        }
        Behavior on color {
            ColorAnimation { duration: Config.fadeMs }
        }
    }
}
