// A round icon button. A separate FILE, not an inline `component`.
//
// Inline components need Qt 5.15. This theme has to load on whichever QML
// engine sddm happens to launch, and a syntax error here is not a bar you lose
// — it is a login screen you cannot get past. So everything in this directory
// stays inside syntax that Qt 5 and Qt 6 both accept.

import QtQuick 2.15

Rectangle {
    id: btn

    property string glyph: ""
    property color fg: "#a6adc8"
    property color fgHover: "#a6adc8"
    property color hover: "#40404a"
    property int size: 38

    signal activated()

    width: size
    height: size
    radius: Math.round(size / 3)
    color: ma.containsMouse ? hover : "transparent"

    Text {
        anchors.centerIn: parent
        text: btn.glyph
        // The shell's icon font, installed system-wide, which is the only
        // reason a greeter running as its own user can reach it.
        font.family: "Symbols Nerd Font"
        font.pixelSize: Math.round(btn.size * 0.4)
        color: ma.containsMouse ? btn.fgHover : btn.fg
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.activated()
    }
}
