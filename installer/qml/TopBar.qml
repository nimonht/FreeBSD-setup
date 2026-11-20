// The strip along the top: who is installing what.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    implicitHeight: 46

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        spacing: 12
        Image {
            source: installer.logoUrl
            sourceSize.width: 22
            sourceSize.height: 22
            Layout.preferredWidth: 22
            Layout.preferredHeight: 22
        }
        Label {
            text: app.distroName
            color: app.cInk
            font.pixelSize: 13
            font.weight: Font.Medium
            font.letterSpacing: 4
            font.capitalization: Font.AllUppercase
        }
        Rectangle {
            Layout.preferredWidth: 1
            Layout.preferredHeight: 14
            color: app.cInk
        }
        Label {
            text: "Installer"
            color: app.cSoft
            font.pixelSize: 13
            font.letterSpacing: 4
            font.capitalization: Font.AllUppercase
        }
        Item { Layout.fillWidth: true }
        Rectangle {
            visible: installer.demo
            Layout.preferredHeight: 22
            Layout.preferredWidth: demoLabel.implicitWidth + 18
            color: app.cOchre
            Label {
                id: demoLabel
                anchors.centerIn: parent
                text: "DEMO: NOTHING IS CHANGED"
                color: app.cPaper
                font.family: app.fMono
                font.pixelSize: 11
                font.letterSpacing: 1
            }
        }
        Label {
            text: (installer.distro.DISTRO_VERSION + " " + installer.distro.DISTRO_CODENAME).toUpperCase()
                  + "  ·  FREEBSD " + (installer.distro.FREEBSD_RELEASE || "").replace("-RELEASE", "")
            color: app.cSoft
            font.family: app.fMono
            font.pixelSize: 12
            font.letterSpacing: 1
        }
    }
    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: app.cInk
    }
}
