// Activity: four small squares lit in turn. Only shown while something
// is really happening.
import QtQuick

Row {
    id: busy
    property bool running: true
    property int lit: 0
    spacing: 4
    visible: running

    Timer {
        interval: 140
        repeat: true
        running: busy.running && busy.visible
        onTriggered: busy.lit = (busy.lit + 1) % 4
    }
    Repeater {
        model: 4
        Rectangle {
            width: 7
            height: 7
            color: app.cInk
            opacity: index === busy.lit ? 1 : 0.25
        }
    }
}
