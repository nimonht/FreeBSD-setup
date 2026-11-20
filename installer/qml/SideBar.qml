// The step list on the left, with the power menu of the full-screen
// installer session (no desktop around it to restart from).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    color: app.cSide

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 26
        spacing: 8

        RowLayout {
            spacing: 12
            Image {
                source: installer.logoUrl
                sourceSize.width: 46
                sourceSize.height: 46
            }
            ColumnLayout {
                spacing: 0
                Label {
                    text: app.distroName
                    font.pixelSize: 22
                    font.bold: true
                    color: app.cText
                }
                Label {
                    text: installer.distro.DISTRO_VERSION + " " + installer.distro.DISTRO_CODENAME
                    color: app.cMuted
                    font.pixelSize: 12
                }
            }
        }

        Item { Layout.preferredHeight: 26 }

        Repeater {
            model: app.steps
            delegate: RowLayout {
                spacing: 12
                readonly property bool done: index < app.page
                readonly property bool current: index === app.page || (index === app.installPage && app.page === app.donePage)
                Layout.preferredHeight: 34
                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: parent.done ? app.cAccent : "transparent"
                    border.width: 2
                    border.color: parent.done || parent.current ? app.cAccent : app.cLine
                    Label {
                        anchors.centerIn: parent
                        text: parent.parent.done ? "✓" : (index + 1)
                        color: parent.parent.done ? app.cSide : app.cText
                        font.pixelSize: 12
                        font.bold: true
                    }
                }
                Label {
                    text: modelData
                    color: parent.current ? app.cText : app.cMuted
                    font.pixelSize: 15
                    font.bold: parent.current
                }
            }
        }

        Item { Layout.fillHeight: true }

        Label {
            visible: installer.demo
            text: "Demo: nothing on this computer is changed"
            color: app.cWarn
            font.pixelSize: 12
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        ColumnLayout {
            visible: installer.mode === "kiosk"
            spacing: 2
            Layout.fillWidth: true
            Button {
                text: "Terminal"
                flat: true
                Layout.fillWidth: true
                onClicked: installer.openTerminal()
            }
            Button {
                text: "Restart"
                flat: true
                Layout.fillWidth: true
                enabled: !installer.installing
                onClicked: installer.reboot()
            }
            Button {
                text: "Power off"
                flat: true
                Layout.fillWidth: true
                enabled: !installer.installing
                onClicked: installer.poweroff()
            }
        }
    }
}
