// A thin ink scroll bar, visible while it matters.
import QtQuick
import QtQuick.Controls

ScrollBar {
    id: sb
    implicitWidth: 6
    contentItem: Rectangle {
        implicitWidth: 4
        color: app.cInk
        opacity: sb.policy === ScrollBar.AlwaysOn || sb.active ? 0.6 : 0.25
    }
    background: Rectangle {
        implicitWidth: 6
        color: "transparent"
    }
}
