// Progress as a row of segments; the next segment breathes while work
// goes on (it shows activity, not decoration).
import QtQuick

Item {
    id: m
    property real value: 0
    property bool active: true
    readonly property int seg: 10
    readonly property int gap: 3
    readonly property int count: Math.max(1, Math.floor((width + gap) / (seg + gap)))
    readonly property int filled: Math.floor(value * count)
    implicitHeight: 16

    Row {
        spacing: m.gap
        Repeater {
            model: m.count
            Rectangle {
                width: m.seg
                height: m.height
                color: app.cInk
                opacity: index < m.filled ? 1 : (index === m.filled && m.active ? pulse.v : 0.16)
            }
        }
    }
    QtObject {
        id: pulse
        property real v: 0.16
    }
    SequentialAnimation {
        running: m.active && m.visible
        loops: Animation.Infinite
        NumberAnimation { target: pulse; property: "v"; from: 0.16; to: 0.7; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { target: pulse; property: "v"; from: 0.7; to: 0.16; duration: 700; easing.type: Easing.InOutSine }
    }
}
