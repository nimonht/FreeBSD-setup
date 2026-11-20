// Title and one line of explanation at the top of a page.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    property string title: ""
    property string subtitle: ""
    spacing: 6
    Layout.fillWidth: true

    Label {
        text: parent.title
        font.pixelSize: 28
        font.bold: true
        color: app.cText
    }
    Label {
        visible: text !== ""
        text: parent.subtitle
        color: app.cMuted
        font.pixelSize: 15
        wrapMode: Text.Wrap
        Layout.fillWidth: true
    }
}
