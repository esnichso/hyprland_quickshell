// A glyph + label pill, for the session and keyboard-layout pickers.
// A separate file for the same reason as IconButton.qml — see the note there.

import QtQuick 2.15

Rectangle {
    id: pill

    property string glyph: ""
    property string label: ""
    property color fg: "#a6adc8"
    property color bg: "#33333c"
    property color bgHover: "#40404a"
    property string uiFont: "Inter"

    signal activated()

    width: inner.width + 22
    height: 32
    radius: 10
    color: pma.containsMouse ? bgHover : bg

    Row {
        id: inner
        anchors.centerIn: parent
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.glyph
            font.family: "Symbols Nerd Font"
            font.pixelSize: 12
            color: pill.fg
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: pill.label
            font.family: pill.uiFont
            font.pixelSize: 12
            color: pill.fg
        }
    }

    MouseArea {
        id: pma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.activated()
    }
}
