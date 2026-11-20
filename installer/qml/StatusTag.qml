// What a hardware line means, in a word as well as a colour:
// OK, NOTE, LIMITED, NO (install.sh's report: OK, INFO, WARN, NO).
import QtQuick
import QtQuick.Controls

Rectangle {
    id: t
    property string status: "OK"
    readonly property var look: ({
        "OK": { text: "OK", fill: app.cInk, fg: app.cPaper },
        "INFO": { text: "NOTE", fill: "transparent", fg: app.cInk },
        "WARN": { text: "LIMITED", fill: app.cOchre, fg: app.cPaper },
        "NO": { text: "NO", fill: app.cSignal, fg: app.cPaper }
    })[status] || { text: status, fill: "transparent", fg: app.cInk }

    width: 72
    height: 22
    color: look.fill
    border.width: 1
    border.color: look.fill === "transparent" ? app.cInk : look.fill
    Label {
        anchors.centerIn: parent
        text: t.look.text
        color: t.look.fg
        font.family: app.fMono
        font.pixelSize: 11
        font.weight: Font.Medium
        font.letterSpacing: 1.2
    }
}
