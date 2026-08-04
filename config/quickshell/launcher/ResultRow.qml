// One row in the launcher's result list.
//
// Every mode produces the same row shape, so this is the only delegate:
//   { kind, title, subtitle, icon, glyph, badge, data }
//
// `icon` is a resolved icon path and `glyph` is a character to draw instead —
// an app has an icon, an emoji is its own glyph, a clipboard entry gets a Nerd
// Font mark. Exactly one of them is set per row.

import QtQuick
import Quickshell
import "root:/"
import "root:/widgets"

Item {
    id: root

    property var item: null
    property bool selected: false

    signal clicked
    signal secondaryClicked

    readonly property bool isEmoji: item && item.kind === "emoji"
    readonly property bool isInfo: item && item.kind === "info"

    // Monospace for anything that is literal text rather than a label: a
    // clipboard entry, a shell command, and a calculated value are all things
    // where the exact characters matter.
    readonly property bool literal:
        item && (item.kind === "clip" || item.kind === "run" || item.kind === "calc")

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        radius: 9
        color: ma.containsMouse && !root.selected ? Theme.hoverBg : "transparent"
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 12

        // ---- leading mark ----
        Item {
            width: 24
            height: parent.height

            Image {
                anchors.centerIn: parent
                width: 24
                height: 24
                visible: root.item && root.item.icon !== ""
                source: root.item ? root.item.icon : ""
                sourceSize: Qt.size(48, 48)
                asynchronous: true
                smooth: true
            }

            Text {
                anchors.centerIn: parent
                visible: root.isEmoji
                text: root.item ? root.item.glyph : ""
                // Not the Nerd Font: these are real emoji and text faces, and
                // the kaomoji need a font with the CJK and Kannada coverage
                // they are built out of.
                font.family: "Noto Color Emoji"
                font.pixelSize: 17
                color: Theme.onSurface
            }

            Glyph {
                anchors.centerIn: parent
                visible: !root.isEmoji && root.item && root.item.icon === ""
                                       && root.item.glyph !== ""
                text: root.item ? root.item.glyph : ""
                font.pixelSize: 15
                color: root.isInfo ? Theme.error : Theme.onSurfaceVariant
            }
        }

        // ---- title and subtitle ----
        Column {
            width: parent.width - 24 - 12 - (badge.visible ? badge.width + 12 : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.item ? root.item.title : ""
                color: root.isInfo ? Theme.error : Theme.onSurface
                font.family: root.literal ? "JetBrainsMono Nerd Font" : "Inter"
                font.pixelSize: root.literal ? 12 : 13
                font.weight: root.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.item ? root.item.subtitle : ""
                color: Theme.onSurfaceVariant
                font.family: "Inter"
                font.pixelSize: 11
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        // ---- badge ----
        Rectangle {
            id: badge
            anchors.verticalCenter: parent.verticalCenter
            visible: root.item && root.item.badge !== ""
            width: badgeText.implicitWidth + 12
            height: 18
            radius: 6
            color: Qt.alpha(Theme.outline, 0.22)

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.item ? root.item.badge : ""
                color: Theme.onSurfaceVariant
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 9
            }
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.clicked();
            else
                root.secondaryClicked();
        }
    }
}
