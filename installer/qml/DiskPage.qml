// Which disk, and how: next to the systems already on it (in its free
// space), or erasing it. Disk encryption, and which system starts first.
// The checks are install.sh's own (--probe): nothing here guesses.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    readonly property var d: app.selectedDisk
    readonly property var other: d ? (app.probe.other || {})[d.name] : undefined
    readonly property var boot: d ? (app.probe.boot || {})[d.name] : undefined
    readonly property bool passOk: !app.encrypt || app.diskUsesLoginPassword
                                    || (pass1.text !== "" && pass1.text === pass2.text && installer.isAscii(pass1.text))
    property bool ready: d !== null && app.installMode !== "" && passOk
    property string hint: d === null ? "Choose a disk" : app.installMode === "" ? "Choose how to install" : ""

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
            spacing: 16

            PageHeader {
                title: "Where to install"
                subtitle: "Nothing is written until you confirm on the Summary page."
            }

            Label {
                text: "Disk"
                font.bold: true
                color: app.cText
            }
            Repeater {
                model: app.probe.disks || []
                delegate: ChoiceCard {
                    enabled: modelData.gb >= (app.probe.min_gb || 30)
                    title: modelData.descr + "  —  " + gb(modelData.gb)
                    badge: modelData.removable ? "USB / REMOVABLE" : modelData.name
                    text: !enabled ? "Too small: at least " + (app.probe.min_gb || 30) + " GB is needed."
                          : "Holds: " + modelData.contents + (modelData.efi !== "" ? "   ·   Starts: " + modelData.efi : "")
                    checked: app.disk === modelData.name
                    onClicked: {
                        app.disk = modelData.name
                        app.installMode = ""
                        app.eraseConfirmed = false
                        page.pickMode()
                    }
                }
            }

            Label {
                visible: page.d !== null
                text: "How"
                font.bold: true
                color: app.cText
                Layout.topMargin: 8
            }
            ChoiceCard {
                visible: page.d !== null && page.d.contents !== "empty"
                enabled: page.d !== null && page.d.alongside
                title: "Install next to what is on it"
                text: !page.d ? "" : page.d.alongside
                      ? "Uses the free space (" + gb(page.d.free_gb) + "). Windows, Linux and your files stay as they are."
                      : "Not possible: " + page.d.why + "."
                checked: app.installMode === "alongside"
                onClicked: app.installMode = "alongside"
            }
            RowLayout {
                visible: app.installMode === "alongside" && page.d !== null
                Layout.fillWidth: true
                Layout.leftMargin: 52
                spacing: 14
                Label {
                    text: "Size for " + app.distroName + ":"
                    color: app.cMuted
                }
                Slider {
                    id: sizeSlider
                    Layout.fillWidth: true
                    from: app.probe.min_gb || 30
                    to: page.d ? Math.max(page.d.free_gb, from) : 100
                    stepSize: 1
                    value: app.sizeGb
                    onMoved: app.sizeGb = Math.round(value)
                }
                Label {
                    text: app.sizeGb + " GB"
                    color: app.cText
                    font.bold: true
                    Layout.preferredWidth: 70
                }
            }
            ChoiceCard {
                visible: page.d !== null
                danger: true
                title: "Erase this disk and install"
                text: !page.d ? "" : page.d.contents === "empty" ? "The disk is empty."
                      : "Deletes everything on it: " + page.d.contents + "."
                checked: app.installMode === "erase"
                onClicked: app.installMode = "erase"
            }

            // ---- which system starts first
            Card {
                id: bootCard
                readonly property bool alongside: app.installMode === "alongside" && page.boot !== undefined
                readonly property bool otherDisk: app.installMode === "erase" && page.other !== undefined
                visible: alongside || otherDisk
                Layout.fillWidth: true
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    Label {
                        text: "When the computer starts"
                        font.bold: true
                        color: app.cText
                    }
                    Label {
                        visible: bootCard.otherDisk
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: app.cMuted
                        text: page.other ? page.other.name + " starts from another disk and is not touched." : ""
                    }
                    Label {
                        visible: bootCard.alongside
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: app.cMuted
                        text: bootCard.alongside ? app.distroName + " can be started from:\n• "
                              + installer.bootPlaces(app.disk).join("\n• ") : ""
                    }
                    RadioButton {
                        text: "Keep " + (page.boot && page.boot.default !== "" ? page.boot.default
                                         : page.other ? page.other.name : "the current system") + " first"
                        checked: !app.bootFirst
                        onClicked: app.bootFirst = false
                    }
                    RadioButton {
                        text: "Start " + app.distroName + " first"
                        checked: app.bootFirst
                        onClicked: app.bootFirst = true
                    }
                }
            }

            Card {
                visible: app.probe.bitlocker === true
                accent: app.cWarn
                Layout.fillWidth: true
                Label {
                    width: parent.width
                    wrapMode: Text.Wrap
                    color: app.cText
                    text: "Windows on this computer is encrypted with BitLocker. Because " + app.distroName
                          + " needs Secure Boot switched off, Windows will ask once for its 48-digit recovery key. "
                          + "Have it ready: https://aka.ms/myrecoverykey"
                }
            }

            // ---- encryption
            Card {
                visible: page.d !== null
                Layout.fillWidth: true
                ColumnLayout {
                    width: parent.width
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Label {
                                text: "Encrypt " + app.distroName
                                font.bold: true
                                color: app.cText
                            }
                            Label {
                                Layout.fillWidth: true
                                wrapMode: Text.Wrap
                                color: app.cMuted
                                text: "Recommended for laptops: nobody can read your files without the passphrase, which you type every time the computer starts."
                            }
                        }
                        Switch {
                            checked: app.encrypt
                            onToggled: app.encrypt = checked
                        }
                    }
                    CheckBox {
                        visible: app.encrypt && app.layout === "us"
                        text: "Use my login password as the passphrase"
                        checked: app.diskUsesLoginPassword
                        onToggled: app.diskUsesLoginPassword = checked
                    }
                    Label {
                        visible: app.encrypt && app.layout !== "us"
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        color: app.cWarn
                        text: "When the computer starts, the keyboard is always US English, so the passphrase is typed with that layout. "
                              + "While you type it below, the keyboard switches to US English. Letters, digits and simple symbols only."
                    }
                    RowLayout {
                        visible: app.encrypt && (!app.diskUsesLoginPassword || app.layout !== "us")
                        Layout.fillWidth: true
                        spacing: 10
                        TextField {
                            id: pass1
                            Layout.fillWidth: true
                            echoMode: TextInput.Password
                            placeholderText: "Disk passphrase"
                            onTextChanged: app.passphrase = text
                            onActiveFocusChanged: if (app.layout !== "us") installer.setKeyboard(activeFocus ? "us" : app.layout)
                        }
                        TextField {
                            id: pass2
                            Layout.fillWidth: true
                            echoMode: TextInput.Password
                            placeholderText: "The same again"
                            onActiveFocusChanged: if (app.layout !== "us") installer.setKeyboard(activeFocus ? "us" : app.layout)
                        }
                    }
                    Label {
                        visible: app.encrypt && !page.passOk && pass1.text !== ""
                        color: app.cBad
                        text: !installer.isAscii(pass1.text) ? "Use letters, digits and simple symbols only (no accents)."
                                                              : "The two passphrases are not the same."
                    }
                }
            }
        }
    }

    Connections {
        target: app
        function onLayoutChanged() {
            if (app.layout !== "us") app.diskUsesLoginPassword = false
        }
    }
}
