// The main action of a page (Next, Install now, Connect, Restart now):
// the sunrise gradient, so it stands out whatever the Qt style does.
import QtQuick
import QtQuick.Controls

Button {
    id: b
    property bool danger: false
    font.bold: true
    contentItem: Label {
        text: b.text
        font: b.font
        color: b.enabled ? "#1A1020" : app.cMuted
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        implicitWidth: 120
        implicitHeight: 42
        radius: 21
        opacity: b.enabled ? (b.down ? 0.8 : 1) : 0.35
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: b.danger ? app.cAccent2 : app.cAccent }
            GradientStop { position: 1; color: b.danger ? "#E0405A" : app.cAccent2 }
        }
    }
}
