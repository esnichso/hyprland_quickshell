// Wallpaper and theme state.
//
// COLOUR HAS EXACTLY ONE CODE PATH, and it is `install/install.sh --theme`.
// This service does not run matugen, does not write colors.json and does not
// know what a template is; it calls the installer the same way you would from a
// terminal. A second mechanism here would be a second thing to keep in sync
// with the seven matugen targets, and it would drift.
//
// The repo path is DERIVED, never hardcoded: ~/.config/quickshell is a symlink
// into the checkout, so resolving it and going up two levels finds the repo on
// any machine. v1's fish aliases hardcoded the dev host's path and were broken
// everywhere else.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"

Singleton {
    id: root

    // Absolute paths of every image in Config.wallpaper.dir.
    property var wallpapers: []
    // [{ id, name, seed }] from themes/*.toml.
    property var themes: []
    property string current: ""
    property bool busy: false

    readonly property bool fromWallpaper: Config.theme.mode === "wallpaper"

    function refresh() {
        if (!listProc.running)
            listProc.running = true;
        if (!themeProc.running)
            themeProc.running = true;
        currentFile.reload();
    }

    // ---- actions ----------------------------------------------------------

    // In wallpaper mode this re-themes; in manual mode it only changes the
    // picture. That difference IS the setting the user asked for, so it lives
    // here in one place rather than in the panel's click handler.
    function applyWallpaper(path) {
        if (!path)
            return;
        root.current = path;
        root.busy = true;
        runInstaller(root.fromWallpaper ? ["--theme", path] : ["--wallpaper", path]);
    }

    function applyTheme(id) {
        if (!id)
            return;
        Config.theme.mode = "manual";
        Config.theme.manual = id;
        Config.save();
        root.busy = true;
        runInstaller(["--theme", id]);
    }

    // Back to wallpaper-driven colour: re-run against whatever is on screen.
    function useWallpaperColours() {
        Config.theme.mode = "wallpaper";
        Config.save();
        root.busy = true;
        runInstaller(root.current !== "" ? ["--theme", root.current] : ["--theme"]);
    }

    function setScheme(scheme) {
        Config.theme.scheme = scheme;
        Config.save();
        root.busy = true;
        // No argument: the installer re-reads mode and scheme from the file
        // Config.save() just flushed, and regenerates from the right source.
        runInstaller(["--theme"]);
    }

    // `sh -c '<script>' name "$@"` — the arguments are positional, never
    // interpolated into the script text.
    function runInstaller(args) {
        const argv = ["sh", "-c",
            'repo=$(dirname "$(dirname "$(readlink -f "$HOME/.config/quickshell")")"); ' +
            '[ -x "$repo/install/install.sh" ] || { echo "no installer at $repo" >&2; exit 1; }; ' +
            'exec "$repo/install/install.sh" "$@"',
            "install.sh"];
        for (let i = 0; i < args.length; i++)
            argv.push(args[i]);
        installProc.exec({ command: argv });
    }

    // ---- listing ----------------------------------------------------------

    function parseList(text) {
        const out = [];
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++)
            if (lines[i].trim() !== "")
                out.push(lines[i]);
        root.wallpapers = out;
    }

    function parseThemes(text) {
        const out = [];
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].split("\t");
            if (f.length < 3 || f[0] === "")
                continue;
            out.push({ id: f[0], name: f[1] || f[0], seed: f[2] || "" });
        }
        root.themes = out;
    }

    function basename(path) {
        const p = String(path || "");
        const i = p.lastIndexOf("/");
        return i === -1 ? p : p.slice(i + 1);
    }

    // install.sh records the active wallpaper here, so the picker agrees with
    // what a `--theme` from the terminal did.
    FileView {
        id: currentFile
        path: `${Quickshell.env("HOME")}/.local/state/quickshell/wallpaper`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.current = currentFile.text().trim()
        // Absent until a wallpaper has ever been chosen. Not an error.
        onLoadFailed: root.current = ""
    }

    // `~` is not expanded by anything between settings.json and here, so the
    // script does it. POSIX parameter expansion, not bash's ${x/#\~/}.
    Process {
        id: listProc
        command: ["sh", "-c",
            'dir=$1; case "$dir" in "~"*) dir="$HOME${dir#\\~}";; esac; ' +
            '[ -d "$dir" ] || exit 0; ' +
            'find "$dir" -maxdepth 1 -type f ' +
            '\\( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" ' +
            '-o -iname "*.webp" -o -iname "*.bmp" \\) | sort',
            "sh", Config.wallpaper.dir]
        stdout: StdioCollector {
            id: listOut
            onStreamFinished: root.parseList(listOut.text)
        }
        stderr: StdioCollector {}
    }

    // Emits "<id>\t<name>\t<swatch>" per theme, so each row previews its own
    // colour instead of just its name.
    //
    // The swatch is the theme's `primary` role override when it has one, and
    // its `seed` otherwise. Those are not always the same colour: gruvbox
    // seeds from the dim yellow because that is the hue the palette is built
    // around, but its accent is the bright one. Showing the seed there would
    // preview a colour the desktop never actually uses.
    Process {
        id: themeProc
        command: ["sh", "-c",
            'repo=$(dirname "$(dirname "$(readlink -f "$HOME/.config/quickshell")")"); ' +
            'for f in "$repo"/themes/*.toml; do [ -f "$f" ] || continue; ' +
            'b=$(basename "$f" .toml); ' +
            'n=$(sed -n \'s/^name *= *"\\([^"]*\\)".*/\\1/p\' "$f" | head -1); ' +
            's=$(sed -n \'s/^seed *= *"\\([^"]*\\)".*/\\1/p\' "$f" | head -1); ' +
            'p=$(sed -n \'s/^primary *= *"\\([^"]*\\)".*/\\1/p\' "$f" | head -1); ' +
            '[ -n "$p" ] && s="$p"; ' +
            'printf "%s\\t%s\\t%s\\n" "$b" "$n" "$s"; done']
        stdout: StdioCollector {
            id: themeOut
            onStreamFinished: root.parseThemes(themeOut.text)
        }
        stderr: StdioCollector {}
    }

    Process {
        id: installProc
        stderr: StdioCollector { id: installErr }
        onExited: (code, status) => {
            root.busy = false;
            if (code !== 0)
                console.warn("Wall: install.sh failed:", installErr.text.trim());
            // Theme.qml watches colors.json, so a successful run repaints the
            // shell with no further help from here.
        }
    }
}
