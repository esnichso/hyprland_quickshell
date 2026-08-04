// Clipboard history — the launcher's `;` mode.
//
// cliphist is the store; the daemons that feed it are started in
// conf/autostart.lua. This only ever reads and deletes.
//
// Every cliphist call goes through `sh -c '<script>' sh "$id"` with the id as a
// POSITIONAL ARGUMENT, never interpolated into the script text. The ids come
// from cliphist's own output rather than from the user, but a shell string
// built by concatenation is the kind of thing that is safe until the day the
// input changes.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/services"

Singleton {
    id: root

    // [{ id, line, preview, image }]
    property var entries: []
    property bool loaded: false

    // cliphist renders binary entries as `[[ binary data 41 KiB png 800x600 ]]`.
    readonly property var binaryMarker: /^\[\[\s*binary data/

    function refresh() {
        if (lister.running)
            return;
        lister.running = true;
    }

    function parse(text) {
        const out = [];
        const lines = String(text || "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line === "")
                continue;

            // cliphist list is "<id>\t<preview>". Split on the FIRST tab only:
            // the clipboard content itself can contain tabs.
            const tab = line.indexOf("\t");
            if (tab === -1)
                continue;

            const preview = line.slice(tab + 1);
            out.push({
                id: line.slice(0, tab),
                line: line,
                preview: preview,
                image: root.binaryMarker.test(preview)
            });
        }

        root.entries = out;
        root.loaded = true;
    }

    function search(query) {
        const q = String(query || "").trim();
        if (q === "")
            return root.entries;

        const out = [];
        for (let i = 0; i < root.entries.length; i++) {
            const e = root.entries[i];
            const s = Fuzzy.score(q, e.preview);
            if (s >= 0)
                out.push({ e: e, s: s });
        }
        out.sort((a, b) => b.s - a.s);
        return out.map(r => r.e);
    }

    function copy(entry) {
        if (!entry)
            return;
        // Decode through a pipe rather than into QML: image entries are binary
        // and would not survive a round trip through a JS string.
        Quickshell.execDetached([
            "sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", entry.id
        ]);
    }

    function remove(entry) {
        if (!entry)
            return;
        // `cliphist delete` reads the list-format line on stdin, which is
        // exactly the line we kept when parsing.
        Quickshell.execDetached([
            "sh", "-c", 'printf "%s\\n" "$1" | cliphist delete', "sh", entry.line
        ]);

        // Drop it locally too. Re-listing would race the delete, and the list
        // is rebuilt from scratch the next time the mode is opened anyway.
        const out = [];
        for (let i = 0; i < root.entries.length; i++)
            if (root.entries[i].id !== entry.id)
                out.push(root.entries[i]);
        root.entries = out;
    }

    Process {
        id: lister
        command: ["cliphist", "list"]

        // Named rather than using `this.text`: what `this` binds to inside a
        // QML signal handler is a detail worth not depending on.
        stdout: StdioCollector {
            id: listOutput
            onStreamFinished: root.parse(listOutput.text)
        }

        onExited: (code, status) => {
            if (code !== 0) {
                console.warn("Clip: cliphist list exited", code,
                             "— is cliphist installed and are the wl-paste watchers running?");
                root.loaded = true;
            }
        }
    }
}
