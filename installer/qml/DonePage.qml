// The end: restart into the new system, or what went wrong and what to do.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property bool ready: false
    property string hint: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 18

        RowLayout {
            spacing: 16
            Rectangle {
                width: 52
                height: 52
                radius: 26
                color: Qt.rgba(app.installOk ? 0.3 : 1, app.installOk ? 0.82 : 0.42, app.installOk ? 0.54 : 0.42, 0.18)
                Label {
                    anchors.centerIn: parent
                    text: app.installOk ? "✓" : "!"
                    color: app.installOk ? app.cOk : app.cBad
                    font.pixelSize: 26
                    font.bold: true
                }
            }
            PageHeader {
                title: app.installOk ? app.distroName + " is installed" : "The installation did not finish"
                subtitle: app.installOk ? "Remove the USB stick, then restart the computer."
                                        : "Nothing is lost: the installer removed what it had started on the disk. The details below say why it stopped; check the internet connection and try again."
            }
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            ScrollView {
                anchors.fill: parent
                TextArea {
                    readOnly: true
                    text: app.installOk ? (app.resultText !== "" ? app.resultText : "Nothing else to do: restart, and log in with your account.")
                                         : app.resultText + "\n\nFull log: " + installer.logPath()
                    wrapMode: TextEdit.Wrap
                    font.family: app.installOk ? Qt.application.font.family : "monospace"
                    background: null
                }
            }
        }

        RowLayout {
            spacing: 14
            Layout.alignment: Qt.AlignRight
            Button {
                visible: !app.installOk
                text: "Back to the summary"
                onClicked: app.page = app.summaryPage
            }
            Button {
                visible: installer.mode === "welcome" || installer.mode === "install"
                text: "Keep using the live system"
                flat: true
                onClicked: Qt.quit()
            }
            AccentButton {
                text: app.installOk ? "Restart now" : "Power off"
                onClicked: app.installOk ? installer.reboot() : installer.poweroff()
            }
        }
    }
}
