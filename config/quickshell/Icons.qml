// Every Nerd Font glyph the shell uses, in one place.
//
// Two reasons this is a file rather than literals at the call sites:
//
// 1. These are private use area characters. A terminal renders them as
//    nothing, a diff shows nothing, and a tool that rewrites a file can drop
//    them silently — which is exactly how the OSD, the notch, the dashboard and
//    the toast once shipped with 23 empty icon slots. One file is one place to
//    check, and check.sh's empty-glyph rule watches the map below.
// 2. Reusing a name is how two surfaces end up drawing different icons for the
//    same concept.
//
// All classic Font Awesome codepoints, the block StatusIsland.qml has used from
// the start. Do NOT add Material Design icons: Nerd Fonts v3 moved those to
// Unicode plane 1, and their codepoints are not something this repo can verify
// without a session.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var glyphs: ({
        // network
        "wifi": "",
        "wifiOff": "",
        "wired": "",
        "lock": "",
        "check": "",
        "globe": "",

        // bluetooth
        "bluetooth": "",

        // audio
        "volume": "",
        "volumeOff": "",
        "mic": "",
        "micOff": "",
        "app": "",

        // display
        "sun": "",
        "keyboard": "",
        "moon": "",
        "display": "",

        // power profiles
        "leaf": "",
        "balance": "",
        "rocket": "",

        // generic
        "close": "",
        "refresh": "",
        "trash": "",
        "warning": ""
    })

    // Named aliases so call sites read as English. The map above is what the
    // lint watches; these are one-line pass-throughs.
    readonly property string wifi: glyphs.wifi
    readonly property string wifiOff: glyphs.wifiOff
    readonly property string wired: glyphs.wired
    readonly property string lock: glyphs.lock
    readonly property string check: glyphs.check
    readonly property string globe: glyphs.globe
    readonly property string bluetooth: glyphs.bluetooth
    readonly property string volume: glyphs.volume
    readonly property string volumeOff: glyphs.volumeOff
    readonly property string mic: glyphs.mic
    readonly property string micOff: glyphs.micOff
    readonly property string app: glyphs.app
    readonly property string sun: glyphs.sun
    readonly property string keyboard: glyphs.keyboard
    readonly property string moon: glyphs.moon
    readonly property string display: glyphs.display
    readonly property string leaf: glyphs.leaf
    readonly property string balance: glyphs.balance
    readonly property string rocket: glyphs.rocket
    readonly property string close: glyphs.close
    readonly property string refresh: glyphs.refresh
    readonly property string trash: glyphs.trash
    readonly property string warning: glyphs.warning
}
