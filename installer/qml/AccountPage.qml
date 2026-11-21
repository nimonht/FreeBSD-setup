// The user account, the computer's name and the administrator password.
// The rules are install.sh's (checked by installer/luna_installer/backend.py).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    id: page
    title: "Your account"
    subtitle: "You log in with it, and its password also unlocks administration (doas)."
    code: app.stepCode(6)

    property bool userTouched: false
    readonly property string nameErr: app.fullname === "" ? "" : installer.checkFullname(app.fullname)
    readonly property string userErr: app.username === "" ? "" : installer.checkUsername(app.username)
    readonly property string hostErr: installer.checkHostname(app.hostname)
    readonly property string passErr: pw2.text === "" ? "" : installer.checkPassword(app.password, pw2.text, "password")
    readonly property string rootErr: app.sameRootPassword || rpw2.text === "" ? "" : installer.checkPassword(app.rootPassword, rpw2.text, "password")
    readonly property bool diskPassBad: app.encrypt && app.diskUsesLoginPassword && app.password !== "" && !installer.isAscii(app.password)
    readonly property int strength: installer.strength(app.password)
    ready: app.fullname !== "" && app.username !== "" && nameErr === "" && userErr === "" && hostErr === ""
           && app.password !== "" && pw2.text === app.password && !diskPassBad
           && (app.sameRootPassword || (app.rootPassword !== "" && rpw2.text === app.rootPassword))
    hint: app.fullname === "" ? "Type your name" : app.password === "" ? "Choose a password" : ""

    ColumnLayout {
        width: parent.width
        spacing: 24

        Panel {
            Layout.fillWidth: true
            title: "You"
            ColumnLayout {
                width: parent.width
                spacing: 18
                LField {
                    label: "Your name"
                    text: app.fullname
                    error: page.nameErr
                    onEdited: {
                        app.fullname = text
                        if (!page.userTouched) app.username = installer.suggestUsername(text)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20
                    LField {
                        label: "Login name"
                        text: app.username
                        error: page.userErr
                        onEdited: {
                            app.username = text
                            page.userTouched = true
                        }
                    }
                    LField {
                        label: "Computer name"
                        text: app.hostname
                        error: page.hostErr
                        onEdited: app.hostname = text
                    }
                }
            }
        }

        Panel {
            Layout.fillWidth: true
            title: "Password"
            ColumnLayout {
                width: parent.width
                spacing: 16
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20
                    LField {
                        label: "Password"
                        secret: true
                        text: app.password
                        onEdited: app.password = text
                    }
                    LField {
                        id: pw2
                        label: "Password again"
                        secret: true
                        text: installer.demo ? app.password : ""
                        error: page.passErr
                    }
                }
                RowLayout {
                    visible: app.password !== ""
                    spacing: 6
                    Repeater {
                        model: 3
                        Rectangle {
                            width: 54
                            height: 6
                            color: index < page.strength ? (page.strength === 1 ? app.cSignal : app.cInk) : app.cWeak
                        }
                    }
                    Label {
                        Layout.leftMargin: 10
                        color: app.cSoft
                        font.pixelSize: 14
                        text: ["Weak password: use more words or characters", "Weak password: use more words or characters",
                               "Fair password", "Strong password"][page.strength]
                    }
                }
                Label {
                    visible: page.diskPassBad
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: app.cSignal
                    text: "This password also unlocks the disk and is typed before the system starts: use letters, digits and "
                          + "simple symbols only (no accents), or choose a separate disk passphrase on the Disk page."
                }
                MenuRow {
                    kind: "check"
                    compact: true
                    title: "Use the same password for the administrator account (root)"
                    checked: app.sameRootPassword
                    onClicked: app.sameRootPassword = !app.sameRootPassword
                }
                RowLayout {
                    visible: !app.sameRootPassword
                    Layout.fillWidth: true
                    spacing: 20
                    LField {
                        label: "Administrator password"
                        secret: true
                        onEdited: app.rootPassword = text
                    }
                    LField {
                        id: rpw2
                        label: "Administrator password again"
                        secret: true
                        error: page.rootErr
                    }
                }
            }
        }
    }
}
