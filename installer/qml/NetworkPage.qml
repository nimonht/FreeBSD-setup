// The installation downloads the newest packages, so it needs the internet:
// connect to Wi-Fi here, or plug in a cable.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    property bool ready: installer.online === 1
    property string hint: installer.online === 1 ? "" : "An internet connection is needed to continue"
    property string chosen: ""
    property string chosenSecurity: ""

    onVisibleChanged: {
        if (!visible) return
        if (installer.online !== 1) installer.checkNetwork()
        if (installer.online !== 1 && installer.hasWifiCard && installer.wifiNetworks.length === 0)
            installer.scanWifi()
    }

    function bars(signal) {
        // dBm -> 1..4 bars
        var n = signal > -50 ? 4 : signal > -60 ? 3 : signal > -70 ? 2 : 1
        return "▂▄▆█".substring(0, n)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 40
        spacing: 20

        PageHeader {
            title: "Internet connection"
            subtitle: app.distroName + " downloads the newest system and drivers while it installs."
        }

        Card {
            Layout.fillWidth: true
            accent: installer.online === 1 ? app.cOk : "transparent"
            RowLayout {
                width: parent.width
                spacing: 14
                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: installer.checkingNetwork ? app.cWarn : (installer.online === 1 ? app.cOk : app.cBad)
                }
                Label {
                    Layout.fillWidth: true
                    font.pixelSize: 16
                    color: app.cText
                    text: installer.checkingNetwork ? "Checking the connection..."
                          : installer.online === 1 ? "Connected to the internet"
                          : "Not connected to the internet"
                }
                Button {
                    text: "Check again"
                    enabled: !installer.checkingNetwork
                    onClicked: installer.checkNetwork()
                }
            }
        }

        Card {
            visible: installer.online !== 1 && installer.hasWifiCard
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        text: "Wi-Fi networks"
                        font.bold: true
                        color: app.cText
                        Layout.fillWidth: true
                    }
                    BusyIndicator {
                        running: installer.wifiBusy
                        visible: running
                        Layout.preferredHeight: 32
                        Layout.preferredWidth: 32
                    }
                    Button {
                        text: "Search again"
                        flat: true
                        enabled: !installer.wifiBusy
                        onClicked: installer.scanWifi()
                    }
                }
                ListView {
                    id: nets
                    clip: true
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 120
                    model: installer.wifiNetworks
                    ScrollBar.vertical: ScrollBar {}
                    delegate: ItemDelegate {
                        width: nets.width
                        highlighted: page.chosen === modelData.ssid
                        contentItem: RowLayout {
                            Label {
                                text: page.bars(modelData.signal)
                                color: app.cAccent
                                Layout.preferredWidth: 40
                            }
                            Label {
                                text: modelData.ssid
                                color: app.cText
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Label {
                                text: modelData.security === "open" ? "open" : "secured"
                                color: app.cMuted
                            }
                        }
                        onClicked: {
                            page.chosen = modelData.ssid
                            page.chosenSecurity = modelData.security
                            wifiPassword.text = ""
                            if (modelData.security !== "open") wifiPassword.forceActiveFocus()
                        }
                    }
                }
                RowLayout {
                    visible: page.chosen !== ""
                    Layout.fillWidth: true
                    spacing: 10
                    TextField {
                        id: wifiPassword
                        visible: page.chosenSecurity !== "open"
                        Layout.fillWidth: true
                        echoMode: showWifi.checked ? TextInput.Normal : TextInput.Password
                        placeholderText: "Password for " + page.chosen
                        onAccepted: connectButton.clicked()
                    }
                    CheckBox {
                        id: showWifi
                        visible: wifiPassword.visible
                        text: "Show"
                    }
                    AccentButton {
                        id: connectButton
                        text: "Connect"
                        enabled: !installer.wifiBusy && (page.chosenSecurity === "open" || wifiPassword.text.length >= 8)
                        onClicked: installer.connectWifi(page.chosen, page.chosenSecurity === "open" ? "" : wifiPassword.text)
                    }
                }
                Label {
                    visible: text !== ""
                    text: installer.wifiError !== "" ? installer.wifiError : installer.wifiState
                    color: installer.wifiError !== "" ? app.cBad : app.cMuted
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
        }

        Card {
            visible: installer.online !== 1
            Layout.fillWidth: true
            ColumnLayout {
                width: parent.width
                spacing: 6
                Label {
                    text: "Wired or phone"
                    font.bold: true
                    color: app.cText
                }
                Label {
                    Layout.fillWidth: true
                    wrapMode: Text.Wrap
                    color: app.cMuted
                    text: (installer.hasWifiCard ? "" : "No Wi-Fi card with a FreeBSD driver was found. ")
                          + "Plug in an Ethernet cable, or connect a phone by USB and turn on USB tethering, then choose Check again."
                }
            }
        }

        Item {
            visible: installer.online === 1
            Layout.fillHeight: true
        }
    }
}
