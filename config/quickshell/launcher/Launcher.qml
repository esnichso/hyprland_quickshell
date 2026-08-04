// The launcher.
//
// One input field, six modes, one result list. A prefix character picks the
// mode; with no prefix you are searching applications.
//
//   (none)  apps      fuzzy over name, generic name, keywords, categories, exec
//   >       run       run a shell command
//   =       calc      arithmetic, Enter copies the result
//   :       emoji     emoji and kaomoji, Enter copies
//   ;       clip      cliphist history, Enter copies
//   /       window    jump to an open window
//
// This replaces rofi, rofi-calc, rofimoji and the cliphist rofi glue.
//
// The layer surface is FULL SCREEN and never changes size — the visible box
// inside it resizes instead. A layer surface that resizes gets animated by the
// compositor on top of whatever we are animating, which is what made the bar
// bounce (DESIGN.md §3).

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "root:/"
import "root:/services"
import "root:/widgets"

PanelWindow {
    id: root

    // Panels on the focused monitor. Comparing through monitorFor() rather than
    // by name keeps this to documented API on both sides.
    screen: {
        const focused = Hyprland.focusedMonitor;
        if (!focused)
            return null;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (Hyprland.monitorFor(screens[i]) === focused)
                return screens[i];
        return null;
    }

    visible: Panels.launcher

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Set explicitly even though four anchors would not trigger Auto's
    // three-anchor rule. An overlay must never reserve space, and a default
    // that happens to be right is still a default nobody wrote down.
    exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    WlrLayershell.namespace: "hypersetup-panel"
    WlrLayershell.layer: WlrLayer.Overlay

    // Exclusive, so every keystroke reaches the input rather than the window
    // underneath. Hyprland still handles its own binds before forwarding, so
    // SUPER+SPACE closes this again and the keyboard cannot be trapped — and
    // the surface only exists while the launcher is open.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // ---- query -------------------------------------------------------------

    readonly property string raw: input.text

    readonly property string mode: {
        const c = raw.charAt(0);
        switch (c) {
        case ">": return "run";
        case "=": return "calc";
        case ":": return "emoji";
        case ";": return "clip";
        case "/": return "window";
        default:  return "apps";
        }
    }

    readonly property string query:
        mode === "apps" ? raw.trim() : raw.slice(1).trim()

    readonly property var modeLabels: ({
        "apps": "Apps",
        "run": "Run",
        "calc": "Calculator",
        "emoji": "Emoji",
        "clip": "Clipboard",
        "window": "Windows"
    })

    readonly property var modeGlyphs: ({
        "apps": "",
        "run": "",
        "calc": "",
        "emoji": "",
        "clip": "",
        "window": ""
    })

    // ---- results -----------------------------------------------------------
    //
    // Every mode produces the same row shape, so the delegate stays one thing:
    //   { kind, title, subtitle, icon, glyph, badge, data }
    //
    // Each branch reads the properties it depends on (Apps.all, Clip.entries,
    // Emoji.entries, Hyprland.toplevels) during evaluation, which is what makes
    // this binding re-run when those change.

    readonly property var results: {
        switch (mode) {
        case "run":    return runResults();
        case "calc":   return calcResults();
        case "emoji":  return emojiResults();
        case "clip":   return clipResults();
        case "window": return windowResults();
        default:       return appResults();
        }
    }

    // For rows that carry a real icon and want no glyph. Named rather than a
    // bare "" so check.sh can tell a deliberate blank from a Nerd Font
    // character that got eaten somewhere between here and the file — which is
    // how the whole shell ended up with invisible icons once.
    readonly property string noGlyph: ""

    function iconFor(name) {
        return Quickshell.iconPath(name || "application-x-executable",
                                   "application-x-executable");
    }

    function appResults() {
        const ranked = Apps.rank(query);
        const out = [];
        const cap = Math.min(ranked.length, Config.launcher.maxResults);
        for (let i = 0; i < cap; i++) {
            const e = ranked[i];
            out.push({
                kind: "app",
                title: e.name,
                subtitle: e.genericName || e.comment || "",
                icon: iconFor(e.icon),
                glyph: root.noGlyph,
                badge: e.runInTerminal ? "term" : "",
                data: e
            });
        }
        return out;
    }

    function runResults() {
        if (query === "")
            return [];
        return [{
            kind: "run",
            title: query,
            subtitle: "Run in a shell",
            icon: "",
            glyph: "",
            badge: "",
            data: query
        }];
    }

    function calcResults() {
        const r = Calc.evaluate(query);
        if (r.ok) {
            return [{
                kind: "calc",
                title: r.text,
                subtitle: query,
                icon: "",
                glyph: "",
                badge: "copy",
                data: r.text
            }];
        }
        if (r.error === "")
            return [];
        return [{
            kind: "info",
            title: r.error,
            subtitle: "",
            icon: "",
            glyph: "",
            badge: "",
            data: null
        }];
    }

    function emojiResults() {
        const found = Emoji.search(query);
        const out = [];
        const cap = Math.min(found.length, Config.launcher.maxResults);
        for (let i = 0; i < cap; i++) {
            out.push({
                kind: "emoji",
                title: found[i].name,
                subtitle: found[i].group,
                icon: "",
                glyph: found[i].char,
                badge: "",
                data: found[i]
            });
        }
        return out;
    }

    function clipResults() {
        const found = Clip.search(query);
        const out = [];
        const cap = Math.min(found.length, Config.launcher.maxResults);
        for (let i = 0; i < cap; i++) {
            const e = found[i];
            out.push({
                kind: "clip",
                // cliphist collapses newlines into its preview already, but a
                // very long single line still has to be cut somewhere.
                title: e.preview.length > 160 ? e.preview.slice(0, 160) + "…" : e.preview,
                subtitle: "",
                icon: "",
                glyph: e.image ? "" : "",
                badge: "",
                data: e
            });
        }
        return out;
    }

    function windowResults() {
        const tops = Hyprland.toplevels.values;
        const scored = [];

        for (let i = 0; i < tops.length; i++) {
            const t = tops[i];
            const ipc = t.lastIpcObject;
            const cls = ipc ? (ipc["class"] || "") : "";
            const ws = t.workspace ? t.workspace.name : "";

            let s = 0;
            if (query !== "") {
                s = Fuzzy.best(query, [[t.title, 0], [cls, 6], [ws, 30]]);
                if (s < 0)
                    continue;
            }
            scored.push({ t: t, cls: cls, ws: ws, s: s });
        }

        scored.sort((a, b) => b.s - a.s);

        const out = [];
        for (let i = 0; i < scored.length; i++) {
            const r = scored[i];
            const entry = r.cls ? DesktopEntries.heuristicLookup(r.cls) : null;
            out.push({
                kind: "window",
                title: r.t.title || r.cls || "(untitled)",
                subtitle: r.cls,
                icon: iconFor(entry ? entry.icon : ""),
                glyph: root.noGlyph,
                badge: r.ws ? `ws ${r.ws}` : "",
                data: r.t
            });
        }
        return out;
    }

    // ---- activation --------------------------------------------------------

    function activate(item) {
        if (!item)
            return;

        switch (item.kind) {
        case "app":
            Apps.launch(item.data);
            break;
        case "run":
            // Through uwsm for the same reason applications are: a command
            // started here should outlive the shell that started it.
            Quickshell.execDetached(["uwsm", "app", "--", "sh", "-c", item.data]);
            break;
        case "calc":
            Quickshell.execDetached(["sh", "-c", 'printf "%s" "$1" | wl-copy', "sh", item.data]);
            break;
        case "emoji":
            Emoji.copy(item.data);
            break;
        case "clip":
            Clip.copy(item.data);
            break;
        case "window":
            Hyprland.dispatch(`focuswindow address:${item.data.address}`);
            break;
        case "info":
            return;   // nothing to run, and closing would hide the message
        }

        Panels.closeAll();
    }

    function step(delta) {
        const n = root.results.length;
        if (n === 0)
            return;
        // Wraps: pressing up on the first result is a faster way to reach the
        // last one than holding down.
        list.currentIndex = (list.currentIndex + delta + n) % n;
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
    }

    // ---- lifecycle ---------------------------------------------------------

    onVisibleChanged: {
        if (!visible)
            return;
        input.text = Panels.launcherSeed;
        input.cursorPosition = input.text.length;
        list.currentIndex = 0;
        input.forceActiveFocus();
        prime();
    }

    onModeChanged: prime()

    // A launcher bind pressed while the launcher is already open switches mode
    // rather than closing it (see Panels.toggle), which means the seed can
    // change without the window ever going invisible.
    Connections {
        target: Panels
        function onLauncherSeedChanged() {
            if (!root.visible)
                return;
            input.text = Panels.launcherSeed;
            input.cursorPosition = input.text.length;
        }
    }

    // Load whatever the current mode reads from outside the process. Cheap and
    // idempotent; called on open and on every mode change.
    function prime() {
        if (!visible)
            return;
        if (mode === "clip")
            Clip.refresh();
        else if (mode === "emoji")
            Emoji.ensure();
        else if (mode === "window")
            Hyprland.refreshToplevels();
    }

    onResultsChanged: {
        list.currentIndex = results.length > 0 ? 0 : -1;
        list.positionViewAtBeginning();
    }

    // ---- surface -----------------------------------------------------------

    // Declared BEFORE the box so it sits underneath it. A catch-all MouseArea
    // after its siblings stacks above them and swallows their clicks — that is
    // what made critical notifications impossible to dismiss.
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.closeAll()
    }

    IslandSurface {
        id: box
        island: false

        width: Config.launcher.width
        x: Math.round((parent.width - width) / 2)

        // Fixed TOP, not centred: the box is centred at its full height, and
        // shrinking it keeps the input where it is instead of sliding it up the
        // screen as you type.
        y: Math.round((parent.height - Config.launcher.height) / 2)

        implicitHeight: header.height + (listHeight > 0 ? listHeight + 1 : 0)

        readonly property real listHeight:
            Math.min(root.results.length * Config.launcher.rowHeight,
                     Config.launcher.height - header.height - 1)

        Behavior on implicitHeight {
            NumberAnimation {
                duration: Config.expandMs
                easing.type: Easing.OutQuint
            }
        }

        // The box is a Rectangle and does not take input, so without this a
        // click on its padding falls through to the close-everything MouseArea
        // underneath and dismisses the launcher you were aiming at. Declared
        // first so it stays below the header and the list.
        MouseArea {
            anchors.fill: parent
            onClicked: input.forceActiveFocus()
        }

        // ---- input row ----
        Item {
            id: header
            width: parent.width
            height: 56

            Glyph {
                id: modeGlyph
                anchors.left: parent.left
                anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.modeGlyphs[root.mode]
                font.pixelSize: 16
                color: Theme.primary
            }

            TextInput {
                id: input
                anchors.left: modeGlyph.right
                anchors.leftMargin: 14
                anchors.right: modeLabel.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter

                color: Theme.onSurface
                font.family: "Inter"
                font.pixelSize: 16
                selectionColor: Qt.alpha(Theme.primary, 0.4)
                selectedTextColor: Theme.onSurface
                clip: true
                selectByMouse: true

                // Single line. Paste of a multi-line string would otherwise
                // make the field taller than the row it sits in.
                Keys.onReturnPressed: root.activate(root.results[list.currentIndex])
                Keys.onEnterPressed: root.activate(root.results[list.currentIndex])
                Keys.onEscapePressed: Panels.closeAll()
                Keys.onUpPressed: root.step(-1)
                Keys.onDownPressed: root.step(1)

                Keys.onPressed: event => {
                    if (!(event.modifiers & Qt.ControlModifier))
                        return;

                    switch (event.key) {
                    case Qt.Key_J:
                        root.step(1);
                        event.accepted = true;
                        break;
                    case Qt.Key_K:
                        root.step(-1);
                        event.accepted = true;
                        break;
                    case Qt.Key_N:
                        root.step(1);
                        event.accepted = true;
                        break;
                    case Qt.Key_P:
                        root.step(-1);
                        event.accepted = true;
                        break;
                    case Qt.Key_Delete:
                    case Qt.Key_Backspace: {
                        // Drop a clipboard entry without leaving the launcher.
                        const item = root.results[list.currentIndex];
                        if (item && item.kind === "clip") {
                            Clip.remove(item.data);
                            event.accepted = true;
                        }
                        break;
                    }
                    }
                }

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text === ""
                    text: "Search — > run  = calc  : emoji  ; clipboard  / windows"
                    color: Qt.alpha(Theme.onSurfaceVariant, 0.55)
                    font.family: "Inter"
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
            }

            Text {
                id: modeLabel
                anchors.right: parent.right
                anchors.rightMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                text: root.modeLabels[root.mode]
                color: Theme.onSurfaceVariant
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
                font.capitalization: Font.AllUppercase
                font.letterSpacing: 1.4
            }

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: Theme.outline
                opacity: box.listHeight > 0 ? 0.2 : 0
                Behavior on opacity { NumberAnimation { duration: Config.fadeMs } }
            }
        }

        // ---- results ----
        ListView {
            id: list
            anchors.top: header.bottom
            anchors.topMargin: 1
            width: parent.width

            // Follows the ANIMATED box height rather than the target, so the
            // list and the container move together. Binding it to listHeight
            // would snap the list to its new size while the box was still
            // easing, leaving a gap under the last row for 260ms.
            height: Math.max(0, box.height - header.height - 1)
            clip: true

            model: root.results

            // currentIndex is assigned, never bound: a binding here would be
            // destroyed by the first arrow key and then silently stop tracking.
            // onResultsChanged resets it.

            // Driven from the input field's key handlers; the view must not
            // also try to interpret arrows or it fights them.
            keyNavigationEnabled: false
            interactive: true
            boundsBehavior: Flickable.StopAtBounds

            highlightMoveDuration: Config.collapseMs
            highlightResizeDuration: 0

            // Wrapped in an Item because the view sizes the highlight itself
            // and an inset cannot be expressed on the highlight directly. The
            // margins must match ResultRow's hover rectangle, or the selection
            // and the hover are two different widths.
            highlight: Item {
                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    radius: 9
                    color: Qt.alpha(Theme.primary, 0.16)
                }
            }

            delegate: ResultRow {
                required property var modelData
                required property int index

                width: list.width
                height: Config.launcher.rowHeight
                item: modelData
                selected: index === list.currentIndex

                onClicked: {
                    list.currentIndex = index;
                    root.activate(modelData);
                }
                onSecondaryClicked: {
                    if (modelData.kind === "clip")
                        Clip.remove(modelData.data);
                }
            }
        }
    }
}
