// The installation downloads the newest packages, so it needs the internet:
// connect to Wi-Fi here, or plug in a cable.
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

LPage {
    id: page
    title: "Network"
    subtitle: app.distroName + " downloads the newest system and drivers while it installs."
    code: app.stepCode(2)
    ready: installer.online === 1
    hint: installer.online === 1 ? "" : "An internet connection is needed to continue"

    property string chosen: ""
    property string chosenSecurity: ""

    onVisibleChanged: {
        if (!visible) return
        if (installer.online !== 1) installer.checkNetwork()
        if (installer.online !== 1 && installer.hasWifiCard && installer.wifiNetworks.length === 0)
            installer.scanWifi()
    }
    function strength(dbm) {
        return dbm > -50 ? "Strong signal" : dbm > -60 ? "Good signal" : dbm > -70 ? "Fair signal" : "Weak signal"
    }

    ColumnLayout {
        width: parent.width
        spacing: 24

        Panel {
            Layout.fillWidth: true
            title: "Connection"
            RowLayout {
                width: parent.width
                spacing: 14
                Busy {
                    running: installer.checkingNetwork
                }
                Rectangle {
                    visible: !installer.checkingNetwork
                    Layout.preferredWidth: 12
                    Layout.preferredHeight: 12
                    color: installer.online === 1 ? app.cInk : app.cSignal
                }
                Label {
                    Layout.fillWidth: true
                    font.pixelSize: 16
                    color: app.cInk
                    text: installer.checkingNetwork ? "Checking the connection"
                          : installer.online === 1 ? "Connected to the internet"
                          : "Not connected to the internet"
                }
                LButton {
                    text: "Check again"
                    enabled: !installer.checkingNetwork
                    onClicked: installer.checkNetwork()
                }
            }
        }

        Panel {
            visible: installer.online !== 1 && installer.hasWifiCard
            Layout.fillWidth: true
            title: "Wi-Fi networks"
            tag: installer.wifiNetworks.length + " FOUND"
            ColumnLayout {
                width: parent.width
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 6
                    Busy { running: installer.wifiBusy }
                    Label {
                        Layout.fillWidth: true
                        text: installer.wifiBusy ? "Searching" : "Choose your network."
                        color: app.cSoft
                    }
                    LButton {
                        text: "Search again"
                        enabled: !installer.wifiBusy
                        onClicked: installer.scanWifi()
                    }
                }
                Repeater {
                    model: installer.wifiNetworks
                    delegate: MenuRow {
                        title: modelData.ssid
                        text: page.strength(modelData.signal)
                        tag: modelData.security === "open" ? "OPEN" : "SECURED"
                        checked: page.chosen === modelData.ssid
                        onClicked: {
                            page.chosen = modelData.ssid
                            page.chosenSecurity = modelData.security
                            wifiPassword.text = ""
                            if (modelData.security !== "open") wifiPassword.field.forceActiveFocus()
                        }
                    }
                }
                RowLayout {
                    visible: page.chosen !== ""
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    spacing: 16
                    LField {
                        id: wifiPassword
                        visible: page.chosenSecurity !== "open"
                        label: "Password for " + page.chosen
                        secret: true
                        onAccepted: connectButton.clicked()
                    }
                    LButton {
                        id: connectButton
                        Layout.alignment: Qt.AlignBottom
                        text: "Connect"
                        kind: "primary"
                        enabled: !installer.wifiBusy && (page.chosenSecurity === "open" || wifiPassword.text.length >= 8)
                        onClicked: installer.connectWifi(page.chosen, page.chosenSecurity === "open" ? "" : wifiPassword.text)
                    }
                }
                Label {
                    visible: text !== ""
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    text: installer.wifiError !== "" ? installer.wifiError : installer.wifiState
                    color: installer.wifiError !== "" ? app.cSignal : app.cSoft
                    wrapMode: Text.Wrap
                }
            }
        }

        Panel {
            visible: installer.online !== 1
            Layout.fillWidth: true
            title: "Cable or phone"
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                color: app.cInk
                lineHeight: 1.2
                text: (installer.hasWifiCard ? "" : "No Wi-Fi card with a FreeBSD driver was found. ")
                      + "Plug in a network cable, or connect a phone by USB and turn on USB tethering, then choose Check again."
            }
        }
    }
}
