// A rounded panel. Put a layout inside; it gets 20 px of padding.
import QtQuick

Rectangle {
    id: card
    default property alias content: inner.data
    property int padding: 20
    property color accent: "transparent"
    color: app.cCard
    radius: 14
    border.width: accent === "transparent" ? 1 : 2
    border.color: accent === "transparent" ? app.cLine : accent
    // from the (one) child's own size: never from its position, which can
    // depend on the card's size
    implicitHeight: (inner.children.length > 0 ? inner.children[0].implicitHeight : 0) + 2 * padding
    implicitWidth: (inner.children.length > 0 ? inner.children[0].implicitWidth : 0) + 2 * padding

    Item {
        id: inner
        anchors.fill: parent
        anchors.margins: card.padding
    }
}
