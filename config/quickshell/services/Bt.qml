// Bluetooth — BlueZ over D-Bus, through Quickshell.Bluetooth.
//
// Named Bt, not Bluetooth: a singleton with the same name as the module's own
// singleton would shadow it inside this directory and every reference would
// silently resolve to the wrong one.
//
// DISCOVERY IS NOT FREE either — see Net.qml. adapter.discovering is turned on
// when the bluetooth tab opens and off when it closes.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth

Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter

    // A VM has no adapter at all, which is a different thing from an adapter
    // that is switched off — the tab says so rather than showing a dead toggle.
    readonly property bool available: adapter !== null
    readonly property bool enabled: available && adapter.enabled
    readonly property bool discovering: available && adapter.discovering

    readonly property var all: available ? adapter.devices.values : []

    // Paired devices first — those are the ones you came here to reconnect.
    // Within each group, connected first, then by name, so the list does not
    // reshuffle as discovery finds things.
    readonly property var devices: {
        const out = all.slice();
        out.sort((a, b) => {
            if (a.bonded !== b.bonded)
                return a.bonded ? -1 : 1;
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return label(a).localeCompare(label(b));
        });
        return out;
    }

    readonly property var connected: all.filter(d => d && d.connected)
    readonly property bool anyConnected: connected.length > 0

    // `name` is the user's alias and may be empty; deviceName is what the
    // device calls itself. Falling through to the address means a device with
    // neither still renders as something you can click.
    function label(d) {
        if (!d)
            return "";
        return d.name || d.deviceName || d.address || "(unknown)";
    }

    function setEnabled(on) {
        if (available)
            adapter.enabled = on;
    }

    function setDiscovering(on) {
        // Discovery on a powered-off adapter is not an error worth surfacing,
        // it just does nothing — but asking for it would leave the toggle on.
        if (available && adapter.enabled)
            adapter.discovering = on;
    }

    function toggleConnection(d) {
        if (!d)
            return;
        if (d.connected)
            d.disconnect();
        else
            d.connect();
    }
}
