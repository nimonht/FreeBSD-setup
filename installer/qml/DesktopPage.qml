// Desktop and extras: the same choices as the text installer (lib/wizard.sh).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property bool ready: true
    property string hint: ""

    onVisibleChanged: if (visible && app.hw.HW_DESKTOP === "no" && app.desktop === "kde" && !touched) app.desktop = "none"
    property bool touched: false

    component Extra: RowLayout {
        property string title
        property string text
        property bool on
        signal toggled(bool value)
        Layout.fillWidth: true
        spacing: 12
        ColumnLayout {
            spacing: 0
            Layout.fillWidth: true
            Label {
                text: parent.parent.title
                color: app.cText
                font.bold: true
            }
            Label {
                text: parent.parent.text
                color: app.cMuted
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
        Switch {
            checked: parent.on
            onToggled: parent.toggled(checked)
        }
    }

    Flickable {
        anchors.fill: parent
        contentHeight: col.implicitHeight + 80
        clip: true
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: col
            x: 40
            y: 40
            width: parent.width - 80
            spacing: 14

            PageHeader {
                title: "Desktop and apps"
                subtitle: "Everything can be changed later with: doas freebsd-setup"
            }

            Card {
                visible: app.hw.HW_DESKTOP === "no"
                accent: app.cWarn
                Layout.fillWidth: true
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: app.cText
                    text: "A graphical desktop will not start on this computer (" + (app.hw.HW_DESKTOP_WHY || "") + "). Choose None unless you will move the disk to another computer."
                }
            }

            GridLayout {
                columns: width > 820 ? 2 : 1
                columnSpacing: 14
                rowSpacing: 14
                Layout.fillWidth: true
                ChoiceCard {
                    title: "KDE Plasma"
                    badge: "RECOMMENDED"
                    text: "Familiar and complete, easy if you come from Windows. Firefox, files, settings, all in one place."
                    checked: app.desktop === "kde"
                    onClicked: { app.desktop = "kde"; touched = true }
                }
                ChoiceCard {
                    title: "Hyprland + Caelestia"
                    text: "A modern tiling desktop driven by the keyboard, for the adventurous. Built from source while installing."
                    checked: app.desktop === "hyprland"
                    onClicked: { app.desktop = "hyprland"; touched = true }
                }
                ChoiceCard {
                    title: "Both"
                    text: "Choose KDE Plasma or Hyprland at the login screen."
                    checked: app.desktop === "both"
                    onClicked: { app.desktop = "both"; touched = true }
                }
                ChoiceCard {
                    title: "None"
                    text: "Text console only: servers, or computers without a supported graphics card."
                    checked: app.desktop === "none"
                    onClicked: { app.desktop = "none"; touched = true }
                }
            }

            Card {
                id: branchCard
                Layout.fillWidth: true
                readonly property bool hypr: app.desktop === "hyprland" || app.desktop === "both"
                ColumnLayout {
                    width: parent.width
                    spacing: 6
                    Label {
                        text: "Updates"
                        color: app.cText
                        font.bold: true
                    }
                    RadioButton {
                        text: "Newest: FreeBSD's \"latest\" packages, updated every week (recommended)"
                        checked: app.pkgBranch === "latest" || branchCard.hypr
                        onClicked: app.pkgBranch = "latest"
                    }
                    RadioButton {
                        text: "Steadier: \"quarterly\" packages, new versions every three months, security fixes in between"
                        enabled: !branchCard.hypr
                        checked: app.pkgBranch === "quarterly" && !branchCard.hypr
                        onClicked: app.pkgBranch = "quarterly"
                    }
                    Label {
                        visible: branchCard.hypr
                        text: "Hyprland and Caelestia need the newest packages."
                        color: app.cMuted
                        Layout.leftMargin: 8
                    }
                }
            }

            Card {
                Layout.fillWidth: true
                ColumnLayout {
                    width: parent.width
                    spacing: 12
                    Extra {
                        title: "Everyday apps"
                        text: "Firefox, LibreOffice, VLC, GIMP"
                        on: app.apps
                        onToggled: (v) => app.apps = v
                    }
                    Extra {
                        title: "Printers and scanners"
                        text: "Network printers are found by themselves"
                        on: app.printing
                        onToggled: (v) => app.printing = v
                    }
                    Extra {
                        title: "Gaming"
                        text: "Steam, Wine/Proton, MangoHud. Many games run; games with anti-cheat do not"
                        on: app.gaming
                        onToggled: (v) => app.gaming = v
                    }
                    Extra {
                        title: "Developer tools"
                        text: "VS Code, compilers, build tools"
                        on: app.dev
                        onToggled: (v) => app.dev = v
                    }
                    Extra {
                        title: "Firewall"
                        text: "Blocks connections from outside that you did not ask for"
                        on: app.firewall
                        onToggled: (v) => app.firewall = v
                    }
                    Extra {
                        title: "Automatic snapshots"
                        text: "Hourly and daily versions of your files to go back to (ZFS)"
                        on: app.snapshots
                        onToggled: (v) => app.snapshots = v
                    }
                }
            }

            Card {
                visible: app.desktop !== "none"
                Layout.fillWidth: true
                ColumnLayout {
                    width: parent.width
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Label {
                                text: "Terminal style"
                                color: app.cText
                                font.bold: true
                            }
                            Label {
                                text: "How the terminal app behaves. Your login shell is not changed."
                                color: app.cMuted
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                        ComboBox {
                            id: term
                            Layout.preferredWidth: 300
                            textRole: "label"
                            valueRole: "value"
                            model: [
                                { value: "fish", label: "Friendly (fish): suggestions" },
                                { value: "zsh", label: "Zsh: close to bash" },
                                { value: "bash", label: "Bash with colours" },
                                { value: "none", label: "Plain" }
                            ]
                            Component.onCompleted: currentIndex = indexOfValue(app.terminal)
                            onActivated: app.terminal = currentValue
                        }
                    }
                    Label {
                        text: "Typing in other scripts (switch with Ctrl+Space)"
                        color: app.cText
                        font.bold: true
                    }
                    Flow {
                        Layout.fillWidth: true
                        spacing: 6
                        Repeater {
                            model: [
                                { code: "vi", label: "Vietnamese" }, { code: "zh-cn", label: "Chinese (Pinyin)" },
                                { code: "zh-tw", label: "Chinese (Zhuyin)" }, { code: "ja", label: "Japanese" },
                                { code: "ko", label: "Korean" }, { code: "m17n", label: "Thai, Hindi and more" }
                            ]
                            delegate: CheckBox {
                                text: modelData.label
                                checked: app.inputMethods.indexOf(modelData.code) >= 0
                                onToggled: {
                                    var l = app.inputMethods.filter(function (x) { return x !== modelData.code })
                                    if (checked) l.push(modelData.code)
                                    app.inputMethods = l
                                    app.imTouched = true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
