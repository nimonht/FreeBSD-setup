// A thin ruled track with ticks and a square handle.
import QtQuick
import QtQuick.Controls

Slider {
    id: s
    implicitHeight: 36
    background: Item {
        x: s.leftPadding
        y: s.topPadding + s.availableHeight / 2
        width: s.availableWidth
        height: 1
        Rectangle {
            width: parent.width
            height: 1
            color: app.cInk
        }
        Rectangle {
            width: s.visualPosition * parent.width
            height: 3
            y: -1
            color: app.cInk
        }
        Repeater {
            model: 11
            Rectangle {
                x: index * (parent.width - 1) / 10
                y: index % 5 === 0 ? -9 : -5
                width: 1
                height: index % 5 === 0 ? 9 : 5
                color: app.cInk
            }
        }
    }
    handle: Rectangle {
        x: s.leftPadding + s.visualPosition * (s.availableWidth - width)
        y: s.topPadding + s.availableHeight / 2 - height / 2
        width: 12
        height: 24
        color: s.pressed ? app.cPaper : app.cInk
        border.width: 1
        border.color: app.cInk
    }
}
