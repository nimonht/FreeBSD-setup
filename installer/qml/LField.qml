// A labelled text field: the label always above (never only a placeholder),
// an ink line under the text, the problem in words below it.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: f
    property string label: ""
    property alias text: input.text
    property alias placeholder: input.placeholderText
    property bool secret: false
    property string error: ""
    property alias field: input
    signal edited()
    signal accepted()

    spacing: 6
    Layout.fillWidth: true

    Label {
        text: f.label
        color: app.cSoft
        font.pixelSize: 12
        font.weight: Font.Medium
        font.letterSpacing: 2
        font.capitalization: Font.AllUppercase
    }
    TextField {
        id: input
        Layout.fillWidth: true
        implicitHeight: 42
        leftPadding: 14
        rightPadding: f.secret ? 64 : 14
        font.pixelSize: 16
        color: app.cInk
        placeholderTextColor: app.cDisabled
        selectionColor: app.cInk
        selectedTextColor: app.cPaper
        echoMode: f.secret && !reveal.on ? TextInput.Password : TextInput.Normal
        passwordCharacter: "\u2022"
        onTextEdited: f.edited()
        onAccepted: f.accepted()
        background: Item {
            Rectangle {
                anchors.fill: parent
                color: app.cPaper
            }
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: input.activeFocus ? 2 : 1
                color: f.error !== "" ? app.cSignal : app.cInk
            }
            Rectangle {
                visible: input.activeFocus
                x: 0
                width: 3
                height: parent.height
                color: app.cInk
            }
        }
        Label {
            id: reveal
            property bool on: false
            visible: f.secret && input.text !== ""
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: on ? "HIDE" : "SHOW"
            color: app.cSoft
            font.pixelSize: 11
            font.weight: Font.Medium
            font.letterSpacing: 1.6
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                cursorShape: Qt.PointingHandCursor
                onClicked: reveal.on = !reveal.on
            }
        }
    }
    RowLayout {
        visible: f.error !== ""
        spacing: 8
        Layout.fillWidth: true
        Rectangle {
            Layout.preferredWidth: 7
            Layout.preferredHeight: 7
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 6
            color: app.cSignal
        }
        Label {
            Layout.fillWidth: true
            text: f.error
            color: app.cSignal
            font.pixelSize: 14
            wrapMode: Text.Wrap
        }
    }
}
