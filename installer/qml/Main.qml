// The LunaBSD installer window. The look: printed matter on an instrument
// grid (parchment, ink, one signal red), menus whose choices are swept in
// ink, capitals for short labels only. The answers live here; install.sh
// does the work (installer/luna_installer/app.py starts it).
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: app
    width: 1180
    height: 760
    minimumWidth: 980
    minimumHeight: 640
    visible: true
    visibility: installer.mode === "kiosk" ? Window.FullScreen : Window.AutomaticVisibility
    title: distroName + " Installer"
    color: cBg
    font.family: fSans
    font.pixelSize: 15

    // ----------------------------------------------------------- design --
    // Text colours meet 4.5:1 on parchment and paper (checked).
    readonly property color cBg: "#D1CDB7"        // parchment
    readonly property color cGrid: "#CAC5AE"      // the grid on it
    readonly property color cPaper: "#DCD8C0"     // raised surfaces; text on ink
    readonly property color cWeak: "#BAB5A1"      // shadows, washes
    readonly property color cDisabled: "#8F8A76"
    readonly property color cSoft: "#58544A"      // secondary text
    readonly property color cInk: "#454138"       // text, bands, rules
    readonly property color cSignal: "#8A3322"    // erasing, errors
    readonly property color cOchre: "#5E4A1C"     // limitations
    readonly property string fSans: "IBM Plex Sans"
    readonly property string fMono: "IBM Plex Mono"
    readonly property string distroName: installer.distro.DISTRO_NAME

    // ---------------------------------------------------------- answers --
    property string language: "en"
    property string layout: "us"
    property bool layoutTouched: false
    property bool zoneTouched: false
    property bool imTouched: false
    property string disk: ""
    property string installMode: ""
    property int sizeGb: 0
    property bool encrypt: false
    property bool diskUsesLoginPassword: true
    property string passphrase: ""
    property bool bootFirst: false
    property string timezone: "UTC"
    property string fullname: ""
    property string username: ""
    property string hostname: installer.distro.DISTRO_ID
    property string password: ""
    property bool sameRootPassword: true
    property string rootPassword: ""
    property string desktop: "kde"
    property bool apps: true
    property bool printing: true
    property bool gaming: false
    property bool dev: false
    property bool firewall: true
    property bool snapshots: true
    property string terminal: "fish"
    property string pkgBranch: "latest"
    property var inputMethods: []
    property bool eraseConfirmed: false

    // ------------------------------------------------------------ pages --
    property int page: 0
    readonly property var steps: ["Welcome", "Language", "Network", "Your computer", "Disk",
                                  "Time zone", "Your account", "Desktop", "Summary", "Install"]
    readonly property int summaryPage: 8
    readonly property int installPage: 9
    readonly property int donePage: 10
    property bool installOk: false
    property string resultText: ""
    readonly property Item currentPage: stack.children[stack.currentIndex] || null
    readonly property var probe: installer.probe
    readonly property var hw: probe.hw || ({})
    readonly property var selectedDisk: {
        var ds = probe.disks || []
        for (var i = 0; i < ds.length; i++)
            if (ds[i].name === disk) return ds[i]
        return null
    }
    function stepCode(i) { return "STEP " + (i < 9 ? "0" : "") + (i + 1) + " / 10" }

    function next() {
        if (page === summaryPage) beginInstall()
        else if (page < summaryPage) page++
    }
    function back() { if (page > 0 && page <= summaryPage) page-- }

    function setLanguage(code) {
        language = code
        if (!layoutTouched) setLayout(installer.layoutFor(code), false)
        if (!zoneTouched) timezone = installer.zoneFor(code)
        if (!imTouched) inputMethods = installer.inputMethodsFor(code)
    }
    function setLayout(xkb, touched) {
        layout = xkb
        if (touched) layoutTouched = true
        installer.setKeyboard(xkb)
    }
    function answers() {
        return {
            disk: disk, mode: installMode, size_gb: sizeGb,
            fullname: fullname, username: username, hostname: hostname,
            password: password, root_password: sameRootPassword ? "" : rootPassword,
            encrypt: encrypt, passphrase: diskUsesLoginPassword ? password : passphrase,
            timezone: timezone, boot_first: bootFirst, language: language, layout: layout,
            desktop: desktop, input_methods: inputMethods, terminal: terminal,
            pkg_branch: pkgBranch,
            apps: apps, printing: printing, gaming: gaming, dev: dev,
            firewall: firewall, snapshots: snapshots
        }
    }
    function beginInstall() {
        var err = installer.startInstall(answers())
        if (err !== "") {
            notice.show("Please check", err)
            return
        }
        page = installPage
    }

    // Used by luna-installer --screenshots (demo data only).
    function gotoPage(i) { page = i }
    function demoFill() {
        setLanguage("en")
        disk = installer.defaultDisk()
        installMode = "alongside"
        sizeGb = 180
        encrypt = true
        fullname = "Alex Morgan"
        username = "alex"
        hostname = "alex-thinkpad"
        password = "correct horse battery"
        timezone = "Europe/Berlin"
    }
    function demoInstall() { page = installPage; installer.startInstall(answers()) }

    Connections {
        target: installer
        function onInstallFinished(ok, text) {
            installOk = ok
            resultText = text
            page = donePage
        }
        function onNotice(text) { notice.show("Notice", text) }
    }

    Component.onCompleted: {
        installer.startProbe()
        installer.checkNetwork()
    }

    Backdrop { anchors.fill: parent }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TopBar { Layout.fillWidth: true }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            SideBar {
                Layout.fillHeight: true
                Layout.preferredWidth: 270
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                StackLayout {
                    id: stack
                    currentIndex: app.page
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    WelcomePage {}
                    KeyboardPage {}
                    NetworkPage {}
                    ComputerPage {}
                    DiskPage {}
                    LocationPage {}
                    AccountPage {}
                    DesktopPage {}
                    SummaryPage {}
                    InstallPage {}
                    DonePage {}
                }

                // the footer: what is missing, and the way on
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 74
                    visible: app.page > 0 && app.page <= app.summaryPage
                    Rectangle {
                        x: 48
                        width: parent.width - 88
                        height: 1
                        color: app.cInk
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 48
                        anchors.rightMargin: 40
                        spacing: 18
                        Rectangle {
                            visible: hintLabel.text !== ""
                            Layout.preferredWidth: 7
                            Layout.preferredHeight: 7
                            color: app.cSoft
                        }
                        Label {
                            id: hintLabel
                            Layout.fillWidth: true
                            text: app.currentPage && app.currentPage.hint ? app.currentPage.hint : ""
                            color: app.cSoft
                            font.pixelSize: 14
                            elide: Text.ElideRight
                        }
                        LButton {
                            text: "Back"
                            onClicked: app.back()
                        }
                        LButton {
                            text: app.page === app.summaryPage ? "Install now" : "Next"
                            kind: app.page === app.summaryPage && app.installMode === "erase" ? "danger" : "primary"
                            enabled: app.currentPage ? app.currentPage.ready : false
                            onClicked: app.next()
                        }
                    }
                }
            }
        }
    }

    // A message that needs an answer before going on.
    Popup {
        id: notice
        property string heading: ""
        property string message: ""
        function show(h, m) { heading = h; message = m; open() }
        anchors.centerIn: Overlay.overlay
        width: Math.min(560, app.width - 120)
        modal: true
        padding: 0
        Overlay.modal: Rectangle { color: Qt.rgba(0.27, 0.25, 0.22, 0.45) }
        background: Item {}
        contentItem: Panel {
            title: notice.heading
            accent: app.cSignal
            ColumnLayout {
                width: parent.width
                spacing: 18
                Label {
                    Layout.fillWidth: true
                    text: notice.message
                    color: app.cInk
                    wrapMode: Text.Wrap
                    font.pixelSize: 15
                }
                LButton {
                    Layout.alignment: Qt.AlignRight
                    text: "Understood"
                    kind: "primary"
                    onClicked: notice.close()
                }
            }
        }
    }
}
