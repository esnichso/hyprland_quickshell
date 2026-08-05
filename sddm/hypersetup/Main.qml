// The login screen.
//
// SDDM runs as its own user on its own VT before any user session exists, so
// NOTHING here can reach $HOME. This directory is COPIED to
// /usr/share/sddm/themes/hypersetup by `install.sh --sddm` — symlinking it
// into the repo would give the sddm user a path it cannot read.
//
// The palette arrives the same way every other target does: matugen renders
// theme.conf from the same colors.json the shell uses, and --sddm copies it in
// beside this file. SDDM exposes those keys as `config.<key>`. A key that is
// missing comes back undefined, so every read below has a Mocha fallback and
// the greeter still draws if the copy never happened.
//
// IF THIS FILE HAS AN ERROR YOU CANNOT LOG IN. The escape is a TTY:
//   Ctrl+Alt+F2, log in, then
//   sudo rm /etc/sddm.conf.d/10-hypersetup.conf && sudo systemctl restart sddm
// `install.sh --sddm` prints that too, because the moment you need it is the
// moment you cannot read this comment.

import QtQuick

Rectangle {
    id: root

    // SDDM sizes the greeter to the screen; these matter only in --test-mode.
    width: 1280
    height: 800

    // ---- palette ----------------------------------------------------------
    readonly property color cBg:      config.colorBackground      || "#1e1e2e"
    readonly property color cSurface: config.colorSurface         || "#313244"
    readonly property color cOn:      config.colorOnSurface       || "#cdd6f4"
    readonly property color cOnDim:   config.colorOnSurfaceVariant|| "#a6adc8"
    readonly property color cOutline: config.colorOutline         || "#6c7086"
    readonly property color cPrimary: config.colorPrimary         || "#cba6f7"
    readonly property color cOnPri:   config.colorOnPrimary       || "#1e1e2e"
    readonly property color cError:   config.colorError           || "#f38ba8"
    readonly property string uiFont:  config.fontFamily           || "Inter"

    color: cBg

    property string message: ""
    property bool busy: false

    // ---- background -------------------------------------------------------
    // The wallpaper, copied in by --sddm. Absent on a fresh install, and the
    // solid background above is then the whole design rather than a hole in it.
    Image {
        id: wall
        anchors.fill: parent
        source: config.background ? Qt.resolvedUrl(config.background) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
    }

    // Text has to stay readable over a wallpaper nobody validated for contrast,
    // so the whole image is dimmed towards the background colour rather than
    // trusting the picture.
    Rectangle {
        anchors.fill: parent
        visible: wall.visible
        color: root.cBg
        opacity: 0.55
    }

    // ---- clock ------------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: Math.round(parent.height * 0.14)
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.now, "HH:mm")
            color: root.cOn
            font.family: root.uiFont
            font.pixelSize: 72
            font.weight: Font.Light
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.now, "dddd, d. MMMM")
            color: root.cOnDim
            font.family: root.uiFont
            font.pixelSize: 16
        }
    }

    // One timer, one property. Binding two Texts to `new Date()` directly would
    // never update — a JS call is not a change notifier.
    QtObject {
        id: clock
        property var now: new Date()
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.now = new Date()
    }

    // ---- login card -------------------------------------------------------
    Rectangle {
        id: card
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Math.round(parent.height * 0.08)
        width: 340
        height: content.height + 40
        radius: 18
        color: Qt.rgba(root.cSurface.r, root.cSurface.g, root.cSurface.b, 0.82)
        border.width: 1
        border.color: Qt.rgba(root.cOutline.r, root.cOutline.g, root.cOutline.b, 0.25)

        Column {
            id: content
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 14

            // Avatar. A letter, not userModel's icon: the icon is a path under
            // the user's home in most distributions, which is the one place
            // this greeter cannot read.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 64
                height: 64
                radius: 32
                color: Qt.rgba(root.cPrimary.r, root.cPrimary.g, root.cPrimary.b, 0.22)

                Text {
                    anchors.centerIn: parent
                    text: root.currentUser.length > 0
                          ? root.currentUser.charAt(0).toUpperCase() : "?"
                    color: root.cPrimary
                    font.family: root.uiFont
                    font.pixelSize: 26
                    font.weight: Font.DemiBold
                }
            }

            // The login name — prefilled from the model, but ALWAYS editable.
            //
            // It looks like a label and behaves like one on a machine with a
            // single user, because the model fills it in. The point of it being
            // a field is the case that actually happened: the model gave
            // nothing, the card showed an empty gap, and `login("")` returned
            // silently. Now the worst case is that you type six characters.
            TextInput {
                id: userField
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: TextInput.AlignHCenter
                // A binding, so it fills in when the model answers late; typing
                // replaces it, which is exactly the override we want.
                text: root.resolvedUser
                color: root.cOn
                font.family: root.uiFont
                font.pixelSize: 17
                font.weight: Font.DemiBold
                enabled: !root.busy
                onAccepted: pw.forceActiveFocus()

                Text {
                    anchors.centerIn: parent
                    visible: userField.text.length === 0
                    text: "username"
                    color: root.cError
                    font.family: root.uiFont
                    font.pixelSize: 15
                }
            }

            // Password field. A plain TextInput rather than a Controls
            // TextField: QtQuick.Controls pulls a style, and a style that is
            // not installed for the sddm user is a greeter that does not draw.
            Rectangle {
                width: parent.width
                height: 40
                radius: 10
                color: Qt.rgba(root.cBg.r, root.cBg.g, root.cBg.b, 0.65)
                border.width: 1
                border.color: pw.activeFocus ? root.cPrimary
                                             : Qt.rgba(root.cOutline.r, root.cOutline.g,
                                                       root.cOutline.b, 0.4)

                TextInput {
                    id: pw
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 40
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    color: root.cOn
                    font.family: root.uiFont
                    font.pixelSize: 14
                    echoMode: TextInput.Password
                    passwordCharacter: "\u2022"
                    enabled: !root.busy
                    focus: true
                    // Both, deliberately. `accepted` is the documented signal,
                    // and the key handlers are the belt: `busy` makes a double
                    // call harmless, whereas a signal that never fires is a
                    // login screen that does nothing when you press Enter.
                    onAccepted: root.tryLogin()
                    Keys.onReturnPressed: root.tryLogin()
                    Keys.onEnterPressed: root.tryLogin()
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pw.text.length === 0 && !pw.activeFocus
                    text: "Password"
                    color: root.cOnDim
                    font.family: root.uiFont
                    font.pixelSize: 14
                }

                IconButton {
                    anchors.right: parent.right
                    anchors.rightMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: ""
                    size: 32
                    onActivated: root.tryLogin()
                }
            }

            // Reserved height, not `visible`, so the card does not jump on a
            // failed attempt — a card that resizes under the cursor is how you
            // click the wrong thing twice.
            Text {
                width: parent.width
                height: 30
                text: root.message
                color: root.cError
                font.family: root.uiFont
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                // Wraps rather than elides: the diagnostic messages put the
                // values at the END, which is exactly what eliding removes.
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
        }
    }

    // ---- who is logging in ------------------------------------------------
    //
    // `userModel.lastUser` looked like the obvious source and came back EMPTY
    // on this machine. That failure is completely silent: the card just has no
    // name on it, and `sddm.login("", ...)` does NOTHING — no error, no
    // loginFailed, the greeter simply sits there. Which is exactly what it did.
    //
    // So the model is read by ROLE NAME through a Repeater, the same way the
    // session list is, and `lastUser` is only a preference layered on top. A
    // delegate resolves `model.name` by name; reading the model directly would
    // mean hardcoding Qt.UserRole + n, and SDDM has reordered those.
    property string modelUser: ""

    // What the model thinks; what gets sent is whatever is in the field.
    readonly property string resolvedUser:
        (typeof userModel !== "undefined" && userModel.lastUser)
            ? String(userModel.lastUser) : modelUser

    readonly property string currentUser: userField.text.trim()

    Repeater {
        id: users
        model: typeof userModel !== "undefined" ? userModel : 0

        Item {
            required property int index
            required property var model

            readonly property int want:
                (typeof userModel !== "undefined" && userModel.lastIndex >= 0)
                    ? userModel.lastIndex : 0

            function take() {
                if (index !== want)
                    return;
                root.modelUser = model.name || "";
            }

            onWantChanged: take()
            Component.onCompleted: take()
        }
    }

    property int sessionIndex:
        (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
            ? sessionModel.lastIndex : 0

    function tryLogin() {
        if (busy)
            return;
        // Every one of these used to fail silently. On a login screen there is
        // no terminal to read a warning in, so the screen has to say it.
        if (currentUser.length === 0) {
            message = "Type your username first";
            userField.forceActiveFocus();
            return;
        }
        if (pw.text.length === 0) {
            message = "Enter your password";
            return;
        }

        busy = true;
        message = "";
        watchdog.restart();

        // A JS error here would land in the greeter's stderr, which is in the
        // journal, which you cannot reach from the login screen.
        try {
            sddm.login(root.currentUser, pw.text, root.sessionIndex);
        } catch (e) {
            busy = false;
            watchdog.stop();
            message = "login() failed: " + e;
        }
    }

    // sddm answers every login with loginSucceeded or loginFailed. If neither
    // arrives, the greeter would sit with a dead password field and no
    // explanation — which is what an empty user or a bad session index looks
    // like from the outside. Name both in the message; they are the two things
    // being passed.
    Timer {
        id: watchdog
        interval: 5000
        onTriggered: {
            root.busy = false;
            root.message = "no answer from sddm (user '" + root.currentUser
                         + "', session " + root.sessionIndex + ")";
            pw.forceActiveFocus();
        }
    }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            watchdog.stop();
            root.message = "";
        }

        function onLoginFailed() {
            watchdog.stop();
            root.busy = false;
            root.message = "Wrong password";
            pw.text = "";
            pw.forceActiveFocus();
        }

        // PAM's own words — "account expired", "password must be changed" —
        // which are worth showing verbatim rather than flattening to "failed".
        function onInformationMessage(message) {
            root.message = message;
        }
    }

    // ---- bottom bar -------------------------------------------------------
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 22
        spacing: 8

        // Session picker. Click to cycle rather than open a list: there are two
        // entries on this machine at most.
        //
        // The names come from a Repeater, NOT from sessionModel.data(). Reading
        // a model by role INDEX means hardcoding Qt.UserRole + n, and SDDM has
        // reordered those roles between releases — a delegate resolves them by
        // NAME, which is the same reason the shell prefers typed models.
        PillButton {
            glyph: ""
            label: root.sessionName
            visible: sessions.count > 0
            onActivated: {
                if (sessions.count > 0)
                    root.sessionIndex = (root.sessionIndex + 1) % sessions.count;
            }
        }

        // Keyboard layout. This machine is `de`, and a greeter that silently
        // types on `us` is the classic "my password stopped working".
        PillButton {
            glyph: ""
            label: root.layoutName
            visible: root.layoutCount > 1
            onActivated: {
                if (root.layoutCount > 1)
                    keyboard.currentLayout = (keyboard.currentLayout + 1) % root.layoutCount;
            }
        }
    }

    // Read through helpers so a missing model cannot take the whole file down
    // with it — an undefined property in a binding is a silent empty greeter.
    readonly property int layoutCount:
        (typeof keyboard !== "undefined" && keyboard.layouts) ? keyboard.layouts.length : 0

    readonly property string layoutName: {
        if (layoutCount === 0)
            return "";
        const l = keyboard.layouts[keyboard.currentLayout];
        return l ? String(l.shortName).toUpperCase() : "";
    }

    // Session names, resolved by role name. The Repeater draws nothing — it
    // exists so `model.name` is resolvable and so `count` is a real number.
    property string sessionName: ""

    Repeater {
        id: sessions
        model: typeof sessionModel !== "undefined" ? sessionModel : 0

        Item {
            required property int index
            required property var model
            // Runs once per entry at load, and again whenever the pill cycles,
            // because the binding below re-evaluates on sessionIndex.
            readonly property bool current: index === root.sessionIndex
            onCurrentChanged: if (current) root.sessionName = model.name || ""
            Component.onCompleted: if (current) root.sessionName = model.name || ""
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 22
        spacing: 6

        IconButton {
            glyph: ""
            visible: sddm.canSuspend
            onActivated: sddm.suspend()
        }
        IconButton {
            glyph: ""
            visible: sddm.canReboot
            onActivated: sddm.reboot()
        }
        IconButton {
            glyph: ""
            danger: true
            visible: sddm.canPowerOff
            onActivated: sddm.powerOff()
        }
    }

    // ---- components -------------------------------------------------------

    component IconButton: Rectangle {
        id: btn
        property string glyph: ""
        property bool danger: false
        property int size: 38
        signal activated

        width: size
        height: size
        radius: Math.round(size / 3)
        color: ma.containsMouse
               ? Qt.rgba(root.cOutline.r, root.cOutline.g, root.cOutline.b, 0.28)
               : "transparent"

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            // The shell's icon font. It is a hard dependency and installed
            // system-wide, which is the only reason the greeter can use it.
            font.family: "Symbols Nerd Font"
            font.pixelSize: Math.round(btn.size * 0.4)
            color: btn.danger && ma.containsMouse ? root.cError : root.cOnDim
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.activated()
        }
    }

    component PillButton: Rectangle {
        id: pill
        property string glyph: ""
        property string label: ""
        signal activated

        width: inner.width + 22
        height: 32
        radius: 10
        color: pma.containsMouse
               ? Qt.rgba(root.cOutline.r, root.cOutline.g, root.cOutline.b, 0.28)
               : Qt.rgba(root.cOutline.r, root.cOutline.g, root.cOutline.b, 0.14)

        Row {
            id: inner
            anchors.centerIn: parent
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.glyph
                font.family: "Symbols Nerd Font"
                font.pixelSize: 12
                color: root.cOnDim
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: pill.label
                font.family: root.uiFont
                font.pixelSize: 12
                color: root.cOnDim
            }
        }

        MouseArea {
            id: pma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.activated()
        }
    }

    Component.onCompleted: pw.forceActiveFocus()
}
