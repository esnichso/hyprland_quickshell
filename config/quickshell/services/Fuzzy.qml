// Fuzzy subsequence matching, shared by every launcher mode.
//
// A singleton rather than a .js library because the singleton pattern is
// already proven in this repo and a relative .js import is not — and QML cannot
// be parsed on the dev host, so an import that resolves differently than
// expected would only surface in the VM.
//
// score() returns a number where higher is better and -1 means "no match at
// all". The scale is arbitrary; only the ordering matters. Callers subtract a
// constant to rank one field below another (matching the name beats matching
// the exec line) rather than multiplying, so a strong match in a weak field can
// still beat a weak match in a strong one.

pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Characters after which a match counts as starting a word. Matching the
    // "f" of "Web Browser"'s second word should beat matching the "f" buried
    // inside "Preferences".
    readonly property string boundaries: " -_./:()[]"

    function score(needle, haystack) {
        if (!needle)
            return 0;
        if (!haystack)
            return -1;

        const n = String(needle).toLowerCase();
        const h = String(haystack).toLowerCase();
        if (n.length > h.length)
            return -1;

        let at = 0;         // next index in the haystack to search from
        let streak = 0;     // how many chars have matched back-to-back
        let total = 0;

        for (let i = 0; i < n.length; i++) {
            const c = n.charAt(i);

            let found = -1;
            for (let k = at; k < h.length; k++) {
                if (h.charAt(k) === c) {
                    found = k;
                    break;
                }
            }
            if (found === -1)
                return -1;

            let s = 10;

            if (found === 0)
                s += 25;
            else if (root.boundaries.indexOf(h.charAt(found - 1)) !== -1)
                s += 18;

            if (found === at && i > 0) {
                streak += 1;
                s += 12 + streak * 4;
            } else {
                streak = 0;
            }

            // Distance penalty, capped: one long gap should not make a match
            // score worse than no match at all.
            s -= Math.min(found - at, 12);

            total += s;
            at = found + 1;
        }

        // Shorter haystacks win ties, so "Files" ranks above "Files Settings".
        total -= Math.min(h.length - n.length, 30) * 0.4;
        return total;
    }

    // Best score across several fields, each with its own penalty.
    // fields is [[text, penalty], ...]. Returns -1 if nothing matched.
    function best(needle, fields) {
        let out = -1;
        for (let i = 0; i < fields.length; i++) {
            const s = score(needle, fields[i][0]);
            if (s < 0)
                continue;
            const v = s - fields[i][1];
            if (out === -1 || v > out)
                out = v;
        }
        return out;
    }
}
