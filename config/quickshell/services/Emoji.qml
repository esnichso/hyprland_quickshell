// Emoji and kaomoji — the launcher's `:` mode.
//
// The emoji table is /usr/share/unicode/emoji/emoji-test.txt from the
// `unicode-emoji` package: the Unicode Consortium's own data file, which
// already carries a name and a category for every sequence. Shipping a
// generated JSON blob in the repo instead would mean a file nobody can review
// that goes stale on the next Unicode release.
//
// Loaded LAZILY. The file is ~5000 entries and nothing outside this mode needs
// it, so the FileView has no path until the first time `:` is typed.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/services"

Singleton {
    id: root

    readonly property string source: "/usr/share/unicode/emoji/emoji-test.txt"

    // [{ char, name, group }]
    property var entries: []
    property bool ready: false
    property bool failed: false

    // Text faces, which are not in the Unicode data because they are not
    // characters. Small and hand-picked: `:shrug` is the reason this mode is
    // reached for at all.
    readonly property var kaomoji: [
        { char: "¯\\_(ツ)_/¯",       name: "shrug",            group: "Kaomoji" },
        { char: "(╯°□°)╯︵ ┻━┻",     name: "table flip rage",  group: "Kaomoji" },
        { char: "┬─┬ ノ( ゜-゜ノ)",   name: "table put back",   group: "Kaomoji" },
        { char: "(ノ◕ヮ◕)ノ*:・゚✧",  name: "sparkle throw",    group: "Kaomoji" },
        { char: "( ͡° ͜ʖ ͡°)",        name: "lenny face",       group: "Kaomoji" },
        { char: "ಠ_ಠ",               name: "disapproval look", group: "Kaomoji" },
        { char: "(╥﹏╥)",             name: "crying sob",       group: "Kaomoji" },
        { char: "(づ｡◕‿‿◕｡)づ",      name: "hug",              group: "Kaomoji" },
        { char: "٩(◕‿◕)۶",           name: "cheer happy",      group: "Kaomoji" },
        { char: "(•_•)",             name: "deal with it",     group: "Kaomoji" },
        { char: "→",                 name: "arrow right",      group: "Symbols" },
        { char: "←",                 name: "arrow left",       group: "Symbols" },
        { char: "…",                 name: "ellipsis",         group: "Symbols" },
        { char: "—",                 name: "em dash",          group: "Symbols" },
        { char: "·",                 name: "middle dot",       group: "Symbols" },
        { char: "€",                 name: "euro sign",        group: "Symbols" },
        { char: "±",                 name: "plus minus",       group: "Symbols" },
        { char: "≈",                 name: "approximately",    group: "Symbols" },
        { char: "×",                 name: "multiplication",   group: "Symbols" },
        { char: "✓",                 name: "check mark",       group: "Symbols" }
    ]

    // Start loading. Cheap to call repeatedly.
    function ensure() {
        if (root.ready || root.failed || file.path !== "")
            return;
        file.path = root.source;
    }

    // Only fully-qualified sequences: the file also lists minimally-qualified
    // and unqualified variants of the same emoji, which render inconsistently
    // and would triple the list with duplicates.
    //
    //   1F600  ; fully-qualified  # 😀 E1.0 grinning face
    readonly property var lineRe: /^[0-9A-Fa-f ]+;\s*fully-qualified\s*#\s+(\S+)\s+E[0-9.]+\s+(.+?)\s*$/
    readonly property var groupRe: /^#\s*group:\s*(.+?)\s*$/

    function parse(text) {
        const out = [];
        for (let i = 0; i < root.kaomoji.length; i++)
            out.push(root.kaomoji[i]);

        const lines = String(text || "").split("\n");
        let group = "";

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line === "")
                continue;

            if (line.charAt(0) === "#") {
                const g = root.groupRe.exec(line);
                if (g)
                    group = g[1];
                continue;
            }

            const m = root.lineRe.exec(line);
            if (m)
                out.push({ char: m[1], name: m[2], group: group });
        }

        root.entries = out;
        root.ready = true;
    }

    function search(query) {
        const q = String(query || "").trim();
        if (q === "")
            return root.entries;

        const out = [];
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i];
            const s = Fuzzy.best(q, [[e.name, 0], [e.group, 25]]);
            if (s >= 0)
                out.push({ e: e, s: s });
        }
        out.sort((a, b) => b.s - a.s);
        return out.map(r => r.e);
    }

    function copy(entry) {
        if (!entry)
            return;
        // printf through sh rather than `wl-copy <text>`: the emoji is passed as
        // an argument, so nothing in it can be read as an option or a glob.
        Quickshell.execDetached([
            "sh", "-c", 'printf "%s" "$1" | wl-copy', "sh", entry.char
        ]);
    }

    FileView {
        id: file

        // No path until ensure() sets one — see the lazy-load note above.
        path: ""
        watchChanges: false

        onLoaded: root.parse(file.text())
        onLoadFailed: err => {
            root.failed = true;
            console.warn(`Emoji: could not read ${root.source} (${err}).`,
                         "Install the unicode-emoji package; kaomoji still work.");
            root.entries = root.kaomoji;
            root.ready = true;
        }
    }
}
