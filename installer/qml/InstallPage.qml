// Progress while install.sh runs, a few words about the system, and the
// full output for the curious.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property bool ready: false
    property string hint: ""
    property int slide: 0

    readonly property var slides: [
        ["Undo for updates", "Every update can be undone: pick the previous boot environment in the boot menu and you are back where you were."],
        ["Your files have versions", "Automatic ZFS snapshots keep hourly and daily versions of your files. Deleted something? It is still in a snapshot."],
        ["Drivers, chosen for you", "Graphics, Wi-Fi firmware, CPU microcode and laptop hotkeys are picked from the hardware found in this computer."],
        ["Keeping up to date", "Run 'sysup' in a terminal: packages, FreeBSD patches and a snapshot before each update."],
        ["Help", "Something not working? The README and docs/TROUBLESHOOTING.md on " + installer.distro.DISTRO_URL + " explain what to do."]
    ]

    Timer {
        interval: 12000
        running: parent.visible
        repeat: true
        onTriggered: slide = (slide + 1) % slides.length
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 18

        PageHeader {
            title: "Installing " + app.distroName
            subtitle: "Keep the computer on and connected to the internet."
        }

        Card {
            Layout.fillWidth: true
            ColumnLayout {
                width: parent.width
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: installer.stepTitle
                        font.pixelSize: 18
                        font.bold: true
                        color: app.cText
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Label {
                        text: Math.round(installer.fraction * 100) + " %"
                        font.pixelSize: 18
                        color: app.cAccent
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 10
                    radius: 5
                    color: app.cLine
                    Rectangle {
                        width: parent.width * installer.fraction
                        height: parent.height
                        radius: 5
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: app.cAccent }
                            GradientStop { position: 1; color: app.cAccent2 }
                        }
                        Behavior on width { NumberAnimation { duration: 400 } }
                    }
                }
                Label {
                    text: installer.stepDetail
                    color: app.cMuted
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }

        Card {
            visible: !details.checked
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width * 0.8
                spacing: 12
                Image {
                    source: installer.logoUrl
                    sourceSize.width: 72
                    sourceSize.height: 72
                    Layout.alignment: Qt.AlignHCenter
                }
                Label {
                    text: slides[slide][0]
                    font.pixelSize: 22
                    font.bold: true
                    color: app.cText
                    Layout.alignment: Qt.AlignHCenter
                }
                Label {
                    text: slides[slide][1]
                    color: app.cMuted
                    font.pixelSize: 15
                    wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
            }
        }

        ScrollView {
            visible: details.checked
            Layout.fillWidth: true
            Layout.fillHeight: true
            TextArea {
                readOnly: true
                text: installer.logText
                font.family: "monospace"
                font.pixelSize: 12
                wrapMode: TextEdit.NoWrap
                onTextChanged: cursorPosition = length
                background: Rectangle { color: app.cSide; radius: 10 }
            }
        }

        CheckBox {
            id: details
            text: "Show details"
        }
    }
}
