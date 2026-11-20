// The LumenBSD installer window: a list of steps on the left, one page at a
// time on the right. The answers live here; install.sh does the work
// (installer/lumen_installer/app.py starts it).
import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: app
    width: 1120
    height: 740
    minimumWidth: 940
    minimumHeight: 620
    visible: true
    visibility: installer.mode === "kiosk" ? Window.FullScreen : Window.AutomaticVisibility
    title: distroName + " Installer"
    color: cBg

    Material.theme: Material.Dark
    Material.accent: cAccent
    Material.background: cBg
    Material.foreground: cText

    // ---------------------------------------------------------- colours --
    readonly property color cBg: "#121829"
    readonly property color cSide: "#0B1020"
    readonly property color cCard: "#1A2240"
    readonly property color cCardHi: "#24305A"
    readonly property color cLine: "#2C3763"
    readonly property color cText: "#E9ECF5"
    readonly property color cMuted: "#A0A8C3"
    readonly property color cAccent: "#FF9F43"
    readonly property color cAccent2: "#FF5E62"
    readonly property color cOk: "#4CD08A"
    readonly property color cWarn: "#FFC857"
    readonly property color cBad: "#FF6B6B"
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
                                  "Time zone", "About you", "Desktop", "Summary", "Install"]
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
            errorDialog.message = err
            errorDialog.open()
            return
        }
        page = installPage
    }

    // Used by lumen-installer --screenshots (demo data only).
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
        function onNotice(text) {
            errorDialog.message = text
            errorDialog.open()
        }
    }

    Component.onCompleted: {
        installer.startProbe()
        installer.checkNetwork()
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        SideBar {
            Layout.fillHeight: true
            Layout.preferredWidth: 260
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

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 76
                visible: app.page > 0 && app.page <= app.summaryPage
                color: app.cBg
                Rectangle { width: parent.width; height: 1; color: app.cLine }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 40
                    anchors.rightMargin: 40
                    spacing: 16

                    Button {
                        text: "Back"
                        flat: true
                        onClicked: app.back()
                    }
                    Item { Layout.fillWidth: true }
                    Label {
                        text: app.currentPage && app.currentPage.hint ? app.currentPage.hint : ""
                        color: app.cMuted
                        elide: Text.ElideRight
                        Layout.maximumWidth: 460
                    }
                    AccentButton {
                        id: nextButton
                        text: app.page === app.summaryPage ? "Install now" : "Next"
                        enabled: app.currentPage ? app.currentPage.ready : false
                        danger: app.page === app.summaryPage && app.installMode === "erase"
                        onClicked: app.next()
                    }
                }
            }
        }
    }

    Dialog {
        id: errorDialog
        property string message: ""
        anchors.centerIn: parent
        width: Math.min(560, app.width - 80)
        modal: true
        title: "Please check"
        standardButtons: Dialog.Ok
        Label {
            width: parent.width
            text: errorDialog.message
            wrapMode: Text.Wrap
        }
    }
}
