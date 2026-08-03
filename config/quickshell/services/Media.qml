// Media — MPRIS players.
//
// Picks one "active" player rather than showing all of them: whichever is
// playing, preferring the one that most recently started. Spotify, a browser tab
// and mpv can all be registered at once, and controls that drive an ambiguous
// target are worse than controls that drive the obvious one. The dashboard shows
// a switcher when there is more than one.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values

    readonly property bool any: players.length > 0
    readonly property bool multiple: players.length > 1

    // Explicit user choice from the dashboard switcher, if any.
    property var chosen: null

    readonly property var player: {
        if (chosen && players.indexOf(chosen) !== -1) return chosen;
        const playing = players.find(p => p && p.isPlaying);
        if (playing) return playing;
        return players.length > 0 ? players[0] : null;
    }

    readonly property bool playing: player !== null && player.isPlaying

    readonly property string title: player && player.trackTitle ? player.trackTitle : ""
    readonly property string artist: player && player.trackArtist ? player.trackArtist : ""
    readonly property string album: player && player.trackAlbum ? player.trackAlbum : ""
    readonly property string artUrl: player && player.trackArtUrl ? player.trackArtUrl : ""

    readonly property real position: player ? player.position : 0
    readonly property real length: player ? player.length : 0

    readonly property bool canNext: player !== null && player.canGoNext
    readonly property bool canPrev: player !== null && player.canGoPrevious
    readonly property bool canSeek: player !== null && player.canSeek

    function toggle()   { if (player && player.canControl) player.togglePlaying(); }
    function next()     { if (canNext) player.next(); }
    function previous() { if (canPrev) player.previous(); }
    function seek(sec)  { if (canSeek) player.position = sec; }
    function choose(p)  { chosen = p; }

    // mm:ss. Guards against the -1 that players report for streams of unknown
    // length, which would otherwise render as "-1:-1".
    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) return "--:--";
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }
}
