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

    // [{ id, line, preview, raw, image, format, thumbable }]
    //   preview — what the launcher shows; prettified for binary entries
    //   raw     — exactly what cliphist printed, which is what search reads
    property var entries: []
    property bool loaded: false

    // cliphist renders binary entries as `[[ binary data 41 KiB png 800x600 ]]`.
    readonly property var binaryMarker: /^\[\[\s*binary data/

    // The same line, pulled apart: size, format, dimensions. Kept separate from
    // the test above so a marker cliphist words differently still registers as
    // binary — it just does not get a pretty label.
    // ONE LINE on purpose: tests/launcher.js lifts `property <name>: <value>`
    // out of this file line by line, so a value wrapped onto the next line is
    // extracted as empty and the whole test run dies with a syntax error.
    readonly property var binaryParts: /^\[\[\s*binary data\s+([\d.]+\s*\w+)\s+(\w+)\s+(\d+)x(\d+)\s*\]\]/

    // Formats worth decoding to a file to show a thumbnail. A clipboard entry
    // can be any binary blob; decoding an arbitrary one to disk to hand to an
    // Image decoder is work with no payoff and a surprise waiting in it.
    readonly property var thumbable: ({ png: 1, jpg: 1, jpeg: 1, gif: 1, webp: 1, bmp: 1 })

    function refresh() {
        if (lister.running)
            return;
        // Thumbnails are dropped here rather than after parsing: an entry
        // cliphist has rotated out never comes back, so its decoded file is
        // dead weight, and clearing before the list arrives means no window
        // where a stale path is bound to a row that no longer exists.
        clearThumbs();
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
            const image = root.binaryMarker.test(preview);

            // Show "png · 800×600 · 41 KiB", not the raw marker. The marker is
            // cliphist telling itself something; it is not a description of
            // what you copied.
            let label = preview;
            let format = "";
            if (image) {
                const m = root.binaryParts.exec(preview);
                if (m) {
                    format = m[2].toLowerCase();
                    label = `${format} · ${m[3]}×${m[4]} · ${m[1]}`;
                }
            }

            out.push({
                id: line.slice(0, tab),
                line: line,
                preview: label,
                // The unmodified line still has to be searchable, or typing
                // "png" would match a row whose text no longer says it.
                raw: preview,
                image: image,
                format: format,
                thumbable: image && root.thumbable[format] === 1
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
            // Both, best of: `preview` is what you can see and `raw` is what
            // cliphist actually stored. Scoring only the prettified label would
            // make an image un-findable by typing what the row does not say;
            // scoring only the raw line would make it un-findable by typing
            // what the row DOES say.
            const s = Math.max(Fuzzy.score(q, e.preview), Fuzzy.score(q, e.raw));
            if (s >= 0)
                out.push({ e: e, s: s });
        }
        out.sort((a, b) => b.s - a.s);
        return out.map(r => r.e);
    }

    // ---- thumbnails ---------------------------------------------------------
    //
    // An Image needs a URL, and cliphist only hands out bytes on stdout, so the
    // bytes have to land in a file first. Decoded on demand — the launcher asks
    // for a row's thumbnail when that row is built — and cached by cliphist id,
    // which is stable for the life of an entry.
    //
    // One process at a time, from a queue. A clipboard with forty screenshots
    // in it would otherwise fork forty `cliphist decode` calls in the same
    // frame the moment you type `;`.

    // Quickshell's own per-shell cache dir, not a path assembled from
    // XDG_CACHE_HOME by hand: `cachePath()` is documented to return
    // `${Quickshell.cacheDir}/<path>`, and it already resolves the "usually
    // ~/.cache but not always" question that a hand-built path gets wrong on
    // exactly the machine where it matters.
    readonly property string cacheDir: Quickshell.cachePath("clip")

    // id -> "file:///…". Reassigned rather than mutated: a `var` holding an
    // object does not notify on property writes, so `thumbs[id] = x` would
    // update nothing that is bound to it.
    property var thumbs: ({})

    property var thumbQueue: []
    property string thumbBusy: ""

    function requestThumb(entry) {
        if (!entry || !entry.thumbable)
            return;
        const id = entry.id;
        if (thumbs[id] !== undefined || thumbBusy === id)
            return;
        if (thumbQueue.indexOf(id) !== -1)
            return;
        thumbQueue = thumbQueue.concat([id]);
        pumpThumbs();
    }

    function pumpThumbs() {
        if (thumbBusy !== "" || thumbQueue.length === 0)
            return;
        const id = thumbQueue[0];
        thumbQueue = thumbQueue.slice(1);
        thumbBusy = id;
        // The id goes in as a POSITIONAL ARGUMENT, never interpolated into the
        // script text — the same rule the rest of this file follows.
        decoder.command = [
            "sh", "-c",
            'mkdir -p "$1" && cliphist decode "$2" > "$1/$2"',
            "sh", root.cacheDir, id
        ];
        decoder.running = true;
    }

    Process {
        id: decoder
        onExited: (code, status) => {
            const id = root.thumbBusy;
            root.thumbBusy = "";
            if (id !== "") {
                // Cache the failure as an empty string too. Without it a
                // decode that cannot work is retried on every keystroke.
                root.thumbs = Object.assign({}, root.thumbs, {
                    [id]: code === 0 ? "file://" + root.cacheDir + "/" + id : ""
                });
            }
            root.pumpThumbs();
        }
    }

    // Entries do not come back once cliphist has rotated them out, so their
    // decoded files are dead weight. Cleared wholesale when the list is
    // re-read rather than diffed: the directory only ever holds what one
    // launcher session asked for, and `rm -rf` on a path we built ourselves is
    // cheaper to reason about than a per-file reconciliation.
    function clearThumbs() {
        root.thumbs = ({});
        root.thumbQueue = [];
        Quickshell.execDetached(["sh", "-c", 'rm -rf -- "$1"', "sh", root.cacheDir]);
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
