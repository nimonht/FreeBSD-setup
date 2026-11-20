// One choice in a list: a square marker, a title, a line of explanation.
// Hovering draws a band above and below; choosing it sweeps an ink bar in
// from the left and the text turns light. kind: "radio" (one of several),
// "check" (on/off), "action" (does something now).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: row
    property string title: ""
    property string text: ""
    property string tag: ""
    property string kind: "radio"
    property bool checked: false
    property bool danger: false
    property bool compact: false
    signal clicked()

    readonly property bool hot: area.containsMouse && enabled
    readonly property bool lit: (checked && kind !== "check") || (kind === "action" && hot)
    readonly property color band: danger ? app.cSignal : app.cInk
    readonly property color fg: lit ? app.cPaper : app.cInk
    readonly property color fgSoft: lit ? Qt.rgba(0.86, 0.85, 0.75, 0.9) : app.cSoft

    implicitHeight: Math.max(compact ? 36 : 48, content.implicitHeight + (compact ? 12 : 20))
    implicitWidth: 320
    Layout.fillWidth: true
    opacity: enabled ? 1 : 0.55
    activeFocusOnTab: enabled

    Keys.onSpacePressed: if (enabled) row.clicked()
    Keys.onReturnPressed: if (enabled) row.clicked()

    // hover band: a line above and below, a little outside the row
    Rectangle {
        visible: row.hot && !row.lit
        x: 0
        y: -3
        width: parent.width
        height: 1
        color: row.band
    }
    Rectangle {
        visible: row.hot && !row.lit
        x: 0
        y: parent.height + 2
        width: parent.width
        height: 1
        color: row.band
    }
    // hover wash and the chosen sweep
    Rectangle {
        anchors.fill: parent
        color: app.cWeak
        opacity: row.hot && !row.lit ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: 120 } }
    }
    Rectangle {
        height: parent.height
        width: row.lit ? parent.width : 0
        color: row.band
        Behavior on width { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
    }
    // keyboard focus
    Rectangle {
        visible: row.activeFocus
        anchors.fill: parent
        anchors.margins: -3
        color: "transparent"
        border.width: 1
        border.color: app.cInk
    }

    RowLayout {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        spacing: 14

        // marker
        Item {
            Layout.preferredWidth: 14
            Layout.preferredHeight: 14
            Layout.alignment: row.text !== "" && !row.compact ? Qt.AlignTop : Qt.AlignVCenter
            Layout.topMargin: row.text !== "" && !row.compact ? 3 : 0
            Rectangle {
                anchors.centerIn: parent
                width: row.kind === "check" ? 14 : 10
                height: width
                color: row.kind === "action" ? row.fg : "transparent"
                border.width: row.kind === "action" ? 0 : 1
                border.color: row.fg
                Rectangle {
                    anchors.centerIn: parent
                    width: row.kind === "check" ? 8 : 4
                    height: width
                    visible: row.checked && row.kind !== "action"
                    color: row.fg
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: row.title
                color: row.fg
                font.pixelSize: row.compact ? 15 : 16
                font.weight: row.compact ? Font.Normal : Font.Medium
                elide: Text.ElideRight
            }
            Label {
                visible: row.text !== ""
                Layout.fillWidth: true
                text: row.text
                color: row.fgSoft
                font.pixelSize: 14
                wrapMode: Text.Wrap
                lineHeight: 1.15
            }
        }
        Label {
            visible: row.kind === "action" && row.tag === "" && !row.compact
            text: "\u2192"
            color: row.fg
            font.pixelSize: 20
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: row.hot ? 0 : 6
        }
        Label {
            visible: row.tag !== ""
            text: row.tag
            color: row.fgSoft
            font.family: app.fMono
            font.pixelSize: 12
            font.letterSpacing: 0.5
            Layout.alignment: row.text !== "" && !row.compact ? Qt.AlignTop : Qt.AlignVCenter
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: row.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (row.enabled) { row.forceActiveFocus(); row.clicked() }
    }
}
