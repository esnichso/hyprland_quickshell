// A pill switch.
//
// Same rule as Slider: `checked` reflects real state and is never written here.
// A switch that flips itself on click reports success before the radio, the
// adapter or the daemon has agreed — and then sits in the wrong position until
// something else refreshes it.

import QtQuick
import "root:/"

Item {
    id: root

    property bool checked: false
    // Set while a request is in flight, so the switch can show that it is
    // waiting rather than looking like it ignored the click.
    property bool busy: false

    signal toggled(bool wanted)

    implicitWidth: 36
    implicitHeight: 20

    Rectangle {
        id: pill
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.primary : Qt.alpha(Theme.outline, 0.35)
        opacity: root.enabled ? (root.busy ? 0.6 : 1) : 0.35
        Behavior on color { ColorAnimation { duration: Config.fadeMs } }
        Behavior on opacity { NumberAnimation { duration: Config.fadeMs } }

        Rectangle {
            width: parent.height - 6
            height: width
            radius: width / 2
            y: 3
            x: root.checked ? parent.width - width - 3 : 3
            color: root.checked ? Theme.onPrimary : Theme.onSurfaceVariant

            Behavior on x {
                NumberAnimation { duration: Config.collapseMs; easing.type: Easing.OutQuint }
            }
            Behavior on color { ColorAnimation { duration: Config.fadeMs } }
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.margins: -4
        enabled: root.enabled && !root.busy
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: root.toggled(!root.checked)
    }
}
