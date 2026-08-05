// OSD — volume, mic, brightness, keyboard backlight.
//
// Never taller than the bar. The notch widens in place, so the silhouette stays
// unbroken and nothing on screen is covered. This is the detail that makes the
// design read as deliberate rather than as a bar with a popup.

import QtQuick
import "root:/"
import "root:/services"
import "root:/widgets"

Item {
    anchors.fill: parent

    Row {
        anchors.centerIn: parent
        width: parent.width - 26
        spacing: 10

        Glyph {
            anchors.verticalCenter: parent.verticalCenter
            text: Osd.glyph
            color: Osd.warn ? Theme.error
                 : Osd.value === 0 ? Theme.textOnSurfaceVariant
                 : Theme.textOnSurface
        }

        LevelBar {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 46 - valueText.width
            value: Osd.value
            fillColor: Osd.warn ? Theme.error : Theme.primary
        }

        Text {
            id: valueText
            anchors.verticalCenter: parent.verticalCenter
            text: Osd.label
            color: Theme.textOnSurfaceVariant
            font.family: "Inter"
            font.pixelSize: 11
            font.features: ({ "tnum": 1 })
            horizontalAlignment: Text.AlignRight
            // Fixed width so the bar does not resize as the number changes
            // width between "9%" and "100%".
            width: 34
        }
    }
}
