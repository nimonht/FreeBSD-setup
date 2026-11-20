// The user account, the computer's name and the administrator password.
// The rules are install.sh's (checked by installer/lumen_installer/backend.py).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property bool userTouched: false
    readonly property string nameErr: app.fullname === "" ? "" : installer.checkFullname(app.fullname)
    readonly property string userErr: app.username === "" ? "" : installer.checkUsername(app.username)
    readonly property string hostErr: installer.checkHostname(app.hostname)
    readonly property string passErr: pw2.text === "" ? "" : installer.checkPassword(app.password, pw2.text, "password")
    readonly property string rootErr: app.sameRootPassword || rpw2.text === "" ? "" : installer.checkPassword(app.rootPassword, rpw2.text, "password")
    readonly property bool diskPassBad: app.encrypt && app.diskUsesLoginPassword && app.password !== "" && !installer.isAscii(app.password)
    property bool ready: app.fullname !== "" && app.username !== "" && nameErr === "" && userErr === "" && hostErr === ""
                         && app.password !== "" && pw2.text === app.password && !diskPassBad
                         && (app.sameRootPassword || (app.rootPassword !== "" && rpw2.text === app.rootPassword))
    property string hint: ""

    component Field: ColumnLayout {
        property alias label: lbl.text
        property string error: ""
        default property alias field: holder.data
        spacing: 4
        Layout.fillWidth: true
        Label {
            id: lbl
            color: app.cMuted
        }
        Item {
            id: holder
            Layout.fillWidth: true
            implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        }
        Label {
            visible: parent.error !== ""
            text: parent.error
            color: app.cBad
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 80
        clip: true
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: col
            x: 40
            y: 40
            width: Math.min(parent.width - 80, 720)
            spacing: 14

            PageHeader {
                title: "About you"
                subtitle: "Your account on this computer. You log in with it and use its password for administration (doas)."
            }

            Field {
                label: "Your name"
                error: page.nameErr
                TextField {
                    width: parent.width
                    text: app.fullname
                    onTextEdited: {
                        app.fullname = text
                        if (!page.userTouched) app.username = installer.suggestUsername(text)
                    }
                }
            }
            RowLayout {
                spacing: 16
                Layout.fillWidth: true
                Field {
                    label: "Login name"
                    error: page.userErr
                    TextField {
                        width: parent.width
                        text: app.username
                        onTextEdited: {
                            app.username = text
                            page.userTouched = true
                        }
                    }
                }
                Field {
                    label: "Computer name"
                    error: page.hostErr
                    TextField {
                        width: parent.width
                        text: app.hostname
                        onTextEdited: app.hostname = text
                    }
                }
            }
            RowLayout {
                spacing: 16
                Layout.fillWidth: true
                Field {
                    label: "Password"
                    TextField {
                        id: pw1
                        width: parent.width
                        echoMode: TextInput.Password
                        text: app.password
                        onTextEdited: app.password = text
                    }
                }
                Field {
                    label: "Password again"
                    error: page.passErr
                    TextField {
                        id: pw2
                        width: parent.width
                        echoMode: TextInput.Password
                        text: installer.demo ? app.password : ""
                    }
                }
            }
            RowLayout {
                visible: app.password !== ""
                spacing: 10
                Repeater {
                    model: 3
                    Rectangle {
                        width: 60
                        height: 6
                        radius: 3
                        color: index < installer.strength(app.password)
                               ? [app.cBad, app.cWarn, app.cOk][installer.strength(app.password) - 1] : app.cLine
                    }
                }
                Label {
                    color: app.cMuted
                    text: ["Weak password", "Weak password", "Fair password", "Strong password"][installer.strength(app.password)]
                }
            }
            Label {
                visible: page.diskPassBad
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: app.cBad
                text: "This password also unlocks the disk, and it is typed before the system starts: use letters, digits and simple symbols only (no accents), or choose a separate disk passphrase on the Disk page."
            }
            CheckBox {
                text: "Use the same password for the administrator account (root)"
                checked: app.sameRootPassword
                onToggled: app.sameRootPassword = checked
            }
            RowLayout {
                visible: !app.sameRootPassword
                spacing: 16
                Layout.fillWidth: true
                Field {
                    label: "Administrator password"
                    TextField {
                        width: parent.width
                        echoMode: TextInput.Password
                        onTextEdited: app.rootPassword = text
                    }
                }
                Field {
                    label: "Administrator password again"
                    error: page.rootErr
                    TextField {
                        id: rpw2
                        width: parent.width
                        echoMode: TextInput.Password
                    }
                }
            }
        }
    }
}
