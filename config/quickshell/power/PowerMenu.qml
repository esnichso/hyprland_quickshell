// The power menu — Lock · Logout · Suspend · Restart · Shut down.
//
// Same window pattern as the launcher and the control centre: full-screen
// transparent overlay, exclusive keyboard focus, click outside to close. One
// focus mechanism per surface, and no HyprlandFocusGrab anywhere near it.
//
// The two irreversible actions ask first. Everything else happens on Enter,
// because a confirmation on Lock is a second keystroke you press every time and
// resent by the third day.
//
// Confirmation is a STATE OF THE PANEL, not a second window. A dialog would be
// another surface taking focus, which is the mistake this repo has already paid
// for twice.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "root:/"
import "root:/services"
import "root:/widgets"

PanelWindow {
    id: root

    screen: Panels.focusedScreen
    visible: Panels.power

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    WlrLayershell.namespace: "hypersetup-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // Index of the row awaiting confirmation, or -1. Reset on every open.
    property int confirming: -1
    property int current: 0

    readonly property var actions: [
        { key: "lock",     label: "Lock",      hint: "L", icon: Icons.lock,
          confirm: false, detail: "hyprlock" },
        { key: "logout",   label: "Log out",   hint: "O", icon: Icons.logout,
          confirm: false, detail: "close apps and quit Hyprland" },
        { key: "suspend",  label: "Suspend",   hint: "S", icon: Icons.suspend,
          confirm: false, detail: "sleep, keep the session" },
        { key: "reboot",   label: "Restart",   hint: "R", icon: Icons.reboot,
          confirm: true,  detail: "close apps, then reboot" },
        { key: "poweroff", label: "Shut down", hint: "P", icon: Icons.power,
          confirm: true,  detail: "close apps, then power off" }
    ]

    onVisibleChanged: {
        if (!visible)
            return;
        root.current = 0;
        root.confirming = -1;
        Session.refresh();
        keys.forceActiveFocus();
    }

    function run(index) {
        const a = root.actions[index];
        if (!a)
            return;

        if (a.confirm && root.confirming !== index) {
            root.confirming = index;
            root.current = index;
            return;
        }

        // Close first. Every one of these tears down the session or the
        // screen, and a panel still painted while hyprshutdown draws its own
        // dialog is two things claiming the same moment.
        Panels.closeAll();

        switch (a.key) {
        case "lock":     Session.lock(); break;
        case "logout":   Session.logout(); break;
        case "suspend":  Session.suspend(); break;
        case "reboot":   Session.reboot(); break;
        case "poweroff": Session.poweroff(); break;
        }
    }

    function step(delta) {
        const n = root.actions.length;
        root.current = (root.current + delta + n) % n;
        // Moving off a row that was awaiting confirmation cancels it: the
        // pending action must always be the one under the cursor.
        if (root.confirming !== root.current)
            root.confirming = -1;
    }

    function activateHint(text) {
        for (let i = 0; i < root.actions.length; i++) {
            if (root.actions[i].hint.toLowerCase() === text.toLowerCase()) {
                root.run(i);
                return true;
            }
        }
        return false;
    }

    // Declared BEFORE the box so it sits underneath it.
    MouseArea {
        anchors.fill: parent
        onClicked: Panels.closeAll()
    }

    Item {
        id: keys
        anchors.fill: parent
        focus: true

        Keys.onUpPressed: root.step(-1)
        Keys.onDownPressed: root.step(1)
        Keys.onReturnPressed: root.run(root.current)
        Keys.onEnterPressed: root.run(root.current)

        Keys.onEscapePressed: event => {
            // Escape backs out of a confirmation first, and only closes the
            // menu once there is nothing to back out of.
            if (root.confirming !== -1)
                root.confirming = -1;
            else
                Panels.closeAll();
            event.accepted = true;
        }

        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_K:
                root.step(-1);
                event.accepted = true;
                return;
            case Qt.Key_J:
                root.step(1);
                event.accepted = true;
                return;
            }
            // Letter accelerators. Checked last so j and k keep meaning
            // "move" even though neither is an accelerator today.
            if (event.text && root.activateHint(event.text))
                event.accepted = true;
        }

        IslandSurface {
            id: box
            island: false

            width: Config.power.width
            x: Math.round((parent.width - width) / 2)
            y: Math.round((parent.height - implicitHeight) / 2)

            implicitHeight: col.implicitHeight + 20

            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: col
                y: 10
                width: parent.width
                spacing: 2

                Repeater {
                    model: root.actions

                    ActionRow {
                        required property var modelData
                        required property int index

                        width: col.width
                        action: modelData
                        selected: index === root.current
                        pending: index === root.confirming

                        onPicked: root.run(index)
                        onHovered: {
                            root.current = index;
                            if (root.confirming !== index)
                                root.confirming = -1;
                        }
                    }
                }

                // ---- footer ----
                Item {
                    width: parent.width
                    height: 26

                    Rectangle {
                        anchors.top: parent.top
                        anchors.topMargin: 4
                        width: parent.width - 24
                        x: 12
                        height: 1
                        color: Theme.outline
                        opacity: 0.18
                    }

                    Glyph {
                        id: clockIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 3
                        text: Icons.clock
                        font.pixelSize: 10
                        color: Qt.alpha(Theme.onSurfaceVariant, 0.7)
                    }

                    Text {
                        anchors.left: clockIcon.right
                        anchors.leftMargin: 8
                        anchors.verticalCenter: clockIcon.verticalCenter
                        text: Session.uptimeText()
                        color: Qt.alpha(Theme.onSurfaceVariant, 0.7)
                        font.family: "Inter"; font.pixelSize: 10
                    }

                    // Only shown when something is actually holding a lock. A
                    // suspend that silently does nothing looks like a broken
                    // button, and this is the one place to say why.
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: clockIcon.verticalCenter
                        spacing: 6
                        visible: Session.inhibitors > 0

                        Glyph {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Icons.warning
                            font.pixelSize: 10
                            color: Theme.error
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Session.inhibitorWho !== ""
                                ? `${Session.inhibitorWho} blocks sleep`
                                : `${Session.inhibitors} blocking sleep`
                            color: Theme.error
                            font.family: "Inter"; font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------- components

    component ActionRow: Item {
        id: row

        property var action: null
        property bool selected: false
        property bool pending: false

        signal picked
        signal hovered

        implicitHeight: 44

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            anchors.topMargin: 1
            anchors.bottomMargin: 1
            radius: 9
            color: row.pending ? Qt.alpha(Theme.error, 0.18)
                 : row.selected ? Qt.alpha(Theme.primary, 0.16)
                 : "transparent"
            Behavior on color { ColorAnimation { duration: Config.fadeMs } }
        }

        Glyph {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: row.action ? row.action.icon : ""
            font.pixelSize: 15
            color: row.pending ? Theme.error
                 : row.selected ? Theme.primary
                 : Theme.onSurfaceVariant
        }

        Column {
            anchors.left: icon.right
            anchors.leftMargin: 16
            anchors.right: hint.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: row.pending && row.action
                    ? `${row.action.label}? Enter to confirm`
                    : row.action ? row.action.label : ""
                color: row.pending ? Theme.error : Theme.onSurface
                font.family: "Inter"; font.pixelSize: 13
                font.weight: row.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                text: row.pending ? "Escape to cancel"
                    : row.action ? row.action.detail : ""
                color: Theme.onSurfaceVariant
                font.family: "Inter"; font.pixelSize: 10
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: hint
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18; radius: 5
            visible: !row.pending
            color: Qt.alpha(Theme.outline, 0.2)

            Text {
                anchors.centerIn: parent
                text: row.action ? row.action.hint : ""
                color: Theme.onSurfaceVariant
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 10
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: row.hovered()
            onClicked: row.picked()
        }
    }
}
