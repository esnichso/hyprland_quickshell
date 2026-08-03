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

    // Binding is what makes `.audio` valid. Without a tracker these nodes
    // report nothing and every property above silently reads its fallback.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(o => o !== null)
    }
}
