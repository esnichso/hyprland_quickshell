// Screen and keyboard backlight.
//
// Reads through `brightnessctl -m` rather than poking sysfs directly, because
// brightnessctl already solves device discovery — the backlight device is
// intel_backlight here but amdgpu_bl0 or acpi_video0 elsewhere, and the
// keyboard LED name varies by vendor.
//
// This service is POLLED ON DEMAND, not watched. sysfs attributes do not
// reliably emit inotify events, so a FileView watching them would work on some
// kernels and silently never fire on others. The keybinds tell the shell when
// they changed something (see conf/binds.lua); everything else refreshes when
// a panel opens.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Percentages, 0-100. -1 means "no such device", which is the normal case
    // for the keyboard backlight in a VM.
    property int screen: -1
    property int keyboard: -1

    readonly property bool hasScreen: screen >= 0
    readonly property bool hasKeyboard: keyboard >= 0

    function refresh() {
        screenProc.running = true;
        kbdProc.running = true;
    }

    function setScreen(pct) {
        setProc.command = ["brightnessctl", "set", `${Math.round(pct)}%`];
        setProc.running = true;
    }

    function setKeyboard(pct) {
        setProc.command = ["brightnessctl", "-d", "*kbd_backlight", "set", `${Math.round(pct)}%`];
        setProc.running = true;
    }

    // brightnessctl -m prints one CSV line:
    //   intel_backlight,backlight,60000,50%,120000
    // Field 4 is the percentage with a trailing %.
    function parsePercent(text) {
        const line = text.trim().split("\n")[0];
        if (!line) return -1;
        const f = line.split(",");
        if (f.length < 4) return -1;
        const n = parseInt(f[3].replace("%", ""), 10);
        return isNaN(n) ? -1 : n;
    }

    Process {
        id: screenProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: root.screen = root.parsePercent(text)
        }
    }

    Process {
        id: kbdProc
        command: ["brightnessctl", "-m", "-d", "*kbd_backlight"]
        stdout: StdioCollector {
            onStreamFinished: root.keyboard = root.parsePercent(text)
        }
        // Exits non-zero when there is no such device. That is not an error
        // worth logging on every refresh — it is the expected answer in a VM.
        stderr: StdioCollector {}
    }

    Process {
        id: setProc
        onExited: root.refresh()
    }

    Component.onCompleted: refresh()
}
