// OSD state.
//
// Two trigger paths, chosen per source for a reason:
//
//   Volume and mic are REACTIVE — the shell watches PipeWire and shows the OSD
//   whenever the level changes, no matter who changed it. Adjusting volume from
//   a player or another tool gets the same feedback as the media keys.
//
//   Brightness is PUSHED by the keybind over IPC, because sysfs does not
//   reliably emit change notifications. Watching it would work on some kernels
//   and silently never fire on others, which is worse than not watching.

pragma Singleton

import QtQuick
import Quickshell
import "root:/"
import "root:/services"

Singleton {
    id: root

    // "", "volume", "mic", "brightness", "keyboard"
    property string kind: ""
    readonly property bool active: kind !== ""

    readonly property real value: {
        switch (kind) {
        case "volume":     return Audio.muted ? 0 : Audio.volume;
        case "mic":        return Audio.micMuted ? 0 : 1;
        case "brightness": return Brightness.screen / 100;
        case "keyboard":   return Brightness.keyboard / 100;
        }
        return 0;
    }

    readonly property string label: {
        switch (kind) {
        case "volume":     return Audio.muted ? "muted" : `${Math.round(Audio.volume * 100)}%`;
        case "mic":        return Audio.micMuted ? "muted" : "live";
        case "brightness": return `${Brightness.screen}%`;
        case "keyboard":   return Brightness.keyboard <= 0 ? "off"
                                : Brightness.keyboard >= 66 ? "high" : "low";
        }
        return "";
    }

    readonly property string glyph: {
        switch (kind) {
        case "volume":     return Audio.muted ? "" : "";  // volume-off / volume-up
        case "mic":        return Audio.micMuted ? "" : "";
        case "brightness": return "";                            // sun
        case "keyboard":   return "";                            // keyboard
        }
        return "";
    }

    // Over 100% is software amplification — worth flagging, it distorts.
    readonly property bool warn: kind === "volume" && Audio.volume > 1.0

    function show(what) {
        if (what === "brightness" || what === "keyboard") Brightness.refresh();
        kind = what;
        timer.restart();
    }

    Timer {
        id: timer
        interval: Config.notch.osdMs
        onTriggered: root.kind = ""
    }

    // Reactive volume. `armed` suppresses the burst of property changes that
    // happens while PipeWire nodes bind at startup — without it the shell
    // greets you with a volume OSD every login.
    property bool armed: false

    Timer {
        running: true
        interval: 2000
        onTriggered: root.armed = true
    }

    Connections {
        target: Audio
        function onVolumeChanged() { if (root.armed) root.show("volume"); }
        function onMutedChanged()  { if (root.armed) root.show("volume"); }
        function onMicMutedChanged() { if (root.armed) root.show("mic"); }
    }
}
