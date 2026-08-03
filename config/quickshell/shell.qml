// hypersetup2 — the shell.
//
// One process draws every surface. This is the only entry point; run it with
//   qs -c hypersetup2
// Saving any QML file below hot-reloads it.
//
// PHASE 1 SCOPE: the bar only. The notch renders its resting clock and nothing
// else; the panels do not exist yet. The IpcHandler below accepts the calls the
// keybinds make so they log something useful instead of failing silently.

import Quickshell
import Quickshell.Io
import "root:/bar"

ShellRoot {
    // One bar per screen. On a laptop that is one; the Variants wrapper means
    // docking a monitor does not need a code change.
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    // Panel IPC. Every keybind in conf/binds.lua routes through here:
    //   qs -c hypersetup2 ipc call panels toggle <name>
    // One mechanism for every panel, so adding a panel never means inventing a
    // new one.
    IpcHandler {
        target: "panels"

        function toggle(name: string): string {
            // Phase 2 wires these to real surfaces.
            console.log(`panels.toggle(${name}) — not implemented yet`);
            return `not-implemented: ${name}`;
        }
    }
}
