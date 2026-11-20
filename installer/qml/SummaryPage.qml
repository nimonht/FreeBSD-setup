// Everything chosen, one last time. Erasing a disk needs a tick.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    title: "Summary"
    subtitle: "Check your choices. Installing takes 30 to 90 minutes, mostly downloading; you can keep using this computer meanwhile."
    code: app.stepCode(8)
    ready: app.installMode !== "erase" || app.eraseConfirmed
    hint: ready ? "" : "Tick the box to confirm erasing the disk"

    readonly property var d: app.selectedDisk
    readonly property var rows: {
        if (!d) return []
        var desk = { kde: "KDE Plasma", hyprland: "Hyprland with Caelestia", both: "KDE Plasma and Hyprland", none: "None (text console)" }[app.desktop]
        var extras = []
        if (app.apps) extras.push("everyday apps")
        if (app.printing) extras.push("printing")
        if (app.gaming) extras.push("gaming")
        if (app.dev) extras.push("developer tools")
        if (app.firewall) extras.push("firewall")
        if (app.snapshots) extras.push("snapshots")
        var langLabel = app.language, lay = app.layout
        installer.languages.forEach(function (l) { if (l.code === app.language) langLabel = l.label })
        installer.layouts.forEach(function (l) { if (l.xkb === app.layout) lay = l.label })
        var hyp = app.desktop === "hyprland" || app.desktop === "both"
        return [
            ["Disk", d.descr + " (" + d.name + ", " + d.gb + " GB)"],
            ["What happens", app.installMode === "erase" ? "The whole disk is erased"
                             : "Added in the free space (" + app.sizeGb + " GB); nothing existing is changed"],
            ["Encryption", app.encrypt ? "Yes: a passphrase at every start" : "No"],
            ["Starts first", app.bootFirst ? app.distroName : "Unchanged"],
            ["Language", langLabel + ", keyboard " + lay],
            ["Time zone", app.timezone.replace(/_/g, " ")],
            ["Account", app.fullname + " (" + app.username + "), computer name " + app.hostname],
            ["Desktop", desk],
            ["Updates", app.pkgBranch === "latest" || hyp ? "Newest packages (latest)" : "Quarterly packages"],
            ["Extras", extras.length ? extras.join(", ") : "none"]
        ]
    }

    ColumnLayout {
        width: parent.width
        spacing: 24

        Panel {
            Layout.fillWidth: true
            title: "Plan"
            ColumnLayout {
                width: parent.width
                spacing: 0
                Repeater {
                    model: rows
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 10
                            Layout.bottomMargin: 10
                            spacing: 24
                            Label {
                                Layout.preferredWidth: 150
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 2
                                text: modelData[0]
                                color: app.cSoft
                                font.pixelSize: 12
                                font.weight: Font.Medium
                                font.letterSpacing: 2
                                font.capitalization: Font.AllUppercase
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData[1]
                                wrapMode: Text.Wrap
                                color: index === 1 && app.installMode === "erase" ? app.cSignal : app.cInk
                                font.weight: index === 1 ? Font.Medium : Font.Normal
                            }
                        }
                        Rectangle {
                            visible: index < rows.length - 1
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            color: app.cWeak
                        }
                    }
                }
            }
        }

        Panel {
            visible: app.installMode === "erase"
            Layout.fillWidth: true
            title: "Erasing"
            accent: app.cSignal
            ColumnLayout {
                width: parent.width
                spacing: 12
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: app.cInk
                    lineHeight: 1.2
                    text: d ? "Everything on " + d.descr + " (" + d.gb + " GB) will be deleted: " + d.contents + "."
                              + (d.efi !== "" ? " This disk also starts " + d.efi + "; if one of these systems lives on another disk, it will no longer start." : "")
                            : ""
                }
                MenuRow {
                    kind: "check"
                    danger: true
                    compact: true
                    title: "I understand: erase this disk"
                    checked: app.eraseConfirmed
                    onClicked: app.eraseConfirmed = !app.eraseConfirmed
                }
            }
        }
    }
}
