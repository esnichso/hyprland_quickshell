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
import Quickshell.Widgets
import "root:/"
import "root:/services"
import "root:/widgets"

Item {
    id: root

    property var item: null
    property bool selected: false

    signal clicked
    signal secondaryClicked

    readonly property bool isEmoji: item && item.kind === "emoji"
    readonly property bool isInfo: item && item.kind === "info"

    // A clipboard entry that is a picture. The thumbnail is decoded to a file
    // on demand — see Clip.qml — so this is empty until that finishes and then
    // becomes a path. Binding to `Clip.thumbs` rather than reading it once is
    // what makes the row fill in when the decode lands.
    readonly property var clipEntry:
        item && item.kind === "clip" ? item.data : null
    readonly property bool isClipImage: clipEntry !== null && clipEntry.thumbable === true
    readonly property string thumb:
        isClipImage && Clip.thumbs[clipEntry.id] ? Clip.thumbs[clipEntry.id] : ""

    // Both, because delegate lifecycle order is not something to bet on: a row
    // may be constructed with `item` already set (no change signal fires) or be
    // handed a different entry later (no second construction). requestThumb is
    // idempotent, so asking twice costs one map lookup.
    onClipEntryChanged: if (isClipImage) Clip.requestThumb(clipEntry);
    Component.onCompleted: if (isClipImage) Clip.requestThumb(clipEntry);

    // A text face (¯\_(ツ)_/¯) rather than a pictograph. Ten characters wide
    // instead of one, and built from scripts an emoji font does not cover — so
    // it needs a different font AND a wider slot. Emoji.qml sets the flag; the
    // row cannot tell by looking at the string.
    readonly property bool isTextFace:
        isEmoji && item.data !== undefined && item.data !== null && item.data.face === true

    // The leading column is 24px for an icon or a single pictograph, and grows
    // for a text face up to a cap. Fixed at 24 it drew straight over the title
    // on one side and out of the row on the other.
    readonly property real leadWidth:
        isClipImage ? 52
      : isTextFace  ? Math.min(Math.max(face.implicitWidth, 24), 116)
      :               24

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
            width: root.leadWidth
            height: parent.height

            // Anything wider than the slot is cut off rather than drawn over
            // its neighbours. Nothing here sets the Text's width, so its
            // implicitWidth stays independent of the slot it sizes — binding
            // both directions would be a loop.
            clip: true

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

            // Clipboard image preview. Wider than tall, cropped to fill, so a
            // screenshot and a portrait photo both read as a picture of
            // something rather than as two differently-shaped boxes.
            ClippingRectangle {
                anchors.centerIn: parent
                width: 52
                height: 30
                radius: 5
                visible: root.thumb !== ""
                color: Qt.alpha(Theme.outline, 0.18)

                Image {
                    anchors.fill: parent
                    source: root.thumb
                    fillMode: Image.PreserveAspectCrop
                    // Decoded down at load time. A pasted 4K screenshot would
                    // otherwise become a 4K texture to draw at 52x30.
                    sourceSize.width: 128
                    asynchronous: true
                    cache: false
                }
            }

            Text {
                id: face
                // Left-aligned, not centred: a centred wide face overflows on
                // BOTH sides, and the left overflow lands outside the row.
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: root.isEmoji
                text: root.item ? root.item.glyph : ""

                // A pictograph wants the colour emoji font. A text face wants
                // the UI font, so fontconfig resolves ツ and ಠ through the Noto
                // CJK/Sans chain instead of walking the fallback list from an
                // emoji font that covers none of them.
                font.family: root.isTextFace ? "Inter" : "Noto Color Emoji"
                font.pixelSize: root.isTextFace ? 12 : 17
                color: Theme.textOnSurface
            }

            Glyph {
                anchors.centerIn: parent
                // Still shown for an image entry whose thumbnail has not
                // decoded yet — it is the placeholder, so the row does not
                // start empty and then pop.
                visible: !root.isEmoji && root.item && root.item.icon === ""
                                       && root.item.glyph !== "" && root.thumb === ""
                text: root.item ? root.item.glyph : ""
                font.pixelSize: 15
                color: root.isInfo ? Theme.error : Theme.textOnSurfaceVariant
            }
        }

        // ---- title and subtitle ----
        Column {
            width: parent.width - root.leadWidth - 12
                                - (badge.visible ? badge.width + 12 : 0)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.item ? root.item.title : ""
                color: root.isInfo ? Theme.error : Theme.textOnSurface
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
                color: Theme.textOnSurfaceVariant
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
                color: Theme.textOnSurfaceVariant
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
