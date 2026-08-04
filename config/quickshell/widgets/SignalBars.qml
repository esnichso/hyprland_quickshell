// Wifi signal strength, drawn as four rising bars.
//
// Geometry, not a font glyph. Nerd Fonts puts the graded wifi-strength icons in
// the Material Design range, which v3 moved to Unicode plane 1 — codepoints
// this repo cannot verify without a session, and an invented one renders as a
// replacement box. Four rectangles cannot be wrong, scale with the theme, and
// take their colour from a role like everything else.

import QtQuick
import "root:/"

Item {
    id: root

    // 0..4. Net.bars() is the single place that maps strength to this.
    property int level: 0
    property color color: Theme.onSurfaceVariant
    property bool dimmed: false

    implicitWidth: 14
    implicitHeight: 12

    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 1.5

        Repeater {
            model: 4

            Rectangle {
                required property int index

                width: 2.5
                // 3, 5.5, 8, 10.5 — a readable rise inside 12px.
                height: 3 + index * 2.5
                radius: 1
                anchors.bottom: parent.bottom

                color: root.color
                // Bars above the level stay visible but faint, so the widget
                // has a constant shape and you can read "1 of 4" at a glance
                // instead of guessing from a stub.
                opacity: index < root.level ? (root.dimmed ? 0.55 : 1) : 0.2

                Behavior on opacity { NumberAnimation { duration: Config.fadeMs } }
            }
        }
    }
}
