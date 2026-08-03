// A Nerd Font icon.
//
// ttf-nerd-fonts-symbols is a hard dependency — without it every icon in the
// shell is a replacement box. check.sh does not verify this because a missing
// glyph is immediately obvious, unlike a missing colour.

import QtQuick
import "root:/"

Text {
    font.family: "Symbols Nerd Font"
    font.pixelSize: 14
    color: Theme.onSurfaceVariant
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering

    Behavior on color {
        ColorAnimation { duration: Config.fadeMs }
    }
}
