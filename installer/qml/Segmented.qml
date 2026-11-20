// A row of choices of which one is on, side by side: [ OFF | ON ].
// model: [{ value, label }]
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Row {
    id: seg
    property var model: []
    property string value: ""
    signal picked(string value)
    spacing: 0

    Repeater {
        model: seg.model
        delegate: Rectangle {
            readonly property bool on: seg.value === modelData.value
            width: Math.max(64, lbl.implicitWidth + 32)
            height: 34
            color: on ? app.cInk : (area.containsMouse ? app.cWeak : app.cPaper)
            border.width: 1
            border.color: app.cInk
            Label {
                id: lbl
                anchors.centerIn: parent
                text: modelData.label
                color: parent.on ? app.cPaper : app.cInk
                font.pixelSize: 12
                font.weight: Font.Medium
                font.letterSpacing: 2
                font.capitalization: Font.AllUppercase
            }
            MouseArea {
                id: area
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: seg.picked(modelData.value)
            }
        }
    }
}
