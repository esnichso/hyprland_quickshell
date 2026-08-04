// Networking — NetworkManager over D-Bus, through Quickshell.Networking.
//
// This is the module that makes the control centre worth building. A year ago
// this meant scraping `nmcli dev wifi list` on a timer; now it is a bindable
// model that updates itself.
//
// SCANNING IS NOT FREE. WifiDevice.scannerEnabled makes the radio sweep
// continuously, which costs power on a laptop. It is turned on when the network
// tab opens and off when it closes — never at startup.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

Singleton {
    id: root

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifiBlocked: !Networking.wifiHardwareEnabled

    readonly property var wifiDevice: deviceOfType(DeviceType.Wifi)
    readonly property var wiredDevice: deviceOfType(DeviceType.Wired)

    readonly property bool hasWifi: wifiDevice !== null
    readonly property bool wiredConnected: wiredDevice !== null && wiredDevice.connected

    function deviceOfType(want) {
        const d = Networking.devices.values;
        for (let i = 0; i < d.length; i++)
            if (d[i] && d[i].type === want)
                return d[i];
        return null;
    }

    // Every visible access point, best first: the connected one, then saved
    // networks, then by signal strength. Sorting by strength alone buries the
    // network you are actually on when you walk away from the router.
    readonly property var networks: {
        if (!wifiDevice)
            return [];

        const all = wifiDevice.networks.values.filter(n => n && n.name !== "");
        const out = all.slice();

        out.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.known !== b.known)
                return a.known ? -1 : 1;
            return strength(b) - strength(a);
        });
        return out;
    }

    readonly property var active: {
        for (let i = 0; i < networks.length; i++)
            if (networks[i].connected)
                return networks[i];
        return null;
    }

    // A wired link outranks wifi for what the bar shows: if the cable is in,
    // that is the connection you are using.
    readonly property string mode:
        wiredConnected ? "wired"
        : !wifiEnabled ? "off"
        : active !== null ? "wifi"
        : "down"

    // 0..1. Only WifiNetwork carries signalStrength; the base Network type does
    // not, so this is guarded rather than assumed.
    function strength(n) {
        return n && n.signalStrength !== undefined ? n.signalStrength : 0;
    }

    // Which of the five wifi arcs to draw. Kept here rather than in the bar so
    // the island and the control centre cannot disagree.
    function bars(n) {
        const s = strength(n);
        if (s >= 0.8) return 4;
        if (s >= 0.55) return 3;
        if (s >= 0.3) return 2;
        if (s > 0) return 1;
        return 0;
    }

    function secured(n) {
        return n && n.security !== undefined
            && n.security !== WifiSecurityType.Open
            && n.security !== WifiSecurityType.Owe
            && n.security !== WifiSecurityType.Unknown;
    }

    function securityLabel(n) {
        if (!n || n.security === undefined)
            return "";
        switch (n.security) {
        case WifiSecurityType.Open:          return "Open";
        case WifiSecurityType.Owe:           return "Open (OWE)";
        case WifiSecurityType.StaticWep:
        case WifiSecurityType.DynamicWep:    return "WEP";
        case WifiSecurityType.WpaPsk:        return "WPA";
        case WifiSecurityType.Wpa2Psk:       return "WPA2";
        case WifiSecurityType.Sae:           return "WPA3";
        case WifiSecurityType.WpaEap:
        case WifiSecurityType.Wpa2Eap:       return "Enterprise";
        case WifiSecurityType.Wpa3SuiteB192: return "WPA3 Enterprise";
        case WifiSecurityType.Leap:          return "LEAP";
        }
        return "";
    }

    // Enterprise networks need a certificate and identity flow that this panel
    // does not implement. Saying so beats a password box that cannot work.
    function enterprise(n) {
        return n && (n.security === WifiSecurityType.WpaEap
                  || n.security === WifiSecurityType.Wpa2Eap
                  || n.security === WifiSecurityType.Wpa3SuiteB192);
    }

    function setWifiEnabled(on) {
        Networking.wifiEnabled = on;
    }

    function setScanning(on) {
        if (wifiDevice)
            wifiDevice.scannerEnabled = on;
    }
}
