// The steps, as a menu: done ones are filled and can be revisited, the
// current one is an ink band. In the full-screen session (no desktop
// around it) the System menu offers a terminal, restart and power off.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: side

    component Strip: Rectangle {
        property string label
        Layout.fillWidth: true
        implicitHeight: 28
        color: app.cInk
        Rectangle {
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            color: app.cPaper
        }
        Label {
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            text: parent.label
            color: app.cPaper
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 2.4
            font.capitalization: Font.AllUppercase
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Repeater {
                model: 3
                Rectangle {
                    width: 3
                    height: 3
                    color: app.cPaper
                    opacity: 0.6
                }
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: app.cInk
        opacity: 0.35
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        anchors.rightMargin: 21
        spacing: 0

        Strip { label: "Steps" }
        Item { Layout.preferredHeight: 10 }

        Repeater {
            model: app.steps
            delegate: Item {
                id: step
                readonly property bool current: index === app.page || (index === app.installPage && app.page === app.donePage)
                readonly property bool done: index < app.page && !current
                readonly property bool canGo: done && index > 0 && app.page <= app.summaryPage
                Layout.fillWidth: true
                implicitHeight: 38

                Rectangle {
                    height: parent.height - 4
                    anchors.verticalCenter: parent.verticalCenter
                    width: step.current ? parent.width : 0
                    color: app.cInk
                    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.topMargin: 2
                    anchors.bottomMargin: 2
                    color: app.cWeak
                    opacity: area.containsMouse && step.canGo ? 0.6 : 0
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 12
                    Label {
                        text: (index < 9 ? "0" : "") + (index + 1)
                        color: step.current ? app.cPaper : app.cSoft
                        font.family: app.fMono
                        font.pixelSize: 12
                    }
                    Rectangle {
                        Layout.preferredWidth: 8
                        Layout.preferredHeight: 8
                        color: step.done ? app.cInk : "transparent"
                        border.width: 1
                        border.color: step.current ? app.cPaper : (step.done ? app.cInk : app.cSoft)
                    }
                    Label {
                        Layout.fillWidth: true
                        text: modelData
                        color: step.current ? app.cPaper : (step.done ? app.cInk : app.cSoft)
                        font.pixelSize: 15
                        font.weight: step.current ? Font.Medium : Font.Normal
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: step.canGo
                    cursorShape: step.canGo ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: app.page = index
                }
            }
        }

        Item { Layout.fillHeight: true }

        ColumnLayout {
            visible: installer.mode === "kiosk"
            Layout.fillWidth: true
            spacing: 4
            Strip { label: "System" }
            Item { Layout.preferredHeight: 4 }
            MenuRow {
                kind: "action"
                compact: true
                title: "Open a terminal"
                onClicked: installer.openTerminal()
            }
            MenuRow {
                kind: "action"
                compact: true
                title: "Restart"
                enabled: !installer.installing
                onClicked: installer.reboot()
            }
            MenuRow {
                kind: "action"
                compact: true
                title: "Power off"
                enabled: !installer.installing
                onClicked: installer.poweroff()
            }
        }
    }
}
