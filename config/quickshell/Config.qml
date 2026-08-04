// Config — the single source of every tunable in the shell.
//
// Wraps settings.json with a FileView that watches for changes, so editing the
// file re-renders the shell with no restart. Nothing in this repo should ever
// hardcode a geometry number or a duration; bind to Config.* instead. That is
// what lets the theme pipeline and (later) a settings panel both write state
// without touching QML source.
//
// Every group below carries defaults matching settings.json. They are not
// redundant: if the file is missing, malformed, or mid-write when the FileView
// reads it, the shell still comes up looking correct instead of collapsing to
// zero-sized objects.

pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property alias bar: adapter.bar
    readonly property alias notch: adapter.notch
    readonly property alias launcher: adapter.launcher
    readonly property alias control: adapter.control
    readonly property alias motion: adapter.motion
    readonly property alias clock: adapter.clock
    readonly property alias theme: adapter.theme
    readonly property alias wallpaper: adapter.wallpaper
    readonly property alias modules: adapter.modules

    property alias dnd: adapter.dnd

    // Motion durations, already resolved against motion.enabled. Components
    // bind to these rather than checking the flag themselves, so honouring
    // "reduced motion" is not something a new component can forget to do.
    readonly property int expandMs: adapter.motion.enabled ? adapter.motion.expandMs : 0
    readonly property int collapseMs: adapter.motion.enabled ? adapter.motion.collapseMs : 0
    readonly property int fadeMs: adapter.motion.enabled ? adapter.motion.fadeMs : 0
    readonly property int fadeDelayMs: adapter.motion.enabled ? adapter.motion.fadeDelayMs : 0

    function save() {
        settingsFile.writeAdapter();
    }

    FileView {
        id: settingsFile
        path: `${Quickshell.env("HOME")}/.config/quickshell/settings.json`

        watchChanges: true
        onFileChanged: reload()

        // Do not create the file if it is missing. A missing settings.json
        // means link.sh has not run, and writing a fresh one there would mask
        // that with a file the repo does not know about.
        onLoadFailed: err => console.warn("Config: could not read settings.json:", err)

        JsonAdapter {
            id: adapter

            property JsonObject bar: JsonObject {
                property int height: 46
                property int islandHeight: 34
                property int radius: 14
                property int sideMargin: 10
                property int topMargin: 6
                property int islandPadding: 11
            }

            property JsonObject notch: JsonObject {
                property int restWidth: 168
                property int osdWidth: 240
                property int toastWidth: 400
                property int toastHeight: 76
                property int panelWidth: 440
                property int panelHeight: 560
                property int toastMs: 5000
                property int osdMs: 1600
            }

            // height is the launcher's MAXIMUM height: the box shrinks to fit
            // the result list and only reaches this when the list is full.
            property JsonObject launcher: JsonObject {
                property int width: 640
                property int height: 420
                property int rowHeight: 44
                property int maxResults: 40
                // Terminal for desktop entries with Terminal=true. Matches the
                // one conf/binds.lua opens on SUPER+Return.
                property string terminal: "kitty"
            }

            // maxHeight caps the panel; each tab is shorter when its content
            // is, and scrolls when it is not.
            property JsonObject control: JsonObject {
                property int width: 400
                property int maxHeight: 520
            }

            property JsonObject motion: JsonObject {
                property bool enabled: true
                property int expandMs: 260
                property int collapseMs: 180
                property int fadeMs: 120
                property int fadeDelayMs: 60
            }

            property JsonObject clock: JsonObject {
                property string timeFormat: "HH:mm"
                property string dateFormat: "ddd d. MMM"
            }

            property JsonObject theme: JsonObject {
                property string mode: "wallpaper"
                property string manual: "catppuccin-mocha"
                property string scheme: "dark"
            }

            property JsonObject wallpaper: JsonObject {
                property string dir: "~/Bilder/walls"
                property string fit: "cover"
            }

            property JsonObject modules: JsonObject {
                property bool workspaces: true
                property bool tray: true
                property bool bluetooth: true
                property bool notchMedia: false
            }

            property bool dnd: false
        }
    }
}
