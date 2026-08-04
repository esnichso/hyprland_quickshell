// Ending the session — and the two facts worth knowing before you do.
//
// EVERY destructive action goes through `hyprshutdown`, which asks applications
// to exit rather than killing them. `hl.dsp.exit()` and a bare `systemctl
// reboot` both take your editor's unsaved buffer with them.
//
// hyprshutdown is NOT a menu. Its name says otherwise and v1 lost a round trip
// to that: binding it directly logs you straight out. It opens a progress
// dialog, closes apps, quits Hyprland, and then runs `--post-cmd`. The flags
// below are from docs/hyprland/Hypr_Ecosystem_hyprshutdown.md, not from memory.
//
// No `--vt`: that flag exists for NVIDIA + SDDM black screens, and this machine
// has an Intel iGPU. CLAUDE.md says no NVIDIA workarounds anywhere.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property int uptimeSeconds: 0

    // Anything holding a sleep or idle lock. Worth surfacing next to Suspend:
    // a running backup or a video call will silently prevent it, and a suspend
    // that does nothing looks like a broken button.
    property int inhibitors: 0
    property string inhibitorWho: ""

    function refresh() {
        uptimeFile.reload();
        if (!inhibitProc.running)
            inhibitProc.running = true;
    }

    // ---- actions ----------------------------------------------------------

    function lock() {
        Quickshell.execDetached(["hyprlock"]);
    }

    // Apps are asked to exit, then Hyprland quits. No post-command: quitting
    // the compositor IS the logout.
    function logout() {
        Quickshell.execDetached(["hyprshutdown", "-t", "Logging out…"]);
    }

    // Suspend does not end the session, so it does not go through
    // hyprshutdown. systemctl rather than a bare `suspend` so it runs through
    // polkit and needs no password.
    function suspend() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function reboot() {
        Quickshell.execDetached([
            "hyprshutdown", "-t", "Restarting…", "--post-cmd", "systemctl reboot"
        ]);
    }

    function poweroff() {
        Quickshell.execDetached([
            "hyprshutdown", "-t", "Shutting down…", "--post-cmd", "systemctl poweroff"
        ]);
    }

    // ---- uptime -----------------------------------------------------------

    // /proc/uptime is "<seconds up> <seconds idle>", both as floats.
    function parseUptime(text) {
        const first = String(text || "").trim().split(" ")[0];
        const n = parseFloat(first);
        root.uptimeSeconds = isNaN(n) ? 0 : Math.floor(n);
    }

    function uptimeText() {
        const s = root.uptimeSeconds;
        if (s <= 0)
            return "";
        const d = Math.floor(s / 86400);
        const h = Math.floor((s % 86400) / 3600);
        const m = Math.floor((s % 3600) / 60);
        if (d > 0)
            return `up ${d}d ${h}h`;
        if (h > 0)
            return `up ${h}h ${m}m`;
        return `up ${m}m`;
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        // procfs does not emit change notifications, and this is read when the
        // power menu opens rather than continuously.
        watchChanges: false
        onLoaded: root.parseUptime(uptimeFile.text())
        onLoadFailed: err => console.warn("Session: could not read /proc/uptime:", err)
    }

    // ---- inhibitors -------------------------------------------------------

    // `systemd-inhibit --list` prints a table whose exact columns and header
    // have changed between systemd releases, so this counts lines mentioning a
    // sleep or idle lock rather than parsing by position. A miscount shows the
    // wrong number next to Suspend; a positional parser would show nonsense.
    function parseInhibitors(text) {
        const lines = String(text || "").split("\n");
        let n = 0;
        let who = "";
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.trim() === "" || line.indexOf("inhibitor") !== -1)
                continue;
            if (!/\b(sleep|idle|shutdown)\b/.test(line))
                continue;
            n += 1;
            if (who === "")
                who = line.trim().split(/\s+/)[0];
        }
        root.inhibitors = n;
        root.inhibitorWho = who;
    }

    Process {
        id: inhibitProc
        command: ["systemd-inhibit", "--list"]
        stdout: StdioCollector {
            id: inhibitOut
            onStreamFinished: root.parseInhibitors(inhibitOut.text)
        }
        stderr: StdioCollector {}
        onExited: (code, status) => {
            if (code !== 0) {
                root.inhibitors = 0;
                root.inhibitorWho = "";
            }
        }
    }
}
