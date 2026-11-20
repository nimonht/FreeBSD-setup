// The end: restart into the new system, or what went wrong and what to do.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    title: app.installOk ? "Installed" : "Not finished"
    subtitle: app.installOk ? app.distroName + " is installed. Remove the USB stick, then restart the computer."
                            : "Nothing is lost: the installer removed what it had started on the disk. The details below say why it stopped; "
                              + "check the internet connection and try again."
    code: app.installOk ? "COMPLETE" : "STOPPED"
    scroll: false
    ready: false

    ColumnLayout {
        anchors.fill: parent
        spacing: 24

        Panel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: app.installOk ? "Where it starts from" : "What happened"
            accent: app.installOk ? app.cInk : app.cSignal
            ScrollView {
                anchors.fill: parent
                clip: true
                ScrollBar.vertical: LScrollBar {}
                TextArea {
                    readOnly: true
                    wrapMode: TextEdit.Wrap
                    color: app.cInk
                    font.family: app.installOk ? app.fSans : app.fMono
                    font.pixelSize: app.installOk ? 15 : 13
                    selectionColor: app.cInk
                    selectedTextColor: app.cPaper
                    background: null
                    text: app.installOk ? (app.resultText !== "" ? app.resultText : "Nothing else to do: restart, and log in with your account.")
                                        : app.resultText + "\n\nFull log: " + installer.logPath()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 18
            Item { Layout.fillWidth: true }
            LButton {
                visible: !app.installOk
                text: "Back to summary"
                onClicked: app.page = app.summaryPage
            }
            LButton {
                visible: installer.mode === "welcome" || installer.mode === "install"
                text: "Keep trying " + app.distroName
                onClicked: Qt.quit()
            }
            LButton {
                kind: "primary"
                text: app.installOk ? "Restart now" : "Power off"
                onClicked: app.installOk ? installer.reboot() : installer.poweroff()
            }
        }
    }
}
