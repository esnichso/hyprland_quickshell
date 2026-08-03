// Which shell surface is open.
//
// A singleton rather than state on the Bar, because three different things need
// to reach it: the keybind IPC in shell.qml, the notch's own click handler, and
// (later) each panel's close button. Passing it through the Variants delegate
// would mean bookkeeping a list of bars and reaching into their internals.
//
// Only one surface is open at a time. Opening any closes the rest — two panels
// overlapping is never what you meant.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Phase 2d ships the dashboard. The rest are declared here so the IPC
    // surface and the close-everything logic are complete from the start; each
    // becomes real as its panel is built.
    property bool dash: false
    property bool launcher: false
    property bool control: false
    property bool power: false
    property bool sysmon: false
    property bool wallpaper: false

    readonly property bool anyOpen:
        dash || launcher || control || power || sysmon || wallpaper

    readonly property var known: ["dash", "launcher", "control", "power", "sysmon", "wallpaper"]

    // Names the keybinds use, mapped to the properties above.
    readonly property var aliases: ({
        "dashboard": "dash",
        "notifications": "dash",
        "media": "dash",
        "launcher": "launcher",
        "clipboard": "launcher",
        "emoji": "launcher",
        "control": "control",
        "power": "power",
        "sysmon": "sysmon",
        "wallpaper": "wallpaper"
    })

    function closeAll() {
        dash = false; launcher = false; control = false;
        power = false; sysmon = false; wallpaper = false;
    }

    function open(name) {
        const p = aliases[name] || name;
        if (known.indexOf(p) === -1) return false;
        const wasOpen = root[p];
        closeAll();
        root[p] = true;
        return wasOpen;
    }

    function toggle(name) {
        const p = aliases[name] || name;
        if (known.indexOf(p) === -1) return false;
        const wasOpen = root[p];
        closeAll();
        root[p] = !wasOpen;
        return root[p];
    }
}
