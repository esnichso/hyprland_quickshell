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
    // What players actually put in mpris:artUrl varies more than the spec
    // suggests, and QML Image renders nothing at all for a source it cannot
    // resolve — no warning, just an empty square:
    //
    //   Spotify, mpv     file:///... or a local cache path with NO scheme
    //   browsers         https://... (a YouTube poster frame, a track cover)
    //   some players     data:image/...;base64,...
    //
    // Image handles all three, but only if the string is a URL. A bare
    // filesystem path is the one case that needs fixing up here.
    readonly property string artUrl: {
        const raw = player && player.trackArtUrl ? String(player.trackArtUrl) : "";
        if (raw === "")
            return "";
        if (raw.indexOf("://") !== -1 || raw.indexOf("data:") === 0)
            return raw;
        return raw.charAt(0) === "/" ? "file://" + raw : "";
    }

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

    // Relative seek. `next`/`previous` change TRACK — this moves within one,
    // which is the thing a video or a long track actually needs.
    //
    // Assigning `position` is an absolute seek, so the arithmetic happens here.
    // Clamped at both ends: seeking past the end is how some players stop
    // dead instead of advancing, and a negative position is undefined.
    function seekBy(delta) {
        if (!canSeek)
            return;
        let target = position + delta;
        if (target < 0)
            target = 0;
        // A stream reports length 0 or -1; there is no end to clamp against.
        if (length > 0 && target > length - 1)
            target = length - 1;
        player.position = target;
    }

    // 0-1 of the track, for a scrub bar. Guards the streams that report no
    // length, where a fraction is meaningless rather than zero.
    function seekToFraction(f) {
        if (length > 0)
            seek(Math.max(0, Math.min(1, f)) * length);
    }

    // mm:ss. Guards against the -1 that players report for streams of unknown
    // length, which would otherwise render as "-1:-1".
    function fmt(sec) {
        if (!isFinite(sec) || sec < 0) return "--:--";
        const m = Math.floor(sec / 60);
        const s = Math.floor(sec % 60);
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }
}
