#!/usr/bin/env python3
"""Answer shim's MokManager (the blue screen) in a QEMU VM as a person
would: read the screen, press keys.

  mokmanager.py SOCKET LOG from-disk      Enroll key from disk: the first
                                          file system, the .cer file at its
                                          top, Continue, Yes, Reboot
  mokmanager.py SOCKET LOG request CODE   Enroll MOK, Continue, Yes, the
                                          code, Reboot

SOCKET is the VM's serial socket; its monitor socket (mon.sock) must be in
the same directory. MokManager draws its menus on the screen only (not on
the serial console), so the screen is read from screenshots with OCR
(tesseract); keys go in through the serial line, which the firmware takes
as keyboard input. MokManager puts the cursor on the first entry of every
new menu, so an entry is chosen by counting entries above it."""
import os
import re
import socket
import subprocess
import sys
import tempfile
import time

sock_path, log_path, what = sys.argv[1:4]
code = sys.argv[4] if len(sys.argv) > 4 else ""
mon_path = os.path.join(os.path.dirname(sock_path), "mon.sock")
tmp = tempfile.mkdtemp(prefix="mokmanager-")
s = None
for _ in range(120):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        break
    except OSError:
        time.sleep(1)
s.settimeout(0.2)
log = open(log_path, "ab", buffering=0)


def drain(secs):
    """Keep reading the serial line (into the log): an unread socket would
    stall the VM's serial port."""
    end = time.time() + secs
    while time.time() < end:
        try:
            d = s.recv(65536)
        except socket.timeout:
            continue
        if not d:
            return
        log.write(d)


def look():
    """The screen's text lines, by OCR of a screenshot."""
    from PIL import Image, ImageOps
    ppm, png = os.path.join(tmp, "s.ppm"), os.path.join(tmp, "s.png")
    if os.path.exists(ppm):
        os.unlink(ppm)
    m = socket.socket(socket.AF_UNIX)
    m.connect(mon_path)
    m.settimeout(2)
    time.sleep(0.3)
    try:
        m.recv(65536)
    except socket.timeout:
        pass
    m.sendall(("screendump %s\n" % ppm).encode())
    for _ in range(20):
        time.sleep(0.25)
        if os.path.exists(ppm) and os.path.getsize(ppm) > 0:
            break
    m.close()
    time.sleep(0.3)
    im = Image.open(ppm).convert("L")
    ImageOps.invert(im).resize((im.width * 2, im.height * 2)).save(png)
    out = subprocess.run(["tesseract", png, "-", "--psm", "6"], capture_output=True, text=True).stdout
    lines = []
    for l in out.splitlines():
        l = l.strip()
        l = re.sub(r"^(?:[|!\[\]{}]\s*|I\s+)+", "", l)
        l = re.sub(r"(?:\s*[|!\[\]{}]|\s+I)+$", "", l)
        if l:
            lines.append(l)
    return lines


def key(k, pause=0.8):
    s.sendall({"down": b"\x1b[B", "up": b"\x1b[A", "enter": b"\r"}.get(k, k.encode()))
    drain(pause)


def wait(test, secs, what_for):
    end = time.time() + secs
    while time.time() < end:
        drain(1.5)
        lines = look()
        if test(lines):
            return lines
    print("mokmanager.py: timed out waiting for %s; screen: %s" % (what_for, look()), flush=True)
    sys.exit(1)


def norm(text):
    """For comparing OCR'd text: lower case, no spaces (OCR adds some,
    "Cont inue"), and the letters it confuses taken as one."""
    return re.sub(r"\s+", "", text.lower()).replace("]", "l").replace("|", "l").replace("1", "l")


def has(lines, *words):
    return any(norm(w) in norm(l) for l in lines for w in words)


def choose(entry, entries, lines):
    """Move from the first of entries on screen to the one starting with
    entry, then Enter."""
    present = []
    for l in lines:
        for e in entries:
            if norm(l).startswith(norm(e)) and e not in present:
                present.append(e)
    if entry not in present:
        print("mokmanager.py: %r not on screen (found %s): %s" % (entry, present, lines), flush=True)
        sys.exit(1)
    print("mokmanager.py: %s" % entry, flush=True)
    for _ in range(present.index(entry)):
        key("down", 0.5)
    key("enter", 3)


def pick(title, order, entry, secs=60):
    """Wait for a screen recognised by a word of its title, then choose
    entry by its place in order: MokManager's own fixed order for that
    screen (OCR misses short entries such as "Yes" in small boxes)."""
    wait(lambda l: has(l, *title), secs, " / ".join(title))
    print("mokmanager.py: %s" % entry, flush=True)
    for _ in range(order.index(entry)):
        key("down", 0.5)
    key("enter", 3)


MENU = ["Continue boot", "Enroll MOK", "Delete MOK", "Change Secure Boot state", "Set MOK password",
        "Reset MOK", "Enroll key from disk", "Enroll hash from disk"]

# From power-on to MokManager's menu. shim shows "Verification failed" in a
# dialog (OK) when the loader's key is unknown, then starts MokManager, which
# counts down ("Press any key to perform MOK management"). A key pressed
# before shim waits for it is lost: the screen is read again before each key.
end = time.time() + 1500
while True:
    drain(2)
    lines = look()
    if any(norm(l).startswith(norm(e)) for l in lines for e in ("Continue boot", "Enroll MOK", "Enroll key from disk")):
        break
    if time.time() > end:
        print("mokmanager.py: no MokManager menu; screen: %s" % lines, flush=True)
        sys.exit(1)
    if has(lines, "Press any key", "Booting in"):
        print("mokmanager.py: MokManager's countdown: a key", flush=True)
        key(" ", 2)
    elif has(lines, "Verification failed"):
        print("mokmanager.py: shim's verification error: OK", flush=True)
        key("enter", 2)
print("mokmanager.py: menu: %s" % lines, flush=True)

if what == "from-disk":
    choose("Enroll key from disk", MENU, lines)
    # The file systems MokManager can read (FAT): the stick's EFI image.
    lines = wait(lambda l: len(l) > 0 and not has(l, "Perform MOK management"), 60, "the file systems")
    print("mokmanager.py: file systems: %s" % lines, flush=True)
    key("enter", 3)
    lines = wait(lambda l: has(l, "ENROLL"), 60, "the key file")
    print("mokmanager.py: files: %s" % lines, flush=True)
    files = [l for l in lines if l.endswith("/") or re.search(r"\.(cer|der|crt|efi)$", l, re.I)]
    target = next((f for f in files if f.upper().startswith("ENROLL")), None)
    if target is None:
        print("mokmanager.py: the key file is not listed: %s" % lines, flush=True)
        sys.exit(1)
    choose(target, files, lines)
elif what == "request":
    choose("Enroll MOK", MENU, lines)
else:
    sys.exit(2)

# MokManager.c: "[Enroll MOK]" lists "View key 0" (one per key), then
# "Continue"; "Enroll the key(s)?" offers "No", then "Yes"; a request then
# asks for its password; the menu after enrolling starts with "Reboot".
pick(["View key", "Enroll MOK"], ["View key 0", "Continue"], "Continue")
pick(["Enroll the key"], ["No", "Yes"], "Yes")
if what == "request":
    # the password box keeps the title; OCR may miss its "Password:"
    wait(lambda l: has(l, "Password") or (has(l, "Enroll the key") and not any(norm(x) in ("no", "yes") for x in l)),
         60, "the password prompt")
    print("mokmanager.py: typing the code", flush=True)
    for ch in code:
        key(ch, 0.3)
    key("enter", 3)
pick(["Reboot"], ["Reboot"], "Reboot")
sys.exit(0)
