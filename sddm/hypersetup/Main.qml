// The login screen.
//
// SDDM runs as its own user on its own VT before any user session exists, so
// NOTHING here can reach $HOME. This directory is COPIED to
// /usr/share/sddm/themes/hypersetup by `install.sh --sddm` — symlinking it into
// the repo would give the sddm user a path it cannot read.
//
// The palette arrives the same way every other target does: matugen renders
// theme.conf from the same colors.json the shell uses, and --sddm copies it in
// beside this file. SDDM exposes those keys as `config.<key>`. A missing key
// comes back undefined, so every read below has a Mocha fallback and the
// greeter still draws if the copy never happened.
//
// EVERYTHING HERE STAYS INSIDE QT 5 AND QT 6 SYNTAX, deliberately.
// `import QtQuick` with no version is Qt 6 only, and it is what broke this
// theme in the field: sddm reported "Library import requires a version", the
// theme did not load at all, and the greeter fell back to breeze. Which QML
// engine sddm launches is not something this repo can determine, so the file
// avoids the question — versioned imports, no inline components, no `required
// property`, and signals connected in JS rather than through Connections.
//
// IF THIS FILE HAS AN ERROR YOU CANNOT LOG IN. The escape is a TTY:
//   Ctrl+Alt+F2, log in, then
//   sudo rm /etc/sddm.conf.d/10-hypersetup.conf && sudo systemctl restart sddm
// `install.sh --sddm` prints that too, because the moment you need it is the
// moment you cannot read this comment.

import QtQuick 2.15

Rectangle {
    id: root

    // SDDM sizes the greeter to the screen; these matter only in --test-mode.
    width: 1280
    height: 800

    // ---- palette ----------------------------------------------------------
    property color cBg:      config.colorBackground       || "#1e1e2e"
    property color cSurface: config.colorSurface          || "#313244"
    property color cOn:      config.colorOnSurface        || "#cdd6f4"
    property color cOnDim:   config.colorOnSurfaceVariant || "#a6adc8"
    property color cOutline: config.colorOutline          || "#6c7086"
    property color cPrimary: config.colorPrimary          || "#cba6f7"
    property color cError:   config.colorError            || "#f38ba8"

    property string uiFont:  config.fontFamily || "Inter"

    property color cHover:  Qt.rgba(cOutline.r, cOutline.g, cOutline.b, 0.28)
    property color cChip:   Qt.rgba(cOutline.r, cOutline.g, cOutline.b, 0.14)

    color: cBg

    property string message: ""
    property bool busy: false
    property string modelUser: ""
    property string sessionName: ""

    // ---- background -------------------------------------------------------
    // The wallpaper, copied in by --sddm. Absent on a fresh install, and the
    // solid colour above is then the whole design rather than a hole in it.
    Image {
        id: wall
        anchors.fill: parent
        source: config.background ? Qt.resolvedUrl(config.background) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: status === Image.Ready
    }

    // Text has to stay readable over a picture nobody checked for contrast, so
    // the whole image is dimmed toward the background colour.
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
            font.pixelSize: 72
            font.weight: Font.Light
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.now, "dddd, d. MMMM")
            color: root.cOnDim
            font.pixelSize: 16
        }
    }

    // One timer, one property. Binding a Text to `new Date()` would never
    // update — a JS call is not a change notifier.
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

            // Avatar. A letter, not userModel's icon: that icon is a path under
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
            // It looks like a label and behaves like one on a machine with one
            // user, because the model fills it in. The point of it being a field
            // is the case that actually happened: the model gave nothing, the
            // card showed an empty gap, and `login("")` returned silently. Now
            // the worst case is that you type six characters.
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
            // TextField: QtQuick.Controls resolves a style at load, and a style
            // that is not installed for the sddm user is a greeter that does
            // not draw.
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
                    // Both, deliberately. `accepted` is the documented signal
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
                    fg: root.cOnDim
                    fgHover: root.cOnDim
                    hover: root.cHover
                    onActivated: root.tryLogin()
                }
            }

            // Reserved height, not `visible`, so the card does not jump on a
            // failed attempt — a card that resizes under the cursor is how you
            // click the wrong thing twice.
            Text {
                width: parent.width
                height: 46
                text: root.message
                color: root.cError
                font.family: root.uiFont
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                // Wraps rather than elides: the diagnostics put their values at
                // the END, which is exactly what eliding removes.
                wrapMode: Text.Wrap
                maximumLineCount: 3
            }
        }
    }

    // ---- who is logging in ------------------------------------------------
    //
    // `userModel.lastUser` looked like the obvious source and came back EMPTY on
    // this machine. That failure is completely silent: the card just has no name
    // on it, and `sddm.login("", ...)` does NOTHING — no error, no loginFailed,
    // the greeter simply sits there. Which is exactly what it did.
    //
    // So the model is read by ROLE NAME through a Repeater, the same way the
    // session list is. Reading the model directly would mean hardcoding
    // Qt.UserRole + n, and SDDM has reordered those between releases.
    property string resolvedUser:
        (typeof userModel !== "undefined" && userModel.lastUser)
            ? String(userModel.lastUser) : modelUser

    property string currentUser: userField.text.trim()

    function wantUser() {
        if (typeof userModel === "undefined")
            return 0;
        return userModel.lastIndex >= 0 ? userModel.lastIndex : 0;
    }

    Repeater {
        id: users
        model: (typeof userModel !== "undefined") ? userModel : 0

        delegate: Item {
            property int idx: index
            property string uname:
                (typeof model !== "undefined" && model.name) ? String(model.name) : ""
            Component.onCompleted: {
                if (idx === root.wantUser() && uname !== "")
                    root.modelUser = uname;
            }
        }
    }

    property int sessionIndex:
        (typeof sessionModel !== "undefined" && sessionModel.lastIndex >= 0)
            ? sessionModel.lastIndex : 0

    // Session names, by role name. The Repeater draws nothing — it exists so
    // `model.name` is resolvable and so `count` is a real number.
    Repeater {
        id: sessions
        model: (typeof sessionModel !== "undefined") ? sessionModel : 0

        delegate: Item {
            property int idx: index
            property string sname:
                (typeof model !== "undefined" && model.name) ? String(model.name) : ""
            property bool cur: idx === root.sessionIndex
            onCurChanged: {
                if (cur)
                    root.sessionName = sname;
            }
            Component.onCompleted: {
                if (cur)
                    root.sessionName = sname;
            }
        }
    }

    // ---- login ------------------------------------------------------------

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
    // arrives the greeter would sit with a dead password field and no
    // explanation — which is what an empty user or a bad session index looks
    // like from outside. Name both; they are the two values being passed.
    //
    // IT ALSO FIRES UNDER `--test-mode`, ALWAYS, and that is correct: test mode
    // has no sddm daemon behind the greeter, so login() has nothing to talk to
    // and no reply can come. The message says so, because "no answer from sddm"
    // on a preview reads like a fault when it is the only possible outcome.
    Timer {
        id: watchdog
        interval: 5000
        onTriggered: {
            root.busy = false;
            root.message = "no answer from sddm — normal under --test-mode "
                         + "(user '" + root.currentUser
                         + "', session " + root.sessionIndex + ")";
            pw.forceActiveFocus();
        }
    }

    function handleSucceeded() {
        watchdog.stop();
        root.message = "";
    }

    function handleFailed() {
        watchdog.stop();
        root.busy = false;
        root.message = "Wrong password";
        pw.text = "";
        pw.forceActiveFocus();
    }

    // PAM's own words — "account expired", "password must be changed" — worth
    // showing verbatim rather than flattening to "failed".
    function handleInfo(msg) {
        root.message = String(msg);
    }

    // ---- bottom bar -------------------------------------------------------
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 22
        spacing: 8

        // Session picker. Click to cycle rather than open a list: there are two
        // entries on this machine at most.
        PillButton {
            glyph: ""
            label: root.sessionName
            uiFont: root.uiFont
            visible: sessions.count > 0
            fg: root.cOnDim
            bg: root.cChip
            bgHover: root.cHover
            onActivated: {
                if (sessions.count > 0)
                    root.sessionIndex = (root.sessionIndex + 1) % sessions.count;
            }
        }

        // Keyboard layout. This machine is `de`, and a greeter silently typing
        // on `us` is the classic "my password stopped working".
        PillButton {
            glyph: ""
            label: root.layoutName
            uiFont: root.uiFont
            visible: root.layoutCount > 1
            fg: root.cOnDim
            bg: root.cChip
            bgHover: root.cHover
            onActivated: {
                if (root.layoutCount > 1)
                    keyboard.currentLayout = (keyboard.currentLayout + 1) % root.layoutCount;
            }
        }
    }

    // Read through helpers so a missing model cannot take the whole file down
    // with it — an undefined property in a binding is a silent empty greeter.
    property int layoutCount:
        (typeof keyboard !== "undefined" && keyboard.layouts) ? keyboard.layouts.length : 0

    property string layoutName: {
        if (layoutCount === 0)
            return "";
        var l = keyboard.layouts[keyboard.currentLayout];
        return l ? String(l.shortName).toUpperCase() : "";
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 22
        spacing: 6

        IconButton {
            glyph: ""
            visible: typeof sddm !== "undefined" && sddm.canSuspend
            fg: root.cOnDim
            fgHover: root.cOn
            hover: root.cHover
            onActivated: sddm.suspend()
        }
        IconButton {
            glyph: ""
            visible: typeof sddm !== "undefined" && sddm.canReboot
            fg: root.cOnDim
            fgHover: root.cOn
            hover: root.cHover
            onActivated: sddm.reboot()
        }
        IconButton {
            glyph: ""
            visible: typeof sddm !== "undefined" && sddm.canPowerOff
            fg: root.cOnDim
            fgHover: root.cError
            hover: root.cHover
            onActivated: sddm.powerOff()
        }
    }

    // Signals connected in JS, not through Connections.
    //
    // `Connections { function onLoginFailed() {} }` needs Qt 5.15, and the
    // older `onLoginFailed: {}` form is deprecated in Qt 6. `signal.connect()`
    // is the one spelling both engines have always accepted. Wrapped, because a
    // signal this version does not have must not abort the rest of this block —
    // the focus call below is what makes the greeter typable.
    Component.onCompleted: {
        pw.forceActiveFocus();
        try {
            sddm.loginSucceeded.connect(root.handleSucceeded);
            sddm.loginFailed.connect(root.handleFailed);
            sddm.informationMessage.connect(root.handleInfo);
        } catch (e) {
            root.message = "could not connect sddm signals: " + e;
        }
    }
}
