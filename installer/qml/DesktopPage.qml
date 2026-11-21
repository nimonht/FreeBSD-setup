// Desktop, updates and extras: the same choices as the text installer
// (lib/wizard.sh).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    title: "Desktop"
    subtitle: "Everything here can be changed later with: doas freebsd-setup"
    code: app.stepCode(7)
    ready: true

    property bool touched: false
    onVisibleChanged: if (visible && app.hw.HW_DESKTOP === "no" && app.desktop === "kde" && !touched) app.desktop = "none"
    readonly property bool hypr: app.desktop === "hyprland" || app.desktop === "both"

    ColumnLayout {
        width: parent.width
        spacing: 24

        Panel {
            visible: app.hw.HW_DESKTOP === "no"
            Layout.fillWidth: true
            title: "No graphical desktop here"
            accent: app.cOchre
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: app.cInk
                text: "A graphical desktop will not start on this computer (" + (app.hw.HW_DESKTOP_WHY || "")
                      + "). Choose None unless the disk will move to another computer."
            }
        }

        Panel {
            Layout.fillWidth: true
            title: "Desktop"
            padding: 8
            ColumnLayout {
                width: parent.width
                spacing: 6
                MenuRow {
                    title: "KDE Plasma"
                    tag: "RECOMMENDED"
                    text: "Familiar and complete, easy if you come from Windows. Files, settings and apps in one place."
                    checked: app.desktop === "kde"
                    onClicked: { app.desktop = "kde"; touched = true }
                }
                MenuRow {
                    title: "Hyprland with the Caelestia shell"
                    text: "A modern tiling desktop driven by the keyboard, for the adventurous. Built from source while installing."
                    checked: app.desktop === "hyprland"
                    onClicked: { app.desktop = "hyprland"; touched = true }
                }
                MenuRow {
                    title: "Both"
                    text: "Choose KDE Plasma or Hyprland at the login screen."
                    checked: app.desktop === "both"
                    onClicked: { app.desktop = "both"; touched = true }
                }
                MenuRow {
                    title: "None"
                    text: "Text console only: servers, or computers without a supported graphics card."
                    checked: app.desktop === "none"
                    onClicked: { app.desktop = "none"; touched = true }
                }
            }
        }

        Panel {
            Layout.fillWidth: true
            title: "Updates"
            padding: 8
            ColumnLayout {
                width: parent.width
                spacing: 6
                MenuRow {
                    title: "Newest"
                    tag: "LATEST"
                    text: "FreeBSD's newest packages, updated every week."
                    checked: app.pkgBranch === "latest" || hypr
                    onClicked: app.pkgBranch = "latest"
                }
                MenuRow {
                    enabled: !hypr
                    title: "Steadier"
                    tag: "QUARTERLY"
                    text: hypr ? "Hyprland and Caelestia need the newest packages."
                               : "New versions every three months; security fixes in between."
                    checked: app.pkgBranch === "quarterly" && !hypr
                    onClicked: app.pkgBranch = "quarterly"
                }
            }
        }

        Panel {
            Layout.fillWidth: true
            title: "Extras"
            padding: 8
            ColumnLayout {
                width: parent.width
                spacing: 6
                MenuRow {
                    kind: "check"
                    title: "Everyday apps"
                    text: "Firefox, LibreOffice, VLC, GIMP."
                    checked: app.apps
                    onClicked: app.apps = !app.apps
                }
                MenuRow {
                    kind: "check"
                    title: "Printers and scanners"
                    text: "Network printers are found by themselves."
                    checked: app.printing
                    onClicked: app.printing = !app.printing
                }
                MenuRow {
                    kind: "check"
                    title: "Gaming"
                    text: "Steam, Wine and Proton, MangoHud. Many games run; games with anti-cheat do not."
                    checked: app.gaming
                    onClicked: app.gaming = !app.gaming
                }
                MenuRow {
                    kind: "check"
                    title: "Developer tools"
                    text: "VS Code, compilers, build tools."
                    checked: app.dev
                    onClicked: app.dev = !app.dev
                }
                MenuRow {
                    kind: "check"
                    title: "Firewall"
                    text: "Blocks connections from outside that you did not ask for."
                    checked: app.firewall
                    onClicked: app.firewall = !app.firewall
                }
                MenuRow {
                    kind: "check"
                    title: "Automatic snapshots"
                    text: "Hourly and daily versions of your files to go back to."
                    checked: app.snapshots
                    onClicked: app.snapshots = !app.snapshots
                }
            }
        }

        RowLayout {
            visible: app.desktop !== "none"
            Layout.fillWidth: true
            spacing: 26

            Panel {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                title: "Terminal style"
                padding: 8
                ColumnLayout {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: [{ value: "fish", label: "Friendly (fish): suggestions as you type" },
                                { value: "zsh", label: "Zsh: close to bash" },
                                { value: "bash", label: "Bash with colours" },
                                { value: "none", label: "Plain" }]
                        delegate: MenuRow {
                            compact: true
                            title: modelData.label
                            checked: app.terminal === modelData.value
                            onClicked: app.terminal = modelData.value
                        }
                    }
                }
            }
            Panel {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                title: "Typing in other scripts"
                tag: "CTRL+SPACE"
                padding: 8
                ColumnLayout {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: [{ code: "vi", label: "Vietnamese" }, { code: "zh-cn", label: "Chinese (Pinyin)" },
                                { code: "zh-tw", label: "Chinese (Zhuyin)" }, { code: "ja", label: "Japanese" },
                                { code: "ko", label: "Korean" }, { code: "m17n", label: "Thai, Hindi and more" }]
                        delegate: MenuRow {
                            kind: "check"
                            compact: true
                            title: modelData.label
                            checked: app.inputMethods.indexOf(modelData.code) >= 0
                            onClicked: {
                                var on = app.inputMethods.indexOf(modelData.code) >= 0
                                var l = app.inputMethods.filter(function (x) { return x !== modelData.code })
                                if (!on) l.push(modelData.code)
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
