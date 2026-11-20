// Time zone: search by city, country or region.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property bool ready: app.timezone !== ""
    property string hint: ""
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
        anchors.margins: 40
        spacing: 16

        PageHeader {
            title: "Time zone"
            subtitle: "Chosen: " + app.timezone.replace(/_/g, " ") + ". Search for your city or a city near you."
        }

        TextField {
            Layout.fillWidth: true
            placeholderText: "Search: city, country or region"
            onTextChanged: parent.parent.filter = text
        }

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            padding: 8
            ListView {
                id: zones
                anchors.fill: parent
                clip: true
                model: shown
                ScrollBar.vertical: ScrollBar {}
                delegate: ItemDelegate {
                    width: zones.width
                    highlighted: app.timezone === modelData.zone
                    text: modelData.city + "  —  " + modelData.region + (modelData.comment !== "" ? " (" + modelData.comment + ")" : "")
                    onClicked: {
                        app.timezone = modelData.zone
                        app.zoneTouched = true
                    }
                }
            }
        }
    }
}
