// What was found in this computer and what works on it (lib/hw.sh's report).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property bool ready: !installer.probing && (app.probe.disks || []).length > 0
    property string hint: installer.probing ? "Looking at this computer..." : ""

    function colour(s) { return s === "OK" ? app.cOk : s === "WARN" ? app.cWarn : s === "NO" ? app.cBad : app.cMuted }
    function mark(s) { return s === "OK" ? "✓" : s === "WARN" ? "!" : s === "NO" ? "✕" : "i" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 20

        PageHeader {
            title: "Your computer"
            subtitle: (app.hw.HW_VENDOR || "") + " " + (app.hw.HW_MODEL || "")
                      + ((app.hw.HW_VENDOR || app.hw.HW_MODEL) ? ": " : "") + "what was found, and what works with " + app.distroName + "."
        }

        Card {
            visible: installer.probing || installer.probeError !== ""
            Layout.fillWidth: true
            RowLayout {
                width: parent.width
                spacing: 14
                BusyIndicator {
                    running: installer.probing
                    visible: running
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: installer.probeError !== "" ? app.cBad : app.cText
                    text: installer.probing ? "Looking at this computer's disks and devices..."
                                            : "The computer could not be checked: " + installer.probeError
                }
                Button {
                    visible: !installer.probing
                    text: "Try again"
                    onClicked: installer.startProbe()
                }
            }
        }

        Card {
            visible: !installer.probing && app.hw.HW_DESKTOP === "no"
            accent: app.cWarn
            Layout.fillWidth: true
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: app.cText
                text: "A graphical desktop will not start on this computer: " + (app.hw.HW_DESKTOP_WHY || "")
                      + ".\nYou can still install " + app.distroName + " with the text console, for example on a server or to try things."
            }
        }

        Card {
            visible: !installer.probing && (app.probe.report || []).length > 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 10
            ListView {
                id: report
                anchors.fill: parent
                clip: true
                spacing: 2
                model: app.probe.report || []
                ScrollBar.vertical: ScrollBar {}
                delegate: RowLayout {
                    width: report.width - 16
                    spacing: 12
                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 6
                        color: Qt.rgba(colour(modelData.status).r, colour(modelData.status).g, colour(modelData.status).b, 0.18)
                        Label {
                            anchors.centerIn: parent
                            text: mark(modelData.status)
                            color: colour(modelData.status)
                            font.bold: true
                            font.pixelSize: 12
                        }
                    }
                    Label {
                        text: modelData.text
                        color: app.cText
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                        topPadding: 8
                        bottomPadding: 8
                    }
                }
            }
        }
    }
}
