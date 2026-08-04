// Night light — hyprsunset, driven over its hyprctl IPC.
//
// Commands are exactly the ones in docs/hyprland/Hypr_Ecosystem_hyprsunset.md:
//
//   hyprctl hyprsunset temperature 2500   enable, warmer is lower
//   hyprctl hyprsunset identity           disable
//   hyprctl hyprsunset profile            print the active profile
//
// hyprsunset must already be running; conf/autostart.lua starts it. Setting a
// temperature with no daemon is not an error the shell can fix, so it is
// reported rather than worked around.
//
// STATE IS LOCAL, and deliberately so. `hyprctl hyprsunset profile` prints the
// active profile, but its output format is not documented and this repo cannot
// run it to find out — so the parser below is best-effort and its failure is
// not allowed to move the UI. What the user set is what the slider shows.
// Flagged rather than quietly assumed: if the readback turns out to work, the
// honest improvement is to trust it and delete the local copy.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Kelvin. 6000 is hyprsunset's neutral default; lower is warmer.
    readonly property int neutral: 6000
    readonly property int warmest: 2500
    readonly property int coolest: 6500

    property int temperature: neutral
    property bool enabled: false
    property string error: ""

    function enable(kelvin) {
        const k = Math.round(Math.max(root.warmest, Math.min(root.coolest, kelvin)));
        root.temperature = k;
        root.enabled = true;
        run(["hyprctl", "hyprsunset", "temperature", String(k)]);
    }

    function disable() {
        root.enabled = false;
        run(["hyprctl", "hyprsunset", "identity"]);
    }

    function setEnabled(on) {
        if (on)
            enable(root.temperature);
        else
            disable();
    }

    function run(argv) {
        proc.exec({ command: argv });
    }

    // Best-effort readback. Pulls the first 4-digit Kelvin-looking number out of
    // whatever `profile` prints. If nothing matches, the local state stands.
    function readback(text) {
        const m = /temperature[^0-9]*([0-9]{4})/i.exec(String(text || ""));
        if (!m)
            return;
        const k = parseInt(m[1], 10);
        if (isNaN(k))
            return;
        root.temperature = k;
        root.enabled = k < root.neutral;
    }

    function refresh() {
        profileProc.running = true;
    }

    Process {
        id: proc
        stderr: StdioCollector { id: procErr }
        onExited: (code, status) => {
            if (code === 0) {
                root.error = "";
                return;
            }
            root.error = "hyprsunset is not running";
            console.warn("Sunset: hyprctl hyprsunset failed:", procErr.text.trim());
        }
    }

    Process {
        id: profileProc
        command: ["hyprctl", "hyprsunset", "profile"]
        stdout: StdioCollector {
            id: profileOut
            onStreamFinished: root.readback(profileOut.text)
        }
        stderr: StdioCollector {}
    }
}
