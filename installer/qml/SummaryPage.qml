// Everything chosen, one last time. Erasing a disk needs a tick.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    property bool ready: app.installMode !== "erase" || app.eraseConfirmed
    property string hint: ready ? "" : "Tick the box to confirm"

    readonly property var d: app.selectedDisk
    readonly property var rows: {
        if (!d) return []
        var desk = { kde: "KDE Plasma", hyprland: "Hyprland + Caelestia", both: "KDE Plasma and Hyprland", none: "None (text console)" }[app.desktop]
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
        return [
            ["Disk", d.descr + " (" + d.name + ", " + d.gb + " GB)"],
            ["What happens", app.installMode === "erase" ? "The whole disk is ERASED" : "Added in the free space: " + app.sizeGb + " GB; nothing existing is changed"],
            ["Encryption", app.encrypt ? "Yes: passphrase at every start" : "No"],
            ["Starts first", app.bootFirst ? app.distroName : "Unchanged"],
            ["Language", langLabel + ", keyboard " + lay],
            ["Time zone", app.timezone.replace(/_/g, " ")],
            ["Account", app.fullname + " (" + app.username + "), computer name " + app.hostname],
            ["Desktop", desk],
            ["Updates", app.pkgBranch === "latest" || app.desktop === "hyprland" || app.desktop === "both"
                        ? "Newest packages (latest)" : "Quarterly packages"],
            ["Extras", extras.length ? extras.join(", ") : "none"]
        ]
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 18

        PageHeader {
            title: "Ready to install"
            subtitle: "Check your choices. The installation takes 30 to 90 minutes, mostly downloading; you can keep using this computer meanwhile."
        }

        Card {
            Layout.fillWidth: true
            GridLayout {
                width: parent.width
                columns: 2
                columnSpacing: 24
                rowSpacing: 10
                Repeater {
                    model: rows
                    delegate: Label {
                        Layout.row: index
                        Layout.column: 0
                        text: modelData[0]
                        color: app.cMuted
                    }
                }
                Repeater {
                    model: rows
                    delegate: Label {
                        Layout.row: index
                        Layout.column: 1
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: modelData[1]
                        color: index === 1 && app.installMode === "erase" ? app.cBad : app.cText
                        font.bold: index === 1
                    }
                }
            }
        }

        Card {
            visible: app.installMode === "erase"
            accent: app.cAccent2
            Layout.fillWidth: true
            ColumnLayout {
                width: parent.width
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: app.cText
                    text: d ? "Everything on " + d.descr + " (" + d.gb + " GB) will be deleted: " + d.contents + "."
                              + (d.efi !== "" ? " This disk also starts: " + d.efi + "; if one of these systems lives on another disk, it will no longer start." : "")
                            : ""
                }
                CheckBox {
                    text: "I understand: erase this disk"
                    checked: app.eraseConfirmed
                    onToggled: app.eraseConfirmed = checked
                }
            }
        }
        Item { Layout.fillHeight: true }
    }
}
