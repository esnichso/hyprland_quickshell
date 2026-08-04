// Dashboard — media, calendar, notification history.
//
// Grows down out of the notch. Three stacked sections, scrollable as one.

import QtQuick
import Quickshell
import Quickshell.Widgets
import "root:/"
import "root:/services"
import "root:/widgets"

Item {
    id: root
    anchors.fill: parent

    Flickable {
        anchors.fill: parent
        anchors.margins: 14
        contentHeight: col.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: parent.width
            spacing: 14

            // ---------------------------------------------------------- media
            Column {
                width: parent.width
                spacing: 9
                visible: Media.any

                SectionHeader {
                    width: parent.width
                    text: "Media"

                    // Player switcher. Only when more than one is registered —
                    // otherwise it is a row of one icon that does nothing.
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        visible: Media.multiple

                        Repeater {
                            model: Media.players
                            Rectangle {
                                required property var modelData
                                width: 16; height: 16; radius: 4
                                color: Qt.alpha(Theme.primary, 0.5)
                                border.width: modelData === Media.player ? 1.5 : 0
                                border.color: Theme.primary
                                opacity: modelData === Media.player ? 1 : 0.45
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Media.choose(modelData)
                                }
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 12

                    ClippingRectangle {
                        width: 96; height: 96
                        radius: 12
                        color: Qt.alpha(Theme.primary, 0.25)

                        Image {
                            anchors.fill: parent
                            source: Media.artUrl
                            fillMode: Image.PreserveAspectCrop
                            sourceSize: Qt.size(192, 192)
                            asynchronous: true
                        }

                        // Shown when the player reports no art, which is most
                        // of the time for browser tabs.
                        Glyph {
                            anchors.centerIn: parent
                            visible: Media.artUrl === ""
                            text: ""
                            font.pixelSize: 30
                            color: Theme.primary
                        }
                    }

                    Column {
                        width: parent.width - 96 - 12
                        spacing: 3

                        Text {
                            width: parent.width
                            text: Media.title || "Nothing playing"
                            color: Theme.onSurface
                            font.family: "Inter"; font.pixelSize: 14
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            width: parent.width
                            text: Media.artist
                            color: Theme.onSurfaceVariant
                            font.family: "Inter"; font.pixelSize: 12
                            elide: Text.ElideRight
                        }

                        Item { width: 1; height: 3 }

                        LevelBar {
                            width: parent.width
                            height: 3
                            visible: Media.length > 0
                            value: Media.length > 0 ? Media.position / Media.length : 0
                            // Position updates continuously; animating it fights
                            // the real value and lags behind the audio.
                            animate: false
                        }

                        Row {
                            width: parent.width
                            visible: Media.length > 0
                            Text {
                                text: Media.fmt(Media.position)
                                color: Theme.onSurfaceVariant
                                font.family: "Inter"; font.pixelSize: 10
                                font.features: ({ "tnum": 1 })
                            }
                            Item { width: parent.width - 80; height: 1 }
                            Text {
                                text: Media.fmt(Media.length)
                                color: Theme.onSurfaceVariant
                                font.family: "Inter"; font.pixelSize: 10
                                font.features: ({ "tnum": 1 })
                            }
                        }

                        Row {
                            spacing: 4
                            CtlButton {
                                glyph: ""
                                enabled: Media.canPrev
                                onClicked: Media.previous()
                            }
                            CtlButton {
                                glyph: Media.playing ? "" : ""
                                onClicked: Media.toggle()
                            }
                            CtlButton {
                                glyph: ""
                                enabled: Media.canNext
                                onClicked: Media.next()
                            }
                        }
                    }
                }
            }

            // ------------------------------------------------------- calendar
            Column {
                width: parent.width
                spacing: 9

                SectionHeader {
                    width: parent.width
                    text: Qt.formatDateTime(cal.shown, "MMMM yyyy")

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Glyph {
                            text: ""
                            font.pixelSize: 11
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cal.page(-1)
                            }
                        }
                        Glyph {
                            text: ""
                            font.pixelSize: 11
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: cal.page(1)
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: cal.today()
                        // Click the month name to snap back to the current one.
                        cursorShape: Qt.PointingHandCursor
                        z: -1
                    }
                }

                Calendar { id: cal; width: parent.width }
            }

            // --------------------------------------------- notification list
            Column {
                width: parent.width
                spacing: 9

                SectionHeader {
                    width: parent.width
                    text: "Notifications"

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Text {
                            text: Config.dnd ? "DND on" : "DND off"
                            color: Config.dnd ? Theme.primary : Theme.onSurfaceVariant
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.toggleDnd()
                            }
                        }

                        Text {
                            visible: Notifs.count > 0
                            text: "Clear all"
                            color: Theme.primary
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 10
                            MouseArea {
                                anchors.fill: parent; anchors.margins: -5
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.clearAll()
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: Notifs.count === 0
                    text: "Nothing here"
                    color: Qt.alpha(Theme.onSurfaceVariant, 0.6)
                    font.family: "Inter"; font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: 10; bottomPadding: 10
                }

                Repeater {
                    model: Notifs.history
                    NotifRow { width: col.width }
                }
            }
        }
    }

    // ------------------------------------------------------------ components

    component SectionHeader: Item {
        property alias text: label.text
        height: 14

        Text {
            id: label
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.onSurfaceVariant
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.4
        }
    }

    component CtlButton: Rectangle {
        property string glyph: ""
        property bool enabled: true
        signal clicked

        width: 32; height: 32; radius: 8
        color: ma.containsMouse && enabled ? Theme.hoverBg : "transparent"
        opacity: enabled ? 1 : 0.35

        Glyph {
            anchors.centerIn: parent
            text: parent.glyph
            color: Theme.onSurface
            font.pixelSize: 13
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: parent.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (parent.enabled) parent.clicked()
        }
    }

    component NotifRow: Rectangle {
        required property var modelData

        implicitHeight: rowCol.height + 18
        radius: 10
        color: Qt.alpha(Theme.outline, 0.16)

        Row {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 10

            Rectangle {
                width: 26; height: 26; radius: 7
                color: Qt.alpha(Theme.primary, 0.18)
                Glyph {
                    anchors.centerIn: parent
                    text: ""
                    font.pixelSize: 12
                    color: Theme.primary
                }
            }

            Column {
                id: rowCol
                width: parent.width - 26 - 10
                spacing: 1

                Row {
                    width: parent.width
                    Text {
                        text: modelData.appName
                        color: Theme.onSurfaceVariant
                        font.family: "Inter"; font.pixelSize: 11
                    }
                    Item { width: parent.width - 120; height: 1 }
                }

                Text {
                    width: parent.width
                    text: modelData.summary
                    color: Theme.onSurface
                    font.family: "Inter"; font.pixelSize: 12
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: modelData.body
                    color: Theme.onSurfaceVariant
                    font.family: "Inter"; font.pixelSize: 12
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.MiddleButton) {
                    parent.modelData.dismiss();
                    return;
                }
                const a = parent.modelData.actions;
                if (a && a.length > 0) a[0].invoke();
                else parent.modelData.dismiss();
            }
        }
    }
}
