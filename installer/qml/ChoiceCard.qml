// A clickable card that is one of several choices (disk, installation
// type, desktop). Shows a radio mark; "danger" colours it red when chosen.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: c
    property string title: ""
    property string text: ""
    property string badge: ""
    property bool checked: false
    property bool danger: false
    signal clicked()

    radius: 14
    color: !enabled ? Qt.darker(app.cCard, 1.25) : (checked ? app.cCardHi : (area.containsMouse ? Qt.lighter(app.cCard, 1.12) : app.cCard))
    border.width: checked ? 2 : 1
    border.color: checked ? (danger ? app.cAccent2 : app.cAccent) : app.cLine
    opacity: enabled ? 1 : 0.6
    implicitHeight: row.implicitHeight + 32
    Layout.fillWidth: true

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: c.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (c.enabled) c.clicked()
    }

    RowLayout {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 18
        spacing: 14

        Rectangle {
            width: 20
            height: 20
            radius: 10
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 2
            color: "transparent"
            border.width: 2
            border.color: c.checked ? (c.danger ? app.cAccent2 : app.cAccent) : app.cMuted
            Rectangle {
                anchors.centerIn: parent
                width: 10
                height: 10
                radius: 5
                visible: c.checked
                color: c.danger ? app.cAccent2 : app.cAccent
            }
        }
        ColumnLayout {
            spacing: 4
            Layout.fillWidth: true
            RowLayout {
                spacing: 10
                Label {
                    text: c.title
                    font.pixelSize: 16
                    font.bold: true
                    color: app.cText
                }
                Rectangle {
                    visible: c.badge !== ""
                    radius: 8
                    color: Qt.rgba(1, 0.62, 0.26, 0.18)
                    implicitWidth: badgeLabel.implicitWidth + 14
                    implicitHeight: badgeLabel.implicitHeight + 4
                    Label {
                        id: badgeLabel
                        anchors.centerIn: parent
                        text: c.badge
                        color: app.cAccent
                        font.pixelSize: 11
                        font.bold: true
                    }
                }
            }
            Label {
                visible: c.text !== ""
                text: c.text
                color: app.cMuted
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }
}
