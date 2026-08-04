// Desktop entries, ranked, plus the frecency store that ranks them.
//
// DesktopEntries is a native Quickshell model — no scanning /usr/share
// /applications by hand and no re-parsing on a timer. It already excludes
// Hidden and NoDisplay entries.
//
// Launching goes through `uwsm app --` so the application lands in its own
// systemd scope. Without it every app you start is a child of the shell, and
// restarting the shell takes your editor with it.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "root:/"
import "root:/services"

Singleton {
    id: root

    readonly property var all: DesktopEntries.applications

    // Frecency half-life. 30 days means an app you used daily last month still
    // outranks one you opened once yesterday, but a phase of the project you
    // have moved on from fades out instead of sitting at the top forever.
    readonly property real halfLifeDays: 30

    // Ranked entries for a query. An empty query returns everything sorted by
    // frecency alone, which is what makes the bare launcher useful.
    function rank(query) {
        const q = String(query || "").trim();
        const items = root.all.values;
        const out = [];

        for (let i = 0; i < items.length; i++) {
            const e = items[i];
            let s = 0;

            if (q !== "") {
                s = Fuzzy.best(q, [
                    [e.name, 0],
                    [e.genericName, 8],
                    [joined(e.keywords), 14],
                    [joined(e.categories), 22],
                    [e.execString, 20]
                ]);
                if (s < 0)
                    continue;
            }

            out.push({ entry: e, score: s + frecency(e.id) });
        }

        out.sort((a, b) => b.score - a.score);
        return out.map(r => r.entry);
    }

    function joined(list) {
        if (!list || list.length === 0)
            return "";
        let s = "";
        for (let i = 0; i < list.length; i++)
            s += (i > 0 ? " " : "") + list[i];
        return s;
    }

    function launch(entry) {
        if (!entry)
            return;
        record(entry.id);

        const argv = ["uwsm", "app", "--"];

        // runInTerminal entries (htop, a TUI mail client) have no window of
        // their own. DesktopEntry.execute() explicitly ignores this flag, which
        // is why launching goes through here instead.
        if (entry.runInTerminal) {
            argv.push(Config.launcher.terminal);
            argv.push("-e");
        }

        // A manual loop, not a spread: entry.command is a QML list<string> and
        // whether it spreads is not something this repo can check locally.
        for (let i = 0; i < entry.command.length; i++)
            argv.push(entry.command[i]);

        if (entry.workingDirectory)
            Quickshell.execDetached({ command: argv, workingDirectory: entry.workingDirectory });
        else
            Quickshell.execDetached(argv);
    }

    // ---- frecency ---------------------------------------------------------
    //
    // One number per app: a use count that decays with time. On each launch the
    // stored score is decayed to now and 1 is added, so a score always means
    // "uses, as of the timestamp beside it". Ranking decays it again at query
    // time, which is what keeps the ordering correct between launches without
    // rewriting the file on a timer.

    function nowDays() {
        return Date.now() / 86400000;
    }

    function decayed(rec) {
        return rec.s * Math.pow(0.5, (nowDays() - rec.t) / root.halfLifeDays);
    }

    function frecency(id) {
        const rec = store.apps[id];
        if (!rec)
            return 0;
        // Logarithmic: frecency breaks ties and floats favourites to the top of
        // an empty query, but must never outrank a clearly better text match.
        return 20 * Math.log(1 + decayed(rec));
    }

    function record(id) {
        if (!id)
            return;
        const rec = store.apps[id];
        const next = {};

        // Copy rather than mutate in place: a `var` property holding the same
        // object reference does not notify, and the write would not persist.
        for (const k in store.apps)
            next[k] = store.apps[k];

        next[id] = { s: (rec ? decayed(rec) : 0) + 1, t: nowDays() };
        store.apps = next;
        frecencyFile.writeAdapter();
    }

    FileView {
        id: frecencyFile
        path: `${Quickshell.env("HOME")}/.local/state/quickshell/frecency.json`

        // Not watched. Nothing else writes this file, and reloading it on our
        // own write would be a loop.
        watchChanges: false

        // Unlike settings.json, this file SHOULD be created if missing — it is
        // shell state, not user configuration, and a fresh machine has no
        // launch history by definition. The directory is created by
        // install.sh --link.
        onLoadFailed: err => frecencyFile.writeAdapter()
        onSaveFailed: err => console.warn("Apps: could not write frecency.json:", err)

        JsonAdapter {
            id: store
            // { "<desktop id>": { s: <decayed uses>, t: <days since epoch> } }
            property var apps: ({})
        }
    }
}
