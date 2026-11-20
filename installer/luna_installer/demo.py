"""Made-up data for luna-installer --demo: a laptop with Windows on an NVMe
disk and a USB backup drive. Used for screenshots and tests on any OS;
nothing is read from or written to the real computer."""

import os

from . import backend

STATE = {"online": False}

GB = 1073741824
PROBE = "\n".join([
    "distro\tLunaBSD\t0.1",
    "hw\tHW_BOOT\tUEFI",
    "hw\tHW_VM\tnone",
    "hw\tHW_RAM_MB\t16046",
    "hw\tHW_DESKTOP\tyes",
    "hw\tHW_DESKTOP_WHY\t",
    "hw\tHW_GPU_PRIMARY\tintel",
    "hw\tHW_LAPTOP\tyes",
    "hw\tHW_VENDOR\tLENOVO",
    "hw\tHW_MODEL\tThinkPad T14 Gen 3",
    "hw\tHW_CPU\t12th Gen Intel(R) Core(TM) i7-1260P",
    "report\tOK\tArchitecture: amd64",
    "report\tOK\tFreeBSD 15.1-RELEASE",
    "report\tOK\tCPU: 12th Gen Intel(R) Core(TM) i7-1260P (16 threads)",
    "report\tOK\tMemory: 16 GB",
    "report\tOK\tFirmware: UEFI (installing next to Windows/Linux is possible)",
    "report\tOK\tGraphics: Alder Lake-P GT2 [Iris Xe Graphics] (i915kms)",
    "report\tOK\tDesktop: KDE Plasma and Hyprland can run on this machine",
    "report\tOK\tWi-Fi: Wi-Fi 6E AX211 160MHz (iwlwifi0)",
    "report\tOK\tAudio: Realtek ALC287 (Analog)",
    "report\tOK\tLaptop: battery and power management, hotkeys (acpi_ibm)",
    "report\tINFO\tSleep: suspend to RAM (S3) is available - test it once before relying on it",
    "report\tOK\tWebcam: Integrated Camera (webcamd)",
    "report\tWARN\tBluetooth: Intel AX211 Bluetooth - keyboards and mice can be paired by hand; Bluetooth audio is not supported",
    "report\tNO\tFingerprint reader: Synaptics FS7605 - not supported",
    "min_gb\t30",
    "bitlocker\tno",
    "disk\tnda0\t%d\tSamsung SSD 980 PRO 1TB\tno\tWindows/data (2) EFI \tMicrosoft\t%d\tyes\t\tyes" % (1000 * GB, 238 * GB),
    "boot\tnda0\tnone\tno\tno\tno\tyes\tWindows Boot Manager\tWindows Boot Manager",
    "disk\tda0\t%d\tWD Elements 25A2\tyes\tWindows/data (1) \t\t0\tno\tthere is no EFI system partition on this disk\tyes" % (2000 * GB),
    "net\tno",
]) + "\n"

WIFI_SCAN = "-38\twpa\tHome Network\n-55\twpa\tNeighbours 5G\n-71\topen\tCafe Guest\n-80\twpa\tDIRECT-printer\n"

RESULT = """%(DISTRO_NAME)s is installed.

Remove the USB stick and restart the computer.
Start %(DISTRO_NAME)s from:
  - 'FreeBSD' in the firmware boot menu (F12, F11, F8 or Esc right after power-on)
  - %(DISTRO_NAME)s's own boot menu: 'Start Windows Boot Manager' (key L)"""


def install_lines():
    """What install.sh prints, shortened."""
    yield "==== Partitioning nda0 ===="
    yield "==== Creating the ZFS pool zroot ===="
    yield "==== Downloading and installing FreeBSD 15.1-RELEASE ===="
    for part in ("base", "kernel", "lib32"):
        yield "  -> downloading %s.txz" % part
        yield "  -> unpacking %s.txz" % part
    yield "  -> applying security patches (freebsd-update; can take 10 minutes)"
    for s in ("Configuring the new system", "Creating the user account", "Making it bootable",
              "Copying FreeBSD-setup into the new system", "Installing the desktop (the long part)"):
        yield "==== %s ====" % s
    for stage, _ in backend.STAGES:
        yield "==== %s ====" % stage
        n = 40 if stage == "kde" else 6
        for i in range(1, n + 1):
            yield "       [%d/%d] Fetching pkg-%s-%d.pkg" % (i, n, stage, i)
        for i in range(1, n + 1):
            yield "       [%d/%d] Installing pkg-%s-%d..." % (i, n, stage, i)
    yield "==== Finishing ===="


def take_screenshots(app, root, outdir):
    """Walk through every page and save a picture of each (tests, docs)."""
    from PyQt6.QtCore import QMetaObject, QTimer, Qt, Q_ARG

    os.makedirs(outdir, exist_ok=True)
    names = ["01-welcome", "02-keyboard", "03-network", "04-computer", "05-disk", "06-location",
             "07-account", "08-desktop", "09-summary"]
    plan = []
    for i, name in enumerate(names):
        plan.append(("page", i, name))
    plan += [("install", None, None), ("wait", 4000, "10-installing"), ("wait", 15000, "11-done")]

    def call(method, *args):
        QMetaObject.invokeMethod(root, method, Qt.ConnectionType.DirectConnection,
                                 *[Q_ARG("QVariant", a) for a in args])

    def save(name):
        img = root.grabWindow()
        img.save(os.path.join(outdir, name + ".png"))

    def step():
        if not plan:
            app.quit()
            return
        kind, arg, name = plan.pop(0)
        if kind == "page":
            call("gotoPage", arg)
            QTimer.singleShot(700, lambda: (save(name), step()))
        elif kind == "install":
            call("demoInstall")
            QTimer.singleShot(100, step)
        else:
            QTimer.singleShot(arg, lambda: (save(name), step()))

    def start():
        call("demoFill")
        QTimer.singleShot(500, step)
    QTimer.singleShot(1500, start)
