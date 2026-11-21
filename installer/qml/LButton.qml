// Buttons. kind: "primary" (the page's one main action: ink), "danger"
// (the same, red: erasing), "plain" (outlined). Hover sweeps a band in
// from the left; the label is a short verb in capitals.
import QtQuick
import QtQuick.Controls

Button {
    id: b
    property string kind: "plain"
    readonly property bool solid: kind !== "plain"
    readonly property color ink: kind === "danger" ? app.cSignal : app.cInk
    readonly property bool hot: hovered && enabled

    implicitHeight: 42
    implicitWidth: Math.max(120, label.implicitWidth + 56)
    padding: 0
    focusPolicy: Qt.StrongFocus

    contentItem: Item {
        Rectangle {
            id: dot
            x: 18
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            color: label.color
        }
        Label {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            x: dot.x + 16
            text: b.text
            font.pixelSize: 13
            font.weight: Font.Medium
            font.letterSpacing: 2.4
            font.capitalization: Font.AllUppercase
            color: !b.enabled ? app.cDisabled
                   : (b.solid !== b.hot ? app.cPaper : b.ink)
        }
    }
    background: Item {
        // resting surface
        Rectangle {
            anchors.fill: parent
            color: b.solid && b.enabled ? b.ink : "transparent"
            border.width: b.solid && b.enabled ? 0 : 1
            border.color: b.enabled ? b.ink : app.cDisabled
        }
        // the sweep: ink over plain buttons, paper over solid ones
        Rectangle {
            height: parent.height
            width: b.hot ? parent.width : 0
            color: b.solid ? app.cPaper : b.ink
            border.width: b.solid ? 1 : 0
            border.color: b.ink
            Behavior on width { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            visible: b.hot
            y: -4
            width: parent.width
            height: 1
            color: b.ink
        }
        Rectangle {
            visible: b.hot
            y: parent.height + 3
            width: parent.width
            height: 1
            color: b.ink
        }
        Rectangle {
            visible: b.activeFocus && !b.hot
            anchors.fill: parent
            anchors.margins: -4
            color: "transparent"
            border.width: 1
            border.color: b.ink
        }
        Rectangle {
            anchors.fill: parent
            color: app.cInk
            opacity: b.down ? 0.12 : 0
        }
    }
}
