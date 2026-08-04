// System metrics, straight from /proc and /sys.
//
// POLLED ONLY WHILE `active`. Nothing here runs when the system monitor is
// closed — waking once a second to parse five files so a hidden panel can be
// up to date is exactly the battery cost this design exists to avoid.
//
// Everything is a DELTA between two samples. /proc counters are monotonic
// totals since boot, so the first tick after opening the panel produces no
// reading at all; that is correct, not a bug, and the UI shows a dash for it.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false

    // Samples of history kept for the sparklines. 60 at 1s is the last minute.
    readonly property int historyLength: 60

    // ---- cpu --------------------------------------------------------------

    // 0..1 for the package, and one entry per core.
    property real cpuUsage: 0
    property var coreUsage: []
    property var cpuHistory: []
    property real cpuTemp: -1        // °C, -1 when no sensor was found

    property var prevCpu: []
    property bool cpuPrimed: false

    function parseStat(text) {
        const lines = String(text || "").split("\n");
        const now = [];

        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].split(/\s+/);
            if (!f[0] || f[0].indexOf("cpu") !== 0)
                continue;

            // user nice system idle iowait irq softirq steal …
            let total = 0;
            for (let k = 1; k < f.length; k++) {
                const v = parseInt(f[k], 10);
                if (!isNaN(v))
                    total += v;
            }
            const idle = (parseInt(f[4], 10) || 0) + (parseInt(f[5], 10) || 0);
            now.push({ total: total, idle: idle });
        }

        if (root.prevCpu.length === now.length && now.length > 0) {
            const cores = [];
            for (let i = 0; i < now.length; i++) {
                const dt = now[i].total - root.prevCpu[i].total;
                const di = now[i].idle - root.prevCpu[i].idle;
                // A wrapped or unchanged counter reads as idle rather than as
                // a spike to 100%.
                const use = dt > 0 ? Math.max(0, Math.min(1, (dt - di) / dt)) : 0;
                if (i === 0)
                    root.cpuUsage = use;
                else
                    cores.push(use);
            }
            root.coreUsage = cores;
            root.cpuHistory = push(root.cpuHistory, root.cpuUsage);
            root.cpuPrimed = true;
        }

        root.prevCpu = now;
    }

    // ---- memory -----------------------------------------------------------

    property real memTotal: 0        // bytes
    property real memUsed: 0
    property real memCached: 0
    property real swapTotal: 0
    property real swapUsed: 0

    function parseMeminfo(text) {
        const v = {};
        const lines = String(text || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = /^(\w+):\s+(\d+)/.exec(lines[i]);
            if (m)
                v[m[1]] = parseInt(m[2], 10) * 1024;
        }

        root.memTotal = v.MemTotal || 0;
        root.memCached = (v.Cached || 0) + (v.SReclaimable || 0);

        // MemAvailable is the kernel's own estimate and is the only honest
        // "used" figure: total - free double-counts cache and reports 90% used
        // on a machine that is doing nothing.
        const avail = v.MemAvailable !== undefined ? v.MemAvailable : (v.MemFree || 0);
        root.memUsed = Math.max(0, root.memTotal - avail);

        root.swapTotal = v.SwapTotal || 0;
        root.swapUsed = Math.max(0, (v.SwapTotal || 0) - (v.SwapFree || 0));
    }

    // ---- network ----------------------------------------------------------

    // Bytes per second, summed over every real interface.
    property real netRx: 0
    property real netTx: 0
    property var netHistory: []
    property var prevNet: null

    // lo is not network traffic, and the virtual bridges docker and libvirt
    // create would double-count anything that crosses them.
    readonly property var netIgnore: /^(lo|docker|br-|virbr|veth|tun|tap)/

    function parseNetDev(text) {
        const lines = String(text || "").split("\n");
        let rx = 0;
        let tx = 0;

        for (let i = 0; i < lines.length; i++) {
            const colon = lines[i].indexOf(":");
            if (colon === -1)
                continue;
            const name = lines[i].slice(0, colon).trim();
            if (name === "" || root.netIgnore.test(name))
                continue;
            const f = lines[i].slice(colon + 1).trim().split(/\s+/);
            rx += parseInt(f[0], 10) || 0;
            tx += parseInt(f[8], 10) || 0;
        }

        if (root.prevNet !== null) {
            root.netRx = Math.max(0, rx - root.prevNet.rx);
            root.netTx = Math.max(0, tx - root.prevNet.tx);
            // One series, scaled to whichever direction is busier, so a 1 MB/s
            // download does not flatten a 20 kB/s upload into nothing.
            root.netHistory = push(root.netHistory, Math.max(root.netRx, root.netTx));
        }
        root.prevNet = { rx: rx, tx: tx };
    }

    // ---- disk throughput --------------------------------------------------

    property real diskRead: 0        // bytes per second
    property real diskWrite: 0
    property var prevDisk: null

    // Whole devices only. Counting partitions as well would double every
    // figure, since a write to nvme0n1p2 is also a write to nvme0n1.
    readonly property var diskWhole: /^(nvme\d+n\d+|sd[a-z]+|mmcblk\d+|vd[a-z]+)$/

    function parseDiskstats(text) {
        const lines = String(text || "").split("\n");
        let readSectors = 0;
        let writeSectors = 0;

        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].trim().split(/\s+/);
            if (f.length < 10 || !root.diskWhole.test(f[2]))
                continue;
            readSectors += parseInt(f[5], 10) || 0;
            writeSectors += parseInt(f[9], 10) || 0;
        }

        // Sectors in /proc/diskstats are always 512 bytes, regardless of the
        // device's real block size.
        const r = readSectors * 512;
        const w = writeSectors * 512;

        if (root.prevDisk !== null) {
            root.diskRead = Math.max(0, r - root.prevDisk.r);
            root.diskWrite = Math.max(0, w - root.prevDisk.w);
        }
        root.prevDisk = { r: r, w: w };
    }

    // ---- mounts and processes --------------------------------------------

    // [{ mount, size, used }]
    property var mounts: []
    // [{ pid, name, cpu, mem }]
    property var processes: []

    function parseDf(text) {
        const lines = String(text || "").split("\n");
        const out = [];
        for (let i = 1; i < lines.length; i++) {      // skip the header
            const f = lines[i].trim().split(/\s+/);
            if (f.length < 3)
                continue;
            const size = parseInt(f[1], 10);
            const used = parseInt(f[2], 10);
            if (isNaN(size) || size <= 0)
                continue;
            out.push({ mount: f[0], size: size, used: used });
        }
        out.sort((a, b) => b.size - a.size);
        root.mounts = out;
    }

    function parsePs(text) {
        const lines = String(text || "").split("\n");
        const out = [];
        for (let i = 0; i < lines.length && out.length < 8; i++) {
            const f = lines[i].trim().split(/\s+/);
            if (f.length < 4)
                continue;
            const pid = parseInt(f[0], 10);
            if (isNaN(pid))
                continue;
            out.push({
                pid: pid,
                name: f[1],
                cpu: parseFloat(f[2]) || 0,
                mem: parseFloat(f[3]) || 0
            });
        }
        root.processes = out;
    }

    function parseTemp(text) {
        const n = parseInt(String(text || "").trim(), 10);
        // Millidegrees. A sensor that reports nothing leaves this at -1 and the
        // UI omits the reading rather than showing 0°C.
        root.cpuTemp = isNaN(n) ? -1 : Math.round(n / 1000);
    }

    function kill(pid) {
        if (!pid)
            return;
        Quickshell.execDetached(["kill", String(pid)]);
    }

    // ---- helpers ----------------------------------------------------------

    function push(arr, value) {
        const out = arr.slice();
        out.push(value);
        while (out.length > root.historyLength)
            out.shift();
        return out;
    }

    function bytes(n) {
        if (!isFinite(n) || n < 0)
            return "—";
        const units = ["B", "K", "M", "G", "T"];
        let v = n;
        let u = 0;
        while (v >= 1024 && u < units.length - 1) {
            v /= 1024;
            u += 1;
        }
        return (u === 0 ? Math.round(v) : v.toFixed(v < 10 ? 1 : 0)) + units[u];
    }

    function rate(n) {
        return bytes(n) + "/s";
    }

    // ---- polling ----------------------------------------------------------

    onActiveChanged: {
        if (active) {
            // Drop the previous samples. Deltas against counters from the last
            // time the panel was open would produce one enormous first reading.
            prevCpu = [];
            prevNet = null;
            prevDisk = null;
            cpuPrimed = false;
            cpuHistory = [];
            netHistory = [];
            tick();
        }
    }

    function tick() {
        statFile.reload();
        memFile.reload();
        netFile.reload();
        diskFile.reload();
        if (!dfProc.running)
            dfProc.running = true;
        if (!psProc.running)
            psProc.running = true;
        if (!tempProc.running)
            tempProc.running = true;
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.active
        onTriggered: root.tick()
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        watchChanges: false
        onLoaded: root.parseStat(statFile.text())
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        watchChanges: false
        onLoaded: root.parseMeminfo(memFile.text())
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        watchChanges: false
        onLoaded: root.parseNetDev(netFile.text())
    }

    FileView {
        id: diskFile
        path: "/proc/diskstats"
        watchChanges: false
        onLoaded: root.parseDiskstats(diskFile.text())
    }

    // Filesystem usage needs statvfs, which QML has no access to. df is the
    // one place a process is unavoidable.
    Process {
        id: dfProc
        command: ["df", "-B1", "--output=target,size,used",
                  "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs", "-x", "overlay"]
        stdout: StdioCollector {
            id: dfOut
            onStreamFinished: root.parseDf(dfOut.text)
        }
        stderr: StdioCollector {}
    }

    // `=` suffixes suppress the header, so there is no line to skip and no
    // header text that could be mistaken for a process called "COMMAND".
    Process {
        id: psProc
        command: ["ps", "-eo", "pid=,comm=,pcpu=,pmem=", "--sort=-pcpu"]
        stdout: StdioCollector {
            id: psOut
            onStreamFinished: root.parsePs(psOut.text)
        }
        stderr: StdioCollector {}
    }

    // Which hwmon is the CPU differs by vendor and the numbering is not
    // stable across boots, so the sensor is found by NAME each time, with
    // thermal_zone0 as a last resort.
    Process {
        id: tempProc
        command: ["sh", "-c",
            'for h in /sys/class/hwmon/hwmon*; do ' +
            'case "$(cat "$h/name" 2>/dev/null)" in ' +
            'coretemp|k10temp|zenpower|acpitz) ' +
            'cat "$h/temp1_input" 2>/dev/null && exit 0;; esac; done; ' +
            'cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null']
        stdout: StdioCollector {
            id: tempOut
            onStreamFinished: root.parseTemp(tempOut.text)
        }
        stderr: StdioCollector {}
    }
}
