// First page: who this is, and Try or Install. On the full-screen
// installer session also why the live desktop could not start.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    id: page
    ready: true

    Item {
        width: parent.width
        // centred when there is room, scrolling when there is not
        implicitHeight: Math.max(page.viewHeight - 24, col.implicitHeight + 24)

        // the mark, large and faint, at the right edge
        Image {
            source: installer.logoUrl
            sourceSize.width: 620
            sourceSize.height: 620
            width: 620
            height: 620
            anchors.right: parent.right
            anchors.rightMargin: -170
            y: Math.max(0, (page.viewHeight - height) / 2)
            opacity: 0.055
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            y: Math.max(12, (parent.implicitHeight - implicitHeight) / 2)
            width: Math.min(parent.width - 40, 640)
            spacing: 0

            Image {
                source: installer.logoUrl
                sourceSize.width: 84
                sourceSize.height: 84
                Layout.preferredWidth: 84
                Layout.preferredHeight: 84
            }
            Item {
                Layout.topMargin: 22
                implicitWidth: wordmark.implicitWidth + 4
                implicitHeight: wordmark.implicitHeight
                Label {
                    x: 4
                    y: 4
                    text: wordmark.text
                    font: wordmark.font
                    color: app.cWeak
                }
                Label {
                    id: wordmark
                    text: app.distroName
                    color: app.cInk
                    font.pixelSize: 54
                    font.weight: Font.Light
                    font.letterSpacing: 16
                    font.capitalization: Font.AllUppercase
                }
            }
            Label {
                Layout.topMargin: 10
                text: installer.distro.DISTRO_TAGLINE + "."
                color: app.cInk
                font.pixelSize: 19
            }
            Label {
                Layout.topMargin: 6
                text: (installer.distro.DISTRO_VERSION + " " + installer.distro.DISTRO_CODENAME + "  ·  based on FreeBSD "
                       + (installer.distro.FREEBSD_RELEASE || "").replace("-RELEASE", "")).toUpperCase()
                color: app.cSoft
                font.family: app.fMono
                font.pixelSize: 12
                font.letterSpacing: 1.5
            }

            Panel {
                visible: installer.mode === "kiosk" && installer.liveReason !== ""
                Layout.fillWidth: true
                Layout.topMargin: 30
                title: "Basic graphics"
                accent: app.cOchre
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: app.cInk
                    lineHeight: 1.2
                    text: "The live desktop cannot start on this computer, so only the installer runs. "
                          + "Reason: " + installer.liveReason + ". You can still install "
                          + app.distroName + "; the next pages show what works here."
                }
            }

            Panel {
                Layout.fillWidth: true
                Layout.topMargin: 30
                title: "Start"
                padding: 8
                ColumnLayout {
                    width: parent.width
                    spacing: 6
                    MenuRow {
                        visible: installer.mode === "welcome"
                        kind: "action"
                        title: "Try " + app.distroName
                        text: "Look around without changing anything. The installer stays on the desktop."
                        onClicked: Qt.quit()
                    }
                    MenuRow {
                        kind: "action"
                        title: "Install " + app.distroName
                        text: "Alone on a disk, or next to Windows or Linux. About 30 to 90 minutes."
                        onClicked: app.page = 1
                    }
                }
            }

            Panel {
                Layout.fillWidth: true
                Layout.topMargin: 22
                title: "Before you start"
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    Repeater {
                        model: ["Back up anything you cannot lose.",
                                "On a laptop, connect the power cable.",
                                "Have an internet connection ready: the newest packages are downloaded while installing."]
                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 12
                            Rectangle {
                                Layout.preferredWidth: 6
                                Layout.preferredHeight: 6
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 8
                                color: app.cInk
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData
                                color: app.cInk
                                wrapMode: Text.Wrap
                            }
                        }
                    }
                }
            }
        }
    }
}
