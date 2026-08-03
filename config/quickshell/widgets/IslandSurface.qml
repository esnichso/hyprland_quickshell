// The shared look of every island and panel: translucent container colour, a
// hairline inset border, rounded corners.
//
// Both the alpha and the border come from Theme, so a wallpaper change
// restyles every surface at once without any component knowing about it.

import QtQuick
import "root:/"

Rectangle {
    id: root

    // Set false for panels, which sit on a different surface role.
    property bool island: true

    color: island ? Theme.islandBg : Theme.panelBg
    radius: Config.bar.radius

    border.width: 1
    border.color: Theme.islandBorder

    // Colour transitions are slower than motion transitions on purpose: a
    // wallpaper change should read as the desktop settling into a new palette,
    // not as a flicker.
    Behavior on color {
        ColorAnimation { duration: 400; easing.type: Easing.OutCubic }
    }
    Behavior on border.color {
        ColorAnimation { duration: 400; easing.type: Easing.OutCubic }
    }
}
