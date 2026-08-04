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
import Quickshell.Hyprland

Singleton {
    id: root

    // The screen a panel should appear on. Resolved through monitorFor() rather
    // than by comparing names, which keeps it to documented API on both sides.
    // Null means "quickshell picks", which is correct for a single display.
    readonly property var focusedScreen: {
        const focused = Hyprland.focusedMonitor;
        if (!focused)
            return null;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (Hyprland.monitorFor(screens[i]) === focused)
                return screens[i];
        return null;
    }

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

    // The text the launcher opens with. SUPER+V and SUPER+. are the launcher in
    // clipboard and emoji mode, not separate surfaces — one input field with a
    // prefix already typed.
    property string launcherSeed: ""

    readonly property var seeds: ({
        "launcher": "",
        "clipboard": ";",
        "emoji": ":"
    })

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
        seed(name, p);
        root[p] = true;
        return wasOpen;
    }

    function toggle(name) {
        const p = aliases[name] || name;
        if (known.indexOf(p) === -1) return false;
        const wasOpen = root[p];

        // The three launcher binds are modes of one surface. Pressing SUPER+V
        // while the launcher is already open in app mode means "clipboard", not
        // "never mind" — so a bind that changes the mode switches instead of
        // closing. Pressing the SAME bind twice still closes.
        if (p === "launcher" && wasOpen
                && seeds[name] !== undefined && seeds[name] !== launcherSeed) {
            launcherSeed = seeds[name];
            return true;
        }

        closeAll();
        seed(name, p);
        root[p] = !wasOpen;
        return root[p];
    }

    // Set BEFORE the panel becomes visible: the launcher reads the seed in its
    // onVisibleChanged handler, so writing it afterwards would land one
    // keypress too late and leave the field empty on the first open.
    function seed(name, prop) {
        if (prop !== "launcher") return;
        const s = seeds[name];
        launcherSeed = s === undefined ? "" : s;
    }
}
