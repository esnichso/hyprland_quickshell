// Theme — the Material 3 role set, read from the file matugen generates.
//
// colors.json is gitignored and does not exist until `install.sh --theme` has
// run. The defaults below are Catppuccin Mocha so a fresh clone comes up
// looking deliberate rather than black-on-black. They are the ONLY hex values
// in the shell; everything else binds to a role.
//
// Roles, not palette names. Components ask for Theme.primary or
// Theme.textOnSurfaceVariant, never for "mauve" — that is what makes both
// theming modes render through one code path.
//
// WHY `textOnSurface` AND NOT Material's own `onSurface`. QML reserves names of
// the form `on` + Capital for signal handlers. Declaring `onSurface` next to
// `surface` on the same object costs the property its BINDING — it keeps its
// default value, and the default for a color is BLACK. Nothing warns.
//
// That shipped. Every piece of text asking for Theme.onSurface drew black on a
// dark island: the clock, the launcher input, every result row. Theme
// .onSurfaceVariant beside it was fine, because no `surfaceVariant` role is
// declared here — and that asymmetry is what identified the cause, after two
// screenshots under completely different palettes showed the same black clock
// and ruled the palette out.
//
// `check.sh`'s qml lint now fails on any `onX` declared alongside `X`.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // --- surfaces ---
    readonly property color background: read("background", "#1e1e2e")
    readonly property color surface: read("surface", "#1e1e2e")
    readonly property color surfaceContainerLow: read("surface_container_low", "#181825")
    readonly property color surfaceContainer: read("surface_container", "#313244")
    readonly property color surfaceContainerHigh: read("surface_container_high", "#45475a")

    // --- content ---
    readonly property color textOnSurface: read("on_surface", "#cdd6f4")
    readonly property color textOnSurfaceVariant: read("on_surface_variant", "#a6adc8")
    readonly property color outline: read("outline", "#6c7086")

    // --- accents ---
    readonly property color primary: read("primary", "#cba6f7")
    readonly property color textOnPrimary: read("on_primary", "#1e1e2e")
    readonly property color secondary: read("secondary", "#f5c2e7")
    readonly property color tertiary: read("tertiary", "#94e2d5")
    readonly property color error: read("error", "#f38ba8")

    // --- derived, so the numbers live in one place (DESIGN.md §4) ---
    readonly property color islandBg: Qt.alpha(surfaceContainer, 0.72)
    readonly property color islandBorder: Qt.alpha(outline, 0.18)
    readonly property color panelBg: Qt.alpha(surfaceContainerLow, 0.86)
    readonly property color hoverBg: Qt.alpha(outline, 0.22)

    // True once matugen has actually produced a palette. The bar shows a small
    // marker when false, so "my colours are wrong" is diagnosable at a glance
    // instead of looking like a theming bug.
    readonly property bool generated: colorsFile.loaded

    function read(key, fallback) {
        if (!colorsFile.loaded || !colorsFile.adapter.colors)
            return fallback;
        const v = colorsFile.adapter.colors[key];
        return (v === undefined || v === null || v === "") ? fallback : v;
    }

    // RELOADING IS DEBOUNCED AND RETRIED, and both halves matter.
    //
    // matugen rewrites colors.json in place rather than writing a temp file and
    // renaming it, so the watcher fires while the file is truncated or half
    // written. Reloading on that first event reads a fragment, `JSON.parse`
    // fails, and `onLoadFailed` runs — and nothing re-read the file afterwards,
    // because the only thing that triggers a read is the NEXT change.
    //
    // The result was a theme that applied "sometimes": matugen usually emits
    // several write events, so a later one often caught the finished file and
    // it worked. When it did not, every role fell back to the defaults at the
    // top of this file — which is why a desktop that failed this way looked
    // like Catppuccin Mocha no matter which wallpaper produced it.
    //
    // So: collapse a burst of events into one read of the finished file, and
    // treat a failed read as transient before believing it.
    FileView {
        id: colorsFile
        path: `${Quickshell.env("HOME")}/.config/quickshell/colors.json`

        property bool loaded: false
        property int attempts: 0

        watchChanges: true
        onFileChanged: debounce.restart()

        onLoaded: {
            loaded = true;
            attempts = 0;
        }

        // `loaded` is deliberately NOT cleared while retrying. A partial read
        // is not a reason to drop a palette that is already on screen — doing
        // so would flash the whole desktop to the built-in defaults and back.
        onLoadFailed: {
            if (attempts < 5) {
                attempts = attempts + 1;
                retry.restart();
                return;
            }
            loaded = false;
            console.warn("Theme: could not read colors.json after 5 attempts —",
                         "it is missing, or matugen left it unparseable.",
                         "Run install.sh --theme. Using built-in defaults.");
        }

        JsonAdapter {
            // matugen writes { "colors": { "<role>": "#rrggbb", ... } }.
            // Keeping it as a plain object rather than declaring 40 typed
            // properties means adding a role to the template does not require
            // touching this file.
            property var colors: ({})
        }
    }

    // Declared beside the FileView rather than inside it: FileView's one child
    // slot is its adapter, and a Timer parented there is not something to bet
    // the palette on.
    //
    // 120ms is long enough to swallow the truncate-then-write burst matugen
    // produces and short enough that the desktop still recolours as one motion
    // rather than as a visible step.
    Timer {
        id: debounce
        interval: 120
        onTriggered: colorsFile.reload()
    }

    // Backs off a little further than the debounce: if the first read landed
    // mid-write, the writer is still going, and reading again immediately just
    // spends an attempt to learn the same thing.
    Timer {
        id: retry
        interval: 180
        onTriggered: colorsFile.reload()
    }
}
