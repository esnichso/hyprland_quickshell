// Audio — the default sink and source, and nothing else.
//
// Reads PipeWire's *default* devices rather than a fixed node, so volume
// follows when you plug in headphones. Every consumer in the shell binds here
// instead of instantiating its own tracker.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // `audio` is only populated once the node is bound by a tracker, hence the
    // guards. Both can also be briefly null while devices change.
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false

    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    readonly property bool ready: sink !== null && sink.audio !== null

    // 0-1, matching PipeWire. Values above 1 are allowed and mean software
    // amplification, which is why the OSD colours the bar past 100%.
    function setVolume(v) {
        if (!sink || !sink.audio) return;
        sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function stepVolume(delta) {
        setVolume(volume + delta);
    }

    function toggleMute() {
        if (sink && sink.audio) sink.audio.muted = !sink.audio.muted;
    }

    function toggleMicMute() {
        if (source && source.audio) source.audio.muted = !source.audio.muted;
    }

    // ---- device and stream lists ------------------------------------------
    //
    // Only populated while `detailed` is set, which the control centre's audio
    // tab does while it is open. See the tracker below for why.

    property bool detailed: false

    // isStream separates a program from a hardware device; isSink separates an
    // output from an input. The stream list is NOT split by direction: what
    // isSink means for a stream (the app's own port, or the device it feeds)
    // is not something this repo can check without a session, and a recording
    // app in the applications list is a cosmetic wrong at worst.
    readonly property var sinks: audioNodes(n => !n.isStream && n.isSink)
    readonly property var sources: audioNodes(n => !n.isStream && !n.isSink)
    readonly property var streams: audioNodes(n => n.isStream)

    function audioNodes(pred) {
        if (!root.detailed)
            return [];
        return Pipewire.nodes.values.filter(n => n && n.audio && pred(n));
    }

    // nickname is a friendly name and is often empty; description is what
    // pavucontrol shows; name is the raw node.name and always exists.
    function label(n) {
        if (!n)
            return "";
        if (n.isStream && n.properties) {
            const app = n.properties["application.name"];
            if (app)
                return app;
        }
        return n.description || n.nickname || n.name || "";
    }

    function iconName(n) {
        if (n && n.isStream && n.properties) {
            const icon = n.properties["application.icon-name"];
            if (icon)
                return icon;
        }
        return "";
    }

    function setNodeVolume(n, v) {
        if (n && n.audio)
            n.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleNodeMute(n) {
        if (n && n.audio)
            n.audio.muted = !n.audio.muted;
    }

    function makeDefaultSink(n)   { Pipewire.preferredDefaultAudioSink = n; }
    function makeDefaultSource(n) { Pipewire.preferredDefaultAudioSource = n; }

    // ONE tracker for the whole shell. Binding is what makes `.audio` valid —
    // without it these nodes report nothing and every property above silently
    // reads its fallback.
    //
    // At rest it binds only the default sink and source, which is all the bar
    // needs. While the audio tab is open it binds EVERY node, deliberately
    // without filtering first: `audio` is the property that identifies an audio
    // node, and it is only populated once bound, so filtering on it beforehand
    // would return nothing and nothing would ever be bound.
    //
    // A second tracker would be the obvious alternative and is the wrong one:
    // two trackers on overlapping nodes is redundant work and a way for two
    // components to end up disagreeing about the same volume.
    PwObjectTracker {
        objects: {
            const base = [root.sink, root.source].filter(o => o !== null);
            if (!root.detailed)
                return base;
            return Pipewire.nodes.values.filter(n => n !== null);
        }
    }
}
