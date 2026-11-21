// Language of the new desktop and the keyboard layout (used at once, so
// passwords are typed as they will be at the login screen).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    title: "Language"
    subtitle: "The language of your desktop, and the keyboard you type on. The keyboard changes right away."
    code: app.stepCode(1)
    scroll: false
    ready: app.language !== "" && app.layout !== ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 22

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 26

            Panel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "Language"
                tag: installer.languages.length + " AVAILABLE"
                padding: 8
                ListView {
                    id: langs
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    model: installer.languages
                    ScrollBar.vertical: LScrollBar {}
                    delegate: MenuRow {
                        width: langs.width - 10
                        compact: true
                        title: modelData.label
                        checked: app.language === modelData.code
                        onClicked: app.setLanguage(modelData.code)
                    }
                }
            }
            Panel {
                Layout.fillWidth: true
                Layout.fillHeight: true
                title: "Keyboard layout"
                tag: installer.layouts.length + " AVAILABLE"
                padding: 8
                ListView {
                    id: layouts
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    model: installer.layouts
                    ScrollBar.vertical: LScrollBar {}
                    delegate: MenuRow {
                        width: layouts.width - 10
                        compact: true
                        title: modelData.label
                        tag: modelData.xkb
                        checked: app.layout === modelData.xkb
                        onClicked: app.setLayout(modelData.xkb, true)
                    }
                }
            }
        }

        LField {
            label: "Try your keyboard"
            placeholder: "Type a few letters to check them"
        }
    }
}
