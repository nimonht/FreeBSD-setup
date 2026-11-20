// A page's title: capitals, light, wide, with a hard offset shadow; it
// decodes into place when the page opens (a few frames of signs, then the
// words). Under it a rule with a short bar, and one line of explanation.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: h
    property string title: ""
    property string subtitle: ""
    property string code: ""
    property string shown: title
    property int tick: 0
    readonly property string signs: "/\\|-_=<>+01"

    spacing: 10
    Layout.fillWidth: true

    function play() {
        tick = 0
        decode.restart()
    }
    onTitleChanged: shown = title

    Timer {
        id: decode
        interval: 28
        repeat: true
        onTriggered: {
            h.tick++
            var n = h.title.length, k = Math.floor(h.tick * n / 9)
            if (k >= n) {
                h.shown = h.title
                stop()
                return
            }
            var s = h.title.substr(0, k)
            for (var i = k; i < n; i++)
                s += h.title[i] === " " ? " " : h.signs[Math.floor(Math.random() * h.signs.length)]
            h.shown = s
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        Item {
            Layout.fillWidth: true
            implicitHeight: titleLabel.implicitHeight
            Label {
                x: 3
                y: 3
                text: h.shown
                color: app.cWeak
                font: titleLabel.font
            }
            Label {
                id: titleLabel
                text: h.shown
                color: app.cInk
                font.pixelSize: 30
                font.weight: Font.Light
                font.letterSpacing: 6
                font.capitalization: Font.AllUppercase
            }
        }
        Label {
            visible: h.code !== ""
            text: h.code
            color: app.cSoft
            font.family: app.fMono
            font.pixelSize: 12
            font.letterSpacing: 1
            Layout.alignment: Qt.AlignBottom
            Layout.bottomMargin: 6
        }
    }
    Item {
        Layout.fillWidth: true
        implicitHeight: 7
        Rectangle {
            y: 3
            width: parent.width
            height: 1
            color: app.cInk
        }
        Rectangle {
            y: 2
            width: 44
            height: 3
            color: app.cInk
        }
        Rectangle {
            x: parent.width - 6
            y: 1
            width: 6
            height: 6
            color: app.cInk
        }
    }
    Label {
        visible: h.subtitle !== ""
        Layout.fillWidth: true
        Layout.maximumWidth: 760
        Layout.topMargin: 2
        text: h.subtitle
        color: app.cSoft
        font.pixelSize: 15
        wrapMode: Text.Wrap
        lineHeight: 1.2
    }
}
