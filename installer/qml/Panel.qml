// A paper surface with an optional header strip (ink band, label on the
// left, a short code on the right) and a hard offset shadow. Put one layout
// inside; it gets `padding` on every side.
import QtQuick
import QtQuick.Controls

Item {
    id: panel
    property string title: ""
    property string tag: ""
    property color accent: app.cInk
    property int padding: 18
    property bool shadow: true
    default property alias content: inner.data

    readonly property int stripHeight: title !== "" ? 30 : 0
    implicitHeight: stripHeight + (inner.children.length > 0 ? inner.children[0].implicitHeight : 0) + 2 * padding
    implicitWidth: (inner.children.length > 0 ? inner.children[0].implicitWidth : 0) + 2 * padding

    Rectangle {
        visible: panel.shadow
        x: 5
        y: 5
        width: parent.width
        height: parent.height
        color: app.cWeak
    }
    Rectangle {
        anchors.fill: parent
        color: app.cPaper
    }
    Rectangle {
        id: strip
        visible: panel.title !== ""
        width: parent.width
        height: panel.stripHeight
        color: panel.accent
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
            text: panel.title
            color: app.cPaper
            font.pixelSize: 12
            font.weight: Font.Medium
            font.letterSpacing: 2.4
            font.capitalization: Font.AllUppercase
        }
        Label {
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: panel.tag
            color: app.cPaper
            opacity: 0.75
            font.family: app.fMono
            font.pixelSize: 11
            font.letterSpacing: 1
        }
    }
    Item {
        id: inner
        anchors.fill: parent
        anchors.topMargin: panel.stripHeight + panel.padding
        anchors.leftMargin: panel.padding
        anchors.rightMargin: panel.padding
        anchors.bottomMargin: panel.padding
    }
}
