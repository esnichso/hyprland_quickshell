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
