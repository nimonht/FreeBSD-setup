// Time zone: search by city, country or region.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    id: page
    title: "Time zone"
    subtitle: "Search for your city, or a city near you."
    code: app.stepCode(5)
    scroll: false
    ready: app.timezone !== ""

    property string filter: ""
    readonly property var shown: {
        var f = filter.toLowerCase(), out = [], zs = installer.timezones
        for (var i = 0; i < zs.length; i++) {
            var z = zs[i]
            if (f === "" || (z.city + " " + z.region + " " + z.comment + " " + z.zone).toLowerCase().indexOf(f) >= 0)
                out.push(z)
        }
        return out
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 22

        RowLayout {
            Layout.fillWidth: true
            spacing: 26
            LField {
                label: "Search"
                placeholder: "City, country or region"
                onEdited: page.filter = text
            }
            ColumnLayout {
                Layout.preferredWidth: 300
                Layout.alignment: Qt.AlignBottom
                spacing: 6
                Label {
                    text: "Chosen"
                    color: app.cSoft
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    font.letterSpacing: 2
                    font.capitalization: Font.AllUppercase
                }
                Label {
                    Layout.preferredHeight: 42
                    verticalAlignment: Text.AlignVCenter
                    text: app.timezone.replace(/_/g, " ")
                    color: app.cInk
                    font.family: app.fMono
                    font.pixelSize: 16
                }
            }
        }

        Panel {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "Time zones"
            tag: page.shown.length + " SHOWN"
            padding: 8
            ListView {
                id: zones
                anchors.fill: parent
                clip: true
                spacing: 4
                model: page.shown
                ScrollBar.vertical: LScrollBar {}
                delegate: MenuRow {
                    width: zones.width - 10
                    compact: true
                    title: modelData.city + (modelData.comment !== "" ? " (" + modelData.comment + ")" : "")
                    tag: modelData.region.toUpperCase()
                    checked: app.timezone === modelData.zone
                    onClicked: {
                        app.timezone = modelData.zone
                        app.zoneTouched = true
                    }
                }
            }
        }
    }
}
