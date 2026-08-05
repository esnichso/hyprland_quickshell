// Wallpaper and theme picker.
//
// Two tabs. The second is the switch you asked for at the very start: whether
// the wallpaper themes the desktop, or a theme you pick does. Selecting a named
// theme means you can then change wallpaper freely without the desktop
// re-colouring — Wall.qml is where that difference lives.
//
// Same window pattern as every other panel.

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "root:/"
import "root:/services"
import "root:/widgets"

PanelWindow {
    id: root

    screen: Panels.focusedScreen
    visible: Panels.wallpaper

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    WlrLayershell.namespace: "hypersetup-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    property string tab: "wallpapers"

    onVisibleChanged: {
        if (!visible)
            return;
        root.tab = "wallpapers";
        Wall.refresh();
        keys.forceActiveFocus();
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Panels.closeAll()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: event => {
            Panels.closeAll();
            event.accepted = true;
        }

        IslandSurface {
            id: box
            island: false

            width: Config.picker.width
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - Config.picker.maxHeight) / 2)

            implicitHeight: Math.min(header.height + body.wanted, Config.picker.maxHeight)

            Behavior on implicitHeight {
                NumberAnimation { duration: Config.expandMs; easing.type: Easing.OutQuint }
            }

            MouseArea {
                anchors.fill: parent
            }

            // ---- tabs ----
            Item {
                id: header
                width: parent.width
                height: 44

                Row {
                    anchors.centerIn: parent
                    spacing: 4

                    Repeater {
                        model: [
                            { id: "wallpapers", label: "Wallpapers" },
                            { id: "theme",      label: "Theme" }
                        ]

                        Rectangle {
                            id: tabChip
                            required property var modelData

                            readonly property bool selected: root.tab === modelData.id

                            implicitWidth: tabLabel.implicitWidth + 20
                            height: 26
                            radius: 8
                            color: tabChip.selected ? Qt.alpha(Theme.primary, 0.22)
                                 : tabMa.containsMouse ? Theme.hoverBg
                                 : "transparent"
                            Behavior on color { ColorAnimation { duration: Config.fadeMs } }

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: tabChip.modelData.label
                                color: tabChip.selected ? Theme.primary : Theme.textOnSurfaceVariant
                                font.family: "Inter"; font.pixelSize: 12
                                font.weight: tabChip.selected ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tab = tabChip.modelData.id
                            }
                        }
                    }
                }

                // Shown while install.sh is running. Regenerating seven
                // templates takes a moment, and a picker that looks inert is a
                // picker you click twice.
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Wall.busy
                    text: "applying…"
                    color: Theme.textOnSurfaceVariant
                    font.family: "Inter"; font.pixelSize: 10
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.outline
                    opacity: 0.2
                }
            }

            // ---- content ----
            Item {
                id: body
                anchors.top: header.bottom
                width: parent.width
                height: Math.max(0, box.height - header.height)

                readonly property real wanted:
                    root.tab === "theme" ? themeTab.implicitHeight + 20
                                         : grid.implicitHeight + 24

                Flickable {
                    anchors.fill: parent
                    contentHeight: body.wanted
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    // ---- wallpapers ----
                    Grid {
                        id: grid
                        visible: root.tab === "wallpapers"
                        x: 12
                        y: 12
                        width: body.width - 24
                        columns: Config.picker.columns
                        spacing: 8

                        readonly property real cell:
                            (width - (columns - 1) * spacing) / columns

                        Repeater {
                            model: Wall.wallpapers

                            Item {
                                id: tile
                                required property var modelData

                                width: grid.cell
                                // 16:10, the panel's own aspect ratio.
                                height: Math.round(grid.cell * 0.625)

                                readonly property bool isCurrent: Wall.current === tile.modelData

                                ClippingRectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: Qt.alpha(Theme.outline, 0.18)

                                    // sourceSize downsamples at DECODE time, so
                                    // a 4000px photo never becomes a 4000px
                                    // texture. Without it a grid of wallpapers
                                    // is hundreds of megabytes of VRAM.
                                    Image {
                                        anchors.fill: parent
                                        source: "file://" + tile.modelData
                                        fillMode: Image.PreserveAspectCrop
                                        sourceSize.width: 320
                                        asynchronous: true
                                        cache: true
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 8
                                    color: "transparent"
                                    border.width: tile.isCurrent ? 2 : (tileMa.containsMouse ? 1 : 0)
                                    border.color: tile.isCurrent ? Theme.primary : Theme.textOnSurfaceVariant
                                }

                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.margins: 5
                                    visible: tileMa.containsMouse
                                    text: Wall.basename(tile.modelData)
                                    color: Theme.textOnSurface
                                    style: Text.Outline
                                    styleColor: Theme.surface
                                    font.family: "Inter"; font.pixelSize: 10
                                    elide: Text.ElideMiddle
                                }

                                MouseArea {
                                    id: tileMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Wall.applyWallpaper(tile.modelData)
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.tab === "wallpapers" && Wall.wallpapers.length === 0
                        width: body.width
                        y: 30
                        horizontalAlignment: Text.AlignHCenter
                        text: `No images in ${Config.wallpaper.dir}`
                        color: Theme.textOnSurfaceVariant
                        font.family: "Inter"; font.pixelSize: 12
                    }

                    // ---- theme ----
                    Column {
                        id: themeTab
                        visible: root.tab === "theme"
                        y: 12
                        width: body.width
                        spacing: 10

                        Section { title: "Colour source" }

                        Choice {
                            label: "From wallpaper"
                            detail: "the palette follows the picture"
                            selected: Wall.fromWallpaper
                            onPicked: Wall.useWallpaperColours()
                        }

                        Choice {
                            label: "Pick a theme"
                            detail: "wallpaper changes stop touching colour"
                            selected: !Wall.fromWallpaper
                            // Selecting this with no theme chosen would leave
                            // the mode set and nothing regenerated, so it
                            // applies the remembered one.
                            onPicked: Wall.applyTheme(Config.theme.manual)
                        }

                        Section { title: "Scheme" }

                        Row {
                            x: 18
                            spacing: 6

                            Segment {
                                text: "Dark"
                                selected: Config.theme.scheme === "dark"
                                onPicked: Wall.setScheme("dark")
                            }
                            Segment {
                                text: "Light"
                                selected: Config.theme.scheme === "light"
                                onPicked: Wall.setScheme("light")
                            }
                        }

                        Section {
                            title: "Themes"
                            visible: !Wall.fromWallpaper
                        }

                        Repeater {
                            model: Wall.fromWallpaper ? [] : Wall.themes

                            Choice {
                                required property var modelData
                                label: modelData.name
                                detail: modelData.seed
                                swatch: modelData.seed
                                selected: Config.theme.manual === modelData.id
                                onPicked: Wall.applyTheme(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- components

    component Section: Item {
        id: section
        property string title: ""
        width: body.width
        height: 16

        Text {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.verticalCenter: parent.verticalCenter
            text: section.title
            color: Theme.textOnSurfaceVariant
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 10
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.4
        }
    }

    component Choice: Item {
        id: choice

        property string label: ""
        property string detail: ""
        property bool selected: false
        // A theme's seed colour. Empty for the two mode rows, which have no
        // colour of their own to show.
        property string swatch: ""

        signal picked

        width: body.width
        height: 40

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            radius: 9
            color: choice.selected ? Qt.alpha(Theme.primary, 0.14)
                 : choiceMa.containsMouse ? Theme.hoverBg
                 : "transparent"
        }

        Rectangle {
            id: radio
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 13; height: 13; radius: 7
            color: "transparent"
            border.width: 1.5
            border.color: choice.selected ? Theme.primary : Theme.outline

            Rectangle {
                anchors.centerIn: parent
                width: 7; height: 7; radius: 4
                visible: choice.selected
                color: Theme.primary
            }
        }

        Rectangle {
            id: swatchDot
            anchors.left: radio.right
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 14; height: 14; radius: 4
            visible: choice.swatch !== ""
            color: choice.swatch !== "" ? choice.swatch : "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.outline, 0.4)
        }

        Column {
            anchors.left: swatchDot.visible ? swatchDot.right : radio.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: choice.label
                color: Theme.textOnSurface
                font.family: "Inter"; font.pixelSize: 12
                font.weight: choice.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: choice.detail
                color: Theme.textOnSurfaceVariant
                font.family: "Inter"; font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        MouseArea {
            id: choiceMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: choice.picked()
        }
    }

    component Segment: Rectangle {
        id: seg

        property string text: ""
        property bool selected: false

        signal picked

        implicitWidth: segLabel.implicitWidth + 18
        implicitHeight: 22
        radius: 7
        color: seg.selected ? Qt.alpha(Theme.primary, 0.22)
             : segMa.containsMouse ? Theme.hoverBg
             : Qt.alpha(Theme.outline, 0.14)
        Behavior on color { ColorAnimation { duration: Config.fadeMs } }

        Text {
            id: segLabel
            anchors.centerIn: parent
            text: seg.text
            color: seg.selected ? Theme.primary : Theme.textOnSurfaceVariant
            font.family: "Inter"; font.pixelSize: 11
            font.weight: seg.selected ? Font.DemiBold : Font.Normal
        }

        MouseArea {
            id: segMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: seg.picked()
        }
    }
}
