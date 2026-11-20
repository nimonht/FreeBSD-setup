// First page: "Try or Install" in the live desktop; on the full-screen
// installer session, also why the live desktop could not start.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property bool ready: true
    property string hint: ""

    Image {
        anchors.fill: parent
        source: installer.wallpaperUrl
        fillMode: Image.PreserveAspectCrop
        opacity: 0.45
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 760)
        spacing: 18

        Image {
            source: installer.logoUrl
            sourceSize.width: 112
            sourceSize.height: 112
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: "Welcome to " + app.distroName
            font.pixelSize: 36
            font.bold: true
            color: app.cText
            Layout.alignment: Qt.AlignHCenter
        }
        Label {
            text: installer.distro.DISTRO_TAGLINE
            color: app.cMuted
            font.pixelSize: 17
            Layout.alignment: Qt.AlignHCenter
        }

        Card {
            visible: installer.mode === "kiosk" && installer.liveReason !== ""
            accent: app.cWarn
            Layout.fillWidth: true
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: app.cText
                text: "The live desktop cannot start on this computer, so only the installer is shown. Reason: "
                      + installer.liveReason + ".\n\nYou can still install " + app.distroName
                      + ". The next pages show what works on this computer."
            }
        }

        RowLayout {
            spacing: 18
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10

            ChoiceCard {
                visible: installer.mode === "welcome"
                Layout.preferredWidth: 320
                title: "Try " + app.distroName
                text: "Look around without changing anything. \"Install " + app.distroName + "\" stays on the desktop."
                onClicked: Qt.quit()
            }
            ChoiceCard {
                Layout.preferredWidth: 320
                checked: true
                title: "Install " + app.distroName
                text: "On this computer's disk, alone or next to Windows or Linux. About 30 to 90 minutes."
                onClicked: app.page = 1
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.topMargin: 10
            ColumnLayout {
                width: parent.width
                spacing: 6
                Label {
                    text: "Before you start"
                    font.bold: true
                    color: app.cText
                }
                Repeater {
                    model: ["Back up anything you cannot lose.",
                            "Laptop? Connect it to power.",
                            "Have an internet connection ready: the newest packages are downloaded during the installation."]
                    delegate: Label {
                        text: "•  " + modelData
                        color: app.cMuted
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
