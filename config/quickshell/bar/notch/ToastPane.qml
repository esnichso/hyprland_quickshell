// Notification toast.
//
// Click invokes the notification's default action; middle-click dismisses
// without acting. Both then collapse the notch.

import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import "root:/"
import "root:/services"
import "root:/widgets"

Item {
    id: root
    anchors.fill: parent

    readonly property var n: Notifs.popup
    readonly property bool critical:
        n !== null && n.urgency === NotificationUrgency.Critical

    Row {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        spacing: 12

        // Whatever the notification came with — attached art, or the sending
        // app's own icon — and a tinted glyph when neither loads.
        //
        // The glyph is keyed off Image.status, not off the URL being empty. An
        // icon NAME that resolves to a path the theme does not actually have
        // fails at LOAD time, so keying off the string left an empty square in
        // exactly the case this change exists to fix.
        Item {
            id: mark
            width: 40
            height: 40
            anchors.verticalCenter: parent.verticalCenter

            readonly property bool hasArt: pic.status === Image.Ready

            Rectangle {
                anchors.fill: parent
                radius: 10
                color: Qt.alpha(root.critical ? Theme.error : Theme.primary, 0.20)
                visible: !mark.hasArt
            }

            Glyph {
                anchors.centerIn: parent
                visible: !mark.hasArt
                text: root.critical ? "" : ""   // warning : bell
                font.pixelSize: 18
                color: root.critical ? Theme.error : Theme.primary
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: 10
                color: "transparent"
                visible: mark.hasArt

                Image {
                    id: pic
                    anchors.fill: parent
                    source: Notifs.iconFor(root.n)
                    // Fit, not crop: an app icon is square and meant to be seen
                    // whole, and cropping the one case that used to work to suit
                    // the one being added is the wrong trade.
                    fillMode: Image.PreserveAspectFit
                    sourceSize: Qt.size(80, 80)
                    asynchronous: true
                }
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 40 - 12 - (counter.visible ? counter.width + 12 : 0)
            spacing: 1

            Text {
                width: parent.width
                text: root.n ? root.n.appName : ""
                color: Theme.textOnSurfaceVariant
                font.family: "Inter"
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: root.n ? root.n.summary : ""
                color: root.critical ? Theme.error : Theme.textOnSurface
                font.family: "Inter"
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: root.n ? root.n.body : ""
                color: Theme.textOnSurfaceVariant
                font.family: "Inter"
                font.pixelSize: 12
                elide: Text.ElideRight
                maximumLineCount: 1
                // Apps may send Pango markup whether or not we advertise
                // support. Rendering it as plain text is the safe default —
                // the alternative is stray <b> tags in your messages.
                textFormat: Text.PlainText
            }
        }

        // "3" when notifications stacked up behind this one.
        Rectangle {
            id: counter
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.stacked > 0
            width: countText.width + 14
            height: 20
            radius: 10
            color: Qt.alpha(Theme.outline, 0.35)

            Text {
                id: countText
                anchors.centerIn: parent
                text: `+${Notifs.stacked}`
                color: Theme.textOnSurfaceVariant
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (!root.n) return;
            if (mouse.button === Qt.MiddleButton) {
                Notifs.dismissPopup();
                return;
            }
            // Default action if the app offered one, otherwise just dismiss.
            //
            // invoke() already destroys the notification unless it is resident,
            // so clear our reference with hidePopup() rather than dismissPopup()
            // — calling dismiss() on an already-destroyed notification is a
            // second close for the same object.
            const a = root.n.actions;
            if (a && a.length > 0) {
                a[0].invoke();
                Notifs.hidePopup();
            } else {
                Notifs.dismissPopup();
            }
        }
    }
}
