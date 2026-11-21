// Progress while install.sh runs: the share done, the current step, notes
// about the system, and install.sh's own output.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    title: "Installing"
    subtitle: "Keep the computer on and connected to the internet."
    code: "IN PROGRESS"
    scroll: false
    ready: false

    property int slide: 0
    readonly property var slides: [
        ["Undo for updates", "Every update can be undone: pick the previous boot environment in the boot menu and you are back where you were."],
        ["Your files have versions", "Automatic snapshots keep hourly and daily versions of your files. Deleted something? It is still in a snapshot."],
        ["Drivers, chosen for you", "Graphics, Wi-Fi firmware, CPU microcode and laptop hotkeys are picked from the hardware in this computer."],
        ["Keeping up to date", "Type sysup in a terminal: packages, FreeBSD's patches, and a snapshot before each update."],
        ["When something does not work", "The guides on " + installer.distro.DISTRO_URL.replace("https://", "") + " explain what to do."]
    ]

    Timer {
        interval: 12000
        running: parent.visible
        repeat: true
        onTriggered: slide = (slide + 1) % slides.length
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 24

        Panel {
            Layout.fillWidth: true
            title: "Progress"
            tag: installer.installing ? "RUNNING" : ""
            ColumnLayout {
                width: parent.width
                spacing: 14
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 26
                    Label {
                        text: Math.round(installer.fraction * 100) + "%"
                        color: app.cInk
                        font.family: app.fMono
                        font.pixelSize: 54
                        font.weight: Font.Light
                        Layout.preferredWidth: 150
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 6
                        Label {
                            Layout.fillWidth: true
                            text: installer.stepTitle
                            color: app.cInk
                            font.pixelSize: 20
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Label {
                            Layout.fillWidth: true
                            text: installer.stepDetail
                            color: app.cSoft
                            font.family: app.fMono
                            font.pixelSize: 13
                            elide: Text.ElideMiddle
                        }
                    }
                }
                Meter {
                    Layout.fillWidth: true
                    value: installer.fraction
                    active: installer.installing
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 26

            Panel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 4
                title: "Notes"
                tag: (slide + 1) + " / " + slides.length
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12
                    Item { Layout.fillHeight: true }
                    Image {
                        source: installer.logoUrl
                        sourceSize.width: 48
                        sourceSize.height: 48
                        Layout.preferredWidth: 48
                        Layout.preferredHeight: 48
                    }
                    Label {
                        Layout.fillWidth: true
                        text: slides[slide][0]
                        color: app.cInk
                        font.pixelSize: 22
                        font.weight: Font.Light
                        font.letterSpacing: 1
                        wrapMode: Text.Wrap
                    }
                    Label {
                        Layout.fillWidth: true
                        text: slides[slide][1]
                        color: app.cSoft
                        wrapMode: Text.Wrap
                        lineHeight: 1.25
                    }
                    Item { Layout.fillHeight: true }
                    Row {
                        spacing: 6
                        Repeater {
                            model: slides.length
                            Rectangle {
                                width: 8
                                height: 8
                                color: index === slide ? app.cInk : "transparent"
                                border.width: 1
                                border.color: app.cInk
                            }
                        }
                    }
                }
            }
            Panel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 5
                title: "Log"
                tag: "INSTALL.SH"
                padding: 10
                ScrollView {
                    id: logView
                    anchors.fill: parent
                    clip: true
                    ScrollBar.vertical: LScrollBar {}
                    TextArea {
                        readOnly: true
                        text: installer.logText
                        font.family: app.fMono
                        font.pixelSize: 12
                        color: app.cInk
                        wrapMode: TextEdit.NoWrap
                        selectionColor: app.cInk
                        selectedTextColor: app.cPaper
                        background: null
                        onTextChanged: cursorPosition = length
                    }
                }
            }
        }
    }
}
