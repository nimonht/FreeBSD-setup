// What was found in this computer and what works on it (lib/hw.sh's report).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    title: "Your computer"
    subtitle: ((app.hw.HW_VENDOR || "") + " " + (app.hw.HW_MODEL || "")).trim() !== ""
              ? ((app.hw.HW_VENDOR || "") + " " + (app.hw.HW_MODEL || "")).trim() + ". What was found, and what works with " + app.distroName + "."
              : "What was found, and what works with " + app.distroName + "."
    code: app.stepCode(3)
    ready: !installer.probing && (app.probe.disks || []).length > 0
    hint: installer.probing ? "Looking at this computer" : ""

    ColumnLayout {
        width: parent.width
        spacing: 24

        Panel {
            visible: installer.probing
            Layout.fillWidth: true
            RowLayout {
                width: parent.width
                spacing: 14
                Busy {}
                Label {
                    Layout.fillWidth: true
                    text: "Looking at this computer's disks and devices."
                    color: app.cInk
                }
            }
        }

        Panel {
            visible: !installer.probing && installer.probeError !== ""
            Layout.fillWidth: true
            title: "Could not check this computer"
            accent: app.cSignal
            RowLayout {
                width: parent.width
                spacing: 16
                Label {
                    Layout.fillWidth: true
                    text: installer.probeError
                    color: app.cInk
                    wrapMode: Text.Wrap
                }
                LButton {
                    text: "Try again"
                    onClicked: installer.startProbe()
                }
            }
        }

        Panel {
            visible: !installer.probing && app.hw.HW_DESKTOP === "no"
            Layout.fillWidth: true
            title: "No graphical desktop here"
            accent: app.cOchre
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: app.cInk
                lineHeight: 1.2
                text: "A graphical desktop will not start on this computer: " + (app.hw.HW_DESKTOP_WHY || "")
                      + ". You can still install " + app.distroName + " with the text console, for example on a server."
            }
        }

        Panel {
            visible: !installer.probing && (app.probe.report || []).length > 0
            Layout.fillWidth: true
            title: "Hardware check"
            tag: (app.probe.report || []).length + " ITEMS"
            ColumnLayout {
                width: parent.width
                spacing: 0
                Repeater {
                    model: app.probe.report || []
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 9
                            Layout.bottomMargin: 9
                            spacing: 16
                            StatusTag {
                                status: modelData.status
                                Layout.alignment: Qt.AlignTop
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.text
                                color: app.cInk
                                wrapMode: Text.Wrap
                                lineHeight: 1.15
                            }
                        }
                        Rectangle {
                            visible: index < (app.probe.report || []).length - 1
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: app.cWeak
                        }
                    }
                }
            }
        }

        Panel {
            readonly property var sb: app.probe ? installer.secureBoot() : null
            visible: !installer.probing && sb !== null && sb.status !== ""
            Layout.fillWidth: true
            title: "Secure Boot"
            RowLayout {
                width: parent.width
                spacing: 16
                StatusTag {
                    status: parent.parent.sb ? parent.parent.sb.status : ""
                    Layout.alignment: Qt.AlignTop
                }
                Label {
                    Layout.fillWidth: true
                    text: parent.parent.sb ? parent.parent.sb.text : ""
                    color: app.cInk
                    wrapMode: Text.Wrap
                    lineHeight: 1.15
                }
            }
        }
    }
}
