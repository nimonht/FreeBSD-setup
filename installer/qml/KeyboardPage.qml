// Language of the new desktop and the keyboard layout (used at once, so
// passwords are typed as they will be at the login screen).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property bool ready: app.language !== "" && app.layout !== ""
    property string hint: ""

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 20

        PageHeader {
            title: "Language and keyboard"
            subtitle: "The language of your desktop, and the keyboard you type on. The keyboard changes right away."
        }

        RowLayout {
            spacing: 20
            Layout.fillWidth: true
            Layout.fillHeight: true

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 8
                ColumnLayout {
                    anchors.fill: parent
                    Label {
                        text: "Language"
                        font.bold: true
                        color: app.cText
                        Layout.margins: 10
                    }
                    ListView {
                        id: langList
                        clip: true
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: installer.languages
                        ScrollBar.vertical: ScrollBar {}
                        delegate: ItemDelegate {
                            width: langList.width
                            text: modelData.label
                            highlighted: app.language === modelData.code
                            onClicked: app.setLanguage(modelData.code)
                        }
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                Layout.fillHeight: true
                padding: 8
                ColumnLayout {
                    anchors.fill: parent
                    Label {
                        text: "Keyboard layout"
                        font.bold: true
                        color: app.cText
                        Layout.margins: 10
                    }
                    ListView {
                        id: layoutList
                        clip: true
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: installer.layouts
                        ScrollBar.vertical: ScrollBar {}
                        delegate: ItemDelegate {
                            width: layoutList.width
                            text: modelData.label
                            highlighted: app.layout === modelData.xkb
                            onClicked: app.setLayout(modelData.xkb, true)
                        }
                    }
                }
            }
        }

        TextField {
            Layout.fillWidth: true
            placeholderText: "Type here to test the keyboard"
        }
    }
}
