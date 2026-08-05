// The notification daemon.
//
// Registering this means QuickShell owns org.freedesktop.Notifications. swaync,
// dunst and mako must not be installed — two owners of that name is a coin flip
// at login, and the loser fails in a way that looks like a shell bug.
//
// History is `server.trackedNotifications`, not a parallel ListModel. Keeping
// one source means "dismiss" cannot leave a row behind in a copy.

pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "root:/"

Singleton {
    id: root

    readonly property var all: server.trackedNotifications

    // Newest first. The server appends, and the dashboard reads top-down.
    readonly property var history: {
        const v = all.values.slice();
        v.reverse();
        return v;
    }

    readonly property int count: all.values.length

    // The notification currently occupying the notch, or null.
    property var popup: null
    // How many arrived while one was already showing. Reset when the notch
    // returns to rest.
    property int stacked: 0

    readonly property bool critical:
        popup !== null && popup.urgency === NotificationUrgency.Critical

    // The picture to draw for a notification, as something Image can load, or
    // "" for none.
    //
    // TWO DIFFERENT THINGS arrive under the name "icon", and reading only the
    // first is why almost every notification showed a generic bell:
    //
    //   image        pixel data or a path attached to THIS message — album
    //                art, a contact photo, a screenshot thumbnail. Set by a
    //                minority of apps.
    //   appIcon      the sending app's own icon, from the `app_icon` field.
    //                Set by nearly everyone, and it is usually a freedesktop
    //                icon NAME ("firefox"), not a path — so it has to be
    //                resolved through the icon theme before Image sees it.
    //   desktopEntry the app's .desktop id, when it bothered to send one. Last
    //                resort, and by then a name-shaped icon is a fair guess.
    //
    // Callers must still key their fallback glyph off Image.status, not off
    // this returning "" — a name that resolves to a path the theme does not
    // actually have on disk fails at load time, not here. That is the same
    // trap the media art hit in DashPane.
    function iconFor(n) {
        if (!n)
            return "";
        if (n.image && String(n.image) !== "")
            return String(n.image);

        const name = n.appIcon ? String(n.appIcon) : "";
        const entry = n.desktopEntry ? String(n.desktopEntry) : "";
        return resolveIcon(name) || resolveIcon(entry);
    }

    // A path, a URL, or a theme icon name — apps send all three.
    function resolveIcon(s) {
        if (!s || s === "")
            return "";
        if (s.indexOf("://") !== -1)
            return s;
        if (s.charAt(0) === "/")
            return "file://" + s;
        // `true` asks Quickshell to return "" for an icon the theme does not
        // have, rather than a path that will fail to load.
        return Quickshell.iconPath(s, true) || "";
    }

    function dismissPopup() {
        if (popup) popup.dismiss();
        popup = null;
        stacked = 0;
    }

    // Let the toast time out without telling the app it was dismissed by hand.
    function hidePopup() {
        popup = null;
        stacked = 0;
    }

    function clearAll() {
        // Copy first: dismiss() mutates the model we are iterating.
        const v = all.values.slice();
        for (const n of v) n.dismiss();
        popup = null;
        stacked = 0;
    }

    function toggleDnd() {
        Config.dnd = !Config.dnd;
        Config.save();
        if (Config.dnd) hidePopup();
    }

    NotificationServer {
        id: server

        // Advertised capabilities. Only claim what the shell actually renders —
        // an app that is told inline replies are supported will send one, and
        // then it silently does nothing.
        actionsSupported: true
        actionIconsSupported: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        inlineReplySupported: false

        keepOnReload: true

        onNotification: notification => {
            // Without this the notification is discarded the moment this
            // handler returns.
            notification.tracked = true;

            // Notifications restored across a QuickShell reload should land in
            // history without re-popping — otherwise every save of a QML file
            // replays the last hour of messages at you.
            if (notification.lastGeneration) return;

            // Cap history. Oldest first in `values`, so trim from the front.
            const v = server.trackedNotifications.values;
            if (v.length > 100) v[0].dismiss();

            if (Config.dnd && notification.urgency !== NotificationUrgency.Critical)
                return;

            if (root.popup !== null) root.stacked++;
            else root.stacked = 0;

            root.popup = notification;
        }
    }
}
