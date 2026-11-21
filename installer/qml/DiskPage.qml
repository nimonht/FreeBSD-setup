// Which disk, and how: next to the systems already on it (in its free
// space), or erasing it. Disk encryption, and which system starts first.
// The checks are install.sh's own (--probe): nothing here guesses.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    id: page
    title: "Disk"
    subtitle: "Where " + app.distroName + " goes. Nothing is written until you confirm on the Summary page."
    code: app.stepCode(4)

    readonly property var d: app.selectedDisk
    readonly property var other: d ? (app.probe.other || {})[d.name] : undefined
    readonly property var boot: d ? (app.probe.boot || {})[d.name] : undefined
    readonly property bool passOk: !app.encrypt || app.diskUsesLoginPassword
                                    || (pass1.text !== "" && pass1.text === pass2.text && installer.isAscii(pass1.text))
    ready: d !== null && app.installMode !== "" && passOk
    hint: d === null ? "Choose a disk" : app.installMode === "" ? "Choose how to install" : ""

    function gb(n) { return n + " GB" }

    onVisibleChanged: {
        if (!visible) return
        if (app.disk === "") app.disk = installer.defaultDisk()
        pickMode()
    }
    function pickMode() {
        if (!d) { app.installMode = ""; return }
        if (app.installMode === "alongside" && !d.alongside) app.installMode = ""
        if (app.installMode === "") app.installMode = d.alongside ? "alongside" : (d.contents === "empty" ? "erase" : "")
        if (app.sizeGb < app.probe.min_gb || app.sizeGb > d.free_gb) app.sizeGb = d.free_gb
    }

    ColumnLayout {
        width: parent.width
        spacing: 24

        Panel {
            Layout.fillWidth: true
            title: "Disk"
            tag: (app.probe.disks || []).length + " FOUND"
            padding: 8
            ColumnLayout {
                width: parent.width
                spacing: 6
                Repeater {
                    model: app.probe.disks || []
                    delegate: MenuRow {
                        enabled: modelData.gb >= (app.probe.min_gb || 30)
                        title: modelData.descr
                        tag: (modelData.removable ? "USB  " : "") + modelData.name + "  " + gb(modelData.gb)
                        text: !enabled ? "Too small: at least " + (app.probe.min_gb || 30) + " GB is needed."
                              : "Holds: " + modelData.contents + (modelData.efi !== "" ? ". Starts: " + modelData.efi : "")
                        checked: app.disk === modelData.name
                        onClicked: {
                            app.disk = modelData.name
                            app.installMode = ""
                            app.eraseConfirmed = false
                            page.pickMode()
                        }
                    }
                }
            }
        }

        Panel {
            visible: page.d !== null
            Layout.fillWidth: true
            title: "How"
            padding: 8
            ColumnLayout {
                width: parent.width
                spacing: 6
                MenuRow {
                    visible: page.d !== null && page.d.contents !== "empty"
                    enabled: page.d !== null && page.d.alongside
                    title: "Install next to what is on it"
                    tag: page.d && page.d.alongside ? gb(page.d.free_gb) + " FREE" : ""
                    text: !page.d ? "" : page.d.alongside
                          ? "Uses the free space. Windows, Linux and your files stay as they are."
                          : "Not possible: " + page.d.why + "."
                    checked: app.installMode === "alongside"
                    onClicked: app.installMode = "alongside"
                }
                RowLayout {
                    visible: app.installMode === "alongside" && page.d !== null
                    Layout.fillWidth: true
                    Layout.leftMargin: 42
                    Layout.rightMargin: 14
                    Layout.topMargin: 4
                    Layout.bottomMargin: 8
                    spacing: 18
                    Label {
                        text: "Size"
                        color: app.cSoft
                        font.pixelSize: 12
                        font.weight: Font.Medium
                        font.letterSpacing: 2
                        font.capitalization: Font.AllUppercase
                    }
                    LSlider {
                        Layout.fillWidth: true
                        from: app.probe.min_gb || 30
                        to: page.d ? Math.max(page.d.free_gb, from) : 100
                        stepSize: 1
                        value: app.sizeGb
                        onMoved: app.sizeGb = Math.round(value)
                    }
                    Label {
                        text: app.sizeGb + " GB"
                        color: app.cInk
                        font.family: app.fMono
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: 80
                    }
                }
                MenuRow {
                    visible: page.d !== null
                    danger: true
                    title: "Erase this disk and install"
                    text: !page.d ? "" : page.d.contents === "empty" ? "The disk is empty."
                          : "Deletes everything on it: " + page.d.contents + "."
                    checked: app.installMode === "erase"
                    onClicked: app.installMode = "erase"
                }
            }
        }

        Panel {
            id: bootPanel
            readonly property bool alongside: app.installMode === "alongside" && page.boot !== undefined
            readonly property bool otherDisk: app.installMode === "erase" && page.other !== undefined
            visible: alongside || otherDisk
            Layout.fillWidth: true
            title: "Starting the computer"
            padding: 8
            ColumnLayout {
                width: parent.width
                spacing: 6
                Label {
                    Layout.fillWidth: true
                    Layout.margins: 10
                    wrapMode: Text.Wrap
                    color: app.cInk
                    lineHeight: 1.2
                    text: bootPanel.otherDisk ? (page.other ? page.other.name + " starts from another disk and is not touched." : "")
                          : bootPanel.alongside ? app.distroName + " can be started from:\n▪  "
                                                  + installer.bootPlaces(app.disk).join("\n▪  ") : ""
                }
                MenuRow {
                    compact: true
                    title: "Keep " + (page.boot && page.boot.default !== "" ? page.boot.default
                                      : page.other ? page.other.name : "the current system") + " first"
                    checked: !app.bootFirst
                    onClicked: app.bootFirst = false
                }
                MenuRow {
                    compact: true
                    title: "Start " + app.distroName + " first"
                    checked: app.bootFirst
                    onClicked: app.bootFirst = true
                }
            }
        }

        Panel {
            visible: app.probe.bitlocker === true
            Layout.fillWidth: true
            title: "Windows is encrypted (BitLocker)"
            accent: app.cOchre
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: app.cInk
                lineHeight: 1.2
                text: (app.probe.secureboot && app.probe.secureboot.plan === "shim")
                      ? "Secure Boot stays on, so Windows starts as before. Started from " + app.distroName
                        + "'s own menu (key L) it may ask for its 48-digit recovery key: have it ready (aka.ms/myrecoverykey)."
                      : "Because " + app.distroName + " needs Secure Boot switched off, Windows will ask once for its 48-digit "
                        + "recovery key. Have it ready: aka.ms/myrecoverykey"
            }
        }

        Panel {
            visible: page.d !== null
            Layout.fillWidth: true
            title: "Encryption"
            ColumnLayout {
                width: parent.width
                spacing: 14
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 20
                    Label {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: app.cInk
                        lineHeight: 1.2
                        text: "Recommended for laptops: nobody can read your files without the passphrase, "
                              + "which you type every time the computer starts."
                    }
                    Segmented {
                        model: [{ value: "off", label: "Off" }, { value: "on", label: "On" }]
                        value: app.encrypt ? "on" : "off"
                        onPicked: (v) => app.encrypt = (v === "on")
                    }
                }
                MenuRow {
                    visible: app.encrypt && app.layout === "us"
                    kind: "check"
                    compact: true
                    title: "Use my login password as the passphrase"
                    checked: app.diskUsesLoginPassword
                    onClicked: app.diskUsesLoginPassword = !app.diskUsesLoginPassword
                }
                Label {
                    visible: app.encrypt && app.layout !== "us"
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: app.cOchre
                    lineHeight: 1.2
                    text: "When the computer starts, the keyboard is always US English, so the passphrase is typed with that layout. "
                          + "While you type it below, the keyboard switches to US English. Letters, digits and simple symbols only."
                }
                RowLayout {
                    visible: app.encrypt && (!app.diskUsesLoginPassword || app.layout !== "us")
                    Layout.fillWidth: true
                    spacing: 20
                    LField {
                        id: pass1
                        label: "Disk passphrase"
                        secret: true
                        onEdited: app.passphrase = text
                        error: app.encrypt && pass1.text !== "" && !installer.isAscii(pass1.text)
                               ? "Use letters, digits and simple symbols only (no accents)." : ""
                    }
                    LField {
                        id: pass2
                        label: "The same again"
                        secret: true
                        error: pass2.text !== "" && pass1.text !== pass2.text ? "The two passphrases are not the same." : ""
                    }
                }
            }
        }
    }

    Connections {
        target: pass1.field
        function onActiveFocusChanged() {
            if (app.layout !== "us") installer.setKeyboard(pass1.field.activeFocus ? "us" : app.layout)
        }
    }
    Connections {
        target: pass2.field
        function onActiveFocusChanged() {
            if (app.layout !== "us") installer.setKeyboard(pass2.field.activeFocus ? "us" : app.layout)
        }
    }
    Connections {
        target: app
        function onLayoutChanged() {
            if (app.layout !== "us") app.diskUsesLoginPassword = false
        }
    }
}
