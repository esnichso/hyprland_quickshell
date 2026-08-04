// hypersetup2 — the shell.
//
// One process draws every surface. This is the only entry point:
//   qs
// Saving any QML file below hot-reloads it.
//
// No `-c`: config/quickshell is symlinked to ~/.config/quickshell, so shell.qml
// sits at the base of that directory and quickshell registers it as the default
// config, ignoring subdirectories entirely.
//
// PHASE 2e: the bar, the notch and the launcher. The remaining panels (control
// centre, power, sysmon, wallpaper) are not built yet; their IPC calls are
// accepted and report that they are unimplemented rather than failing silently.

import Quickshell
import Quickshell.Io
import "root:/"
import "root:/bar"
import "root:/control"
import "root:/launcher"
import "root:/services"

ShellRoot {
    id: root

    // One bar per screen. A laptop has one; the Variants wrapper means docking
    // a monitor is not a code change.
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    // One launcher, not one per screen: it follows the focused monitor. Two
    // instances would both take exclusive keyboard focus and one of them would
    // win by luck.
    Launcher {}

    // Same reasoning as the launcher: one instance, following the focused
    // monitor, because two would both take exclusive keyboard focus.
    ControlCentre {}

    // Every panel keybind in conf/binds.lua routes through here:
    //   qs ipc call panels toggle <name>
    IpcHandler {
        target: "panels"

        function toggle(name: string): string {
            // Built surfaces go through the Panels singleton. Everything else
            // is named but not yet drawn.
            const built = ["dashboard", "notifications", "media",
                           "launcher", "clipboard", "emoji", "control"];

            if (name === "dnd") {
                Notifs.toggleDnd();
                return Config.dnd ? "dnd on" : "dnd off";
            }
            if (name === "clear") {
                Notifs.clearAll();
                return "ok";
            }
            if (built.indexOf(name) !== -1) {
                return Panels.toggle(name) ? "open" : "closed";
            }

            console.log(`panels.toggle(${name}) — not implemented yet`);
            return `not-implemented: ${name}`;
        }

        function close(): string {
            Panels.closeAll();
            return "ok";
        }
    }

    IpcHandler {
        target: "osd"

        // Brightness and keyboard backlight are PUSHED here by the keybind,
        // because sysfs does not reliably emit change notifications — watching
        // it would work on some kernels and silently never fire on others.
        // Volume needs no equivalent: the shell sees PipeWire change directly.
        function show(kind: string): string {
            Osd.show(kind);
            return "ok";
        }
    }
}
