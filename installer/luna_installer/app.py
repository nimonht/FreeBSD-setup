"""The LunaBSD installer window: QML pages (installer/qml) over install.sh.

Runs as the live user; whatever needs root (install.sh, luna-wifi,
restarting) goes through doas, which the live system allows without a
password. Nothing here decides how to install: install.sh does, from the
answers file this writes.
"""

import argparse
import os
import platform
import shutil
import sys
import tempfile
import threading
import urllib.request

from PyQt6.QtCore import (QObject, QProcess, QTimer, QUrl, pyqtProperty, pyqtSignal, pyqtSlot,
                          qInstallMessageHandler)
from PyQt6.QtGui import QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtQuick import QQuickWindow

from . import backend
from . import demo as demo_data

REPO = backend.REPO
INSTALL_SH = os.path.join(REPO, "install.sh")
WIFI = shutil.which("luna-wifi") or os.path.join(REPO, "installer", "luna-wifi")
LIVE_STATE = "/var/run/luna-live"


def _read(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


class Installer(QObject):
    probeChanged = pyqtSignal()
    networkChanged = pyqtSignal()
    wifiChanged = pyqtSignal()
    progressChanged = pyqtSignal()
    logChanged = pyqtSignal()
    installFinished = pyqtSignal(bool, str)
    notice = pyqtSignal(str)
    _netResult = pyqtSignal(int)

    def __init__(self, mode, demo):
        super().__init__()
        self._mode = mode
        self._demo = demo
        self._distro = backend.read_distro()
        self._langs, self._layouts = backend.read_wizard_tables()
        self._zones = backend.read_timezones()
        self._reserved = backend.system_users()
        self._probe = {}
        self._probing = False
        self._probeError = ""
        self._online = -1          # -1 unknown, 0 offline, 1 online
        self._checking = False
        self._wifi = []
        self._wifiBusy = False
        self._wifiError = ""
        self._wifiState = ""
        self._installing = False
        self._progress = backend.Progress()
        self._log = []
        self._procs = set()
        self._tmp = None
        self._liveSession = _read(LIVE_STATE + "/session")
        self._liveReason = _read(LIVE_STATE + "/reason")
        if demo and mode == "kiosk" and not self._liveReason:
            self._liveReason = "virtual machines (qemu) have no 3D/KMS graphics driver on FreeBSD"
        self._netResult.connect(self._setOnline)
        self._asRoot = [] if os.geteuid() == 0 else ["doas"]

    # ------------------------------------------------------------ helpers --

    def _run(self, args, done, stdin=None):
        """Start a process; done(exit_code, output) when it ends."""
        p = QProcess(self)
        p.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        self._procs.add(p)

        def finished(code, _status):
            out = bytes(p.readAll()).decode("utf-8", "replace")
            self._procs.discard(p)
            p.deleteLater()
            done(code, out)
        p.finished.connect(finished)
        p.start(args[0], args[1:])
        if stdin is not None:
            p.write(stdin.encode())
            p.closeWriteChannel()
        return p

    # ----------------------------------------------------------- constants --

    @pyqtProperty("QVariant", constant=True)
    def distro(self):
        return self._distro

    @pyqtProperty(str, constant=True)
    def mode(self):
        return self._mode

    @pyqtProperty(bool, constant=True)
    def demo(self):
        return self._demo

    @pyqtProperty("QVariant", constant=True)
    def languages(self):
        return self._langs

    @pyqtProperty("QVariant", constant=True)
    def layouts(self):
        return self._layouts

    @pyqtProperty("QVariant", constant=True)
    def timezones(self):
        return self._zones

    @pyqtProperty(str, constant=True)
    def liveReason(self):
        return self._liveReason

    @pyqtProperty(str, constant=True)
    def logoUrl(self):
        return QUrl.fromLocalFile(os.path.join(REPO, "branding", "lunabsd-logo.svg")).toString()

    @pyqtProperty(str, constant=True)
    def wallpaperUrl(self):
        return QUrl.fromLocalFile(os.path.join(REPO, "branding", "lunabsd-wallpaper.jpg")).toString()

    # --------------------------------------------------------------- probe --

    @pyqtProperty("QVariant", notify=probeChanged)
    def probe(self):
        return self._probe

    @pyqtProperty(bool, notify=probeChanged)
    def probing(self):
        return self._probing

    @pyqtProperty(str, notify=probeChanged)
    def probeError(self):
        return self._probeError

    @pyqtSlot()
    def startProbe(self):
        if self._probing:
            return
        self._probing, self._probeError = True, ""
        self.probeChanged.emit()
        if self._demo:
            QTimer.singleShot(600, lambda: self._probeDone(0, demo_data.PROBE))
            return
        self._run(self._asRoot + ["/bin/sh", INSTALL_SH, "--probe"], self._probeDone)

    def _probeDone(self, code, out):
        self._probing = False
        p = backend.parse_probe(out)
        if code != 0 and not p["disks"]:
            lines = [l for l in out.splitlines() if l.strip()]
            self._probeError = lines[-1] if lines else "install.sh --probe failed"
        self._probe = p
        if p.get("net") is not None:
            self._online = 1 if p["net"] else 0
            self.networkChanged.emit()
        self.probeChanged.emit()

    # ------------------------------------------------------------- network --

    @pyqtProperty(int, notify=networkChanged)
    def online(self):
        return self._online

    @pyqtProperty(bool, notify=networkChanged)
    def checkingNetwork(self):
        return self._checking

    def _setOnline(self, v):
        self._online, self._checking = v, False
        self.networkChanged.emit()

    @pyqtSlot()
    def checkNetwork(self):
        if self._checking:
            return
        self._checking = True
        self.networkChanged.emit()
        if self._demo:
            QTimer.singleShot(800, lambda: self._setOnline(1 if demo_data.STATE["online"] else 0))
            return
        url = "https://download.freebsd.org/releases/"
        if platform.system() == "FreeBSD":
            # fetch(1): the same trust store and proxy settings as install.sh
            self._run(["fetch", "-q", "-T", "10", "-o", "/dev/null", url],
                      lambda code, _out: self._setOnline(1 if code == 0 else 0))
            return

        def worker():
            try:
                urllib.request.urlopen(url, timeout=10).close()
                self._netResult.emit(1)
            except Exception:
                self._netResult.emit(0)
        threading.Thread(target=worker, daemon=True).start()

    @pyqtProperty("QVariant", notify=wifiChanged)
    def wifiNetworks(self):
        return self._wifi

    @pyqtProperty(bool, notify=wifiChanged)
    def wifiBusy(self):
        return self._wifiBusy

    @pyqtProperty(str, notify=wifiChanged)
    def wifiError(self):
        return self._wifiError

    @pyqtProperty(str, notify=wifiChanged)
    def wifiState(self):
        return self._wifiState

    @pyqtProperty(bool, notify=probeChanged)
    def hasWifiCard(self):
        return any(r["text"].startswith("Wi-Fi:") and r["status"] == "OK"
                   for r in self._probe.get("report", []))

    @pyqtSlot()
    def scanWifi(self):
        if self._wifiBusy:
            return
        self._wifiBusy, self._wifiError = True, ""
        self.wifiChanged.emit()
        if self._demo:
            QTimer.singleShot(900, lambda: self._scanDone(0, demo_data.WIFI_SCAN))
            return
        self._run(self._asRoot + [WIFI, "scan"], self._scanDone)

    def _scanDone(self, code, out):
        nets = []
        for line in out.splitlines():
            f = line.split("\t")
            if len(f) == 3 and f[0].lstrip("-").isdigit():
                nets.append({"signal": int(f[0]), "security": f[1], "ssid": f[2]})
        self._wifi = nets
        self._wifiBusy = False
        if code != 0:
            self._wifiError = out.strip().splitlines()[-1] if out.strip() else "Scanning failed."
        self.wifiChanged.emit()

    @pyqtSlot(str, str)
    def connectWifi(self, ssid, password):
        if self._wifiBusy:
            return
        self._wifiBusy, self._wifiError, self._wifiState = True, "", "Connecting to %s..." % ssid
        self.wifiChanged.emit()

        def done(code, out):
            self._wifiBusy = False
            if code == 0:
                self._wifiState = "Connected to %s" % ssid
                self.checkNetwork()
            else:
                self._wifiState = ""
                msg = out.strip().splitlines()[-1] if out.strip() else "Could not connect."
                self._wifiError = msg.replace("luna-wifi: ", "").capitalize()
            self.wifiChanged.emit()
        if self._demo:
            def fake():
                demo_data.STATE["online"] = True
                done(0, "")
            QTimer.singleShot(1200, fake)
            return
        self._run(self._asRoot + [WIFI, "connect", ssid], done, stdin=password + "\n")

    # ------------------------------------------------------------ keyboard --

    @pyqtSlot(str)
    def setKeyboard(self, xkb):
        """Use this layout in the live session now, so passwords are typed
        as they will be at the login screen."""
        if self._demo:
            return
        layout, variant = (xkb, "")
        if xkb == "us-intl":
            layout, variant = "us", "intl"
        if os.environ.get("XDG_SESSION_TYPE") == "wayland" and shutil.which("kwriteconfig6"):
            for key, val in (("LayoutList", layout), ("VariantList", variant), ("Use", "true")):
                QProcess.startDetached("kwriteconfig6", ["--file", "kxkbrc", "--group", "Layout", "--key", key, val])
            QTimer.singleShot(300, lambda: QProcess.startDetached(
                "dbus-send", ["--session", "--type=signal", "/Layouts", "org.kde.keyboard.reloadConfig"]))
        elif shutil.which("setxkbmap"):
            QProcess.startDetached("setxkbmap", ["-layout", layout, "-variant", variant])

    # ---------------------------------------------------------- validation --

    @pyqtSlot(str, result=str)
    def checkFullname(self, s):
        return backend.check_fullname(s)

    @pyqtSlot(str, result=str)
    def checkUsername(self, s):
        return backend.check_username(s, self._reserved)

    @pyqtSlot(str, result=str)
    def checkHostname(self, s):
        return backend.check_hostname(s)

    @pyqtSlot(str, str, str, result=str)
    def checkPassword(self, a, b, what):
        return backend.check_password(a, b, what)

    @pyqtSlot(str, result=int)
    def strength(self, p):
        return backend.password_strength(p)

    @pyqtSlot(str, result=bool)
    def isAscii(self, s):
        return backend.is_ascii_printable(s)

    @pyqtSlot(str, result=str)
    def suggestUsername(self, s):
        return backend.suggest_username(s)

    @pyqtSlot(result=str)
    def defaultDisk(self):
        return backend.default_disk(self._probe.get("disks", []), self._probe.get("min_gb", 30))

    @pyqtSlot(str, result="QVariant")
    def bootPlaces(self, disk):
        return backend.boot_places(self._probe.get("boot", {}).get(disk, {}), self._distro["DISTRO_NAME"])

    @pyqtSlot(str, result=str)
    def zoneFor(self, lang):
        return backend.LANG_ZONES.get(lang, "UTC")

    @pyqtSlot(str, result=str)
    def layoutFor(self, lang):
        return backend.LANG_LAYOUTS.get(lang, "us")

    @pyqtSlot(str, result="QVariant")
    def inputMethodsFor(self, lang):
        im = backend.LANG_IMS.get(lang)
        return [im] if im else []

    # ------------------------------------------------------------- install --

    @pyqtProperty(bool, notify=progressChanged)
    def installing(self):
        return self._installing

    @pyqtProperty(float, notify=progressChanged)
    def fraction(self):
        return self._progress.fraction

    @pyqtProperty(str, notify=progressChanged)
    def stepTitle(self):
        return self._progress.title

    @pyqtProperty(str, notify=progressChanged)
    def stepDetail(self):
        return self._progress.detail

    @pyqtProperty(str, notify=logChanged)
    def logText(self):
        return "\n".join(self._log[-400:])

    def _feed(self, text):
        for line in text.splitlines():
            self._log.append(line)
            self._progress.feed(line)
        del self._log[:-3000]
        self.progressChanged.emit()
        self.logChanged.emit()

    @pyqtSlot("QVariant", result=str)
    def startInstall(self, answers):
        """Write the answers file and start install.sh. Returns an error
        message, or "" when the installation has started."""
        if self._installing:
            return "The installation is already running."
        if hasattr(answers, "toVariant"):
            answers = answers.toVariant()
        try:
            text = backend.build_answers(dict(answers))
        except ValueError as e:
            return str(e)
        self._progress = backend.Progress()
        self._log = []
        self._installing = True
        self.progressChanged.emit()
        if self._demo:
            lines = list(demo_data.install_lines())
            timer = QTimer(self)

            def tick():
                if lines:
                    self._feed(lines.pop(0))
                else:
                    timer.stop()
                    self._installing = False
                    self.progressChanged.emit()
                    self.installFinished.emit(True, backend.result_details(demo_data.RESULT % self._distro, self._distro["DISTRO_NAME"]))
            timer.timeout.connect(tick)
            timer.start(40)
            return ""
        self._tmp = tempfile.mkdtemp(prefix="luna-installer-")
        conf = os.path.join(self._tmp, "answers.conf")
        fd = os.open(conf, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(text)
        result = os.path.join(self._tmp, "result.txt")
        p = QProcess(self)
        p.setProcessChannelMode(QProcess.ProcessChannelMode.MergedChannels)
        p.readyRead.connect(lambda: self._feed(bytes(p.readAll()).decode("utf-8", "replace")))

        def finished(code, _status):
            self._feed(bytes(p.readAll()).decode("utf-8", "replace"))
            self._installing = False
            self.progressChanged.emit()
            # the passwords are in there: remove it now
            try:
                os.unlink(conf)
            except OSError:
                pass
            if code == 0:
                self.installFinished.emit(True, backend.result_details(_read(result), self._distro["DISTRO_NAME"]))
            else:
                tail = "\n".join(l for l in self._log[-12:] if l.strip())
                self.installFinished.emit(False, tail)
        p.finished.connect(finished)
        cmd = self._asRoot + ["/usr/bin/env", "NO_COLOR=1", "FBS_RESULT_FILE=" + result,
                               "/bin/sh", INSTALL_SH, "--config", conf, "--yes"]
        p.start(cmd[0], cmd[1:])
        self._procs.add(p)
        return ""

    # ---------------------------------------------------------------- misc --

    def _as_root_detached(self, *args):
        cmd = self._asRoot + list(args)
        QProcess.startDetached(cmd[0], cmd[1:])

    @pyqtSlot()
    def reboot(self):
        if not self._demo:
            self._as_root_detached("/sbin/shutdown", "-r", "now")
        QGuiApplication.quit()

    @pyqtSlot()
    def poweroff(self):
        if not self._demo:
            self._as_root_detached("/sbin/shutdown", "-p", "now")
        QGuiApplication.quit()

    @pyqtSlot()
    def openTerminal(self):
        for t in ("konsole", "xterm"):
            if shutil.which(t):
                QProcess.startDetached(t, [])
                return
        self.notice.emit("No terminal program is installed.")

    @pyqtSlot(result=str)
    def logPath(self):
        return "/tmp/freebsd-install.log"


def main(argv=None):
    ap = argparse.ArgumentParser(prog="luna-installer", description="Install LunaBSD.")
    ap.add_argument("--welcome", action="store_true", help="start with 'Try or Install' (live desktop)")
    ap.add_argument("--kiosk", action="store_true", help="full screen, the only program on screen")
    ap.add_argument("--demo", action="store_true", help="made-up computer, nothing is changed")
    ap.add_argument("--screenshots", metavar="DIR", help="save a picture of every page and quit (with --demo)")
    args = ap.parse_args(argv)
    if args.screenshots:
        args.demo = True

    # --screenshots is also the test that every page loads: any QML warning
    # (an unknown property, a binding loop...) makes it fail.
    qml_problems = []
    if args.screenshots:
        def handler(_mode, _context, message):
            print(message, file=sys.stderr)
            if "qml" in message.lower() or "file://" in message:
                qml_problems.append(message)
        qInstallMessageHandler(handler)

    os.environ.setdefault("QT_QUICK_CONTROLS_STYLE", "Material")
    os.environ.setdefault("QT_QUICK_CONTROLS_MATERIAL_THEME", "Dark")
    app = QGuiApplication(sys.argv[:1])
    app.setApplicationName("luna-installer")
    app.setOrganizationName("LunaBSD")
    app.setDesktopFileName("luna-installer")
    app.setWindowIcon(QIcon(os.path.join(REPO, "branding", "lunabsd-logo.svg")))

    mode = "kiosk" if args.kiosk else ("welcome" if args.welcome else "install")
    installer = Installer(mode, args.demo)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("installer", installer)
    engine.quit.connect(app.quit)
    engine.load(QUrl.fromLocalFile(os.path.join(REPO, "installer", "qml", "Main.qml")))
    if not engine.rootObjects():
        print("luna-installer: the user interface could not be loaded", file=sys.stderr)
        return 1
    root = engine.rootObjects()[0]
    if args.screenshots and isinstance(root, QQuickWindow):
        demo_data.take_screenshots(app, root, args.screenshots)
    rc = app.exec()
    if qml_problems:
        print("luna-installer: %d QML problem(s)" % len(qml_problems), file=sys.stderr)
        return rc or 1
    return rc
