#!/usr/bin/env python3
"""Answer shim's MokManager (the blue screen) through QEMU's serial line,
by the text of its menus, as a person would.

  mokmanager.py SOCKET LOG from-disk      Enroll key from disk: the first
                                          file system, the .cer file at its
                                          top, Continue, Yes, Reboot
  mokmanager.py SOCKET LOG request CODE   Enroll MOK, Continue, Yes, the
                                          code, Reboot

OVMF draws MokManager on the serial console too, with cursor movements;
entries are found by their text in what was drawn since the last screen
clear, and chosen with the arrow keys from the first entry (MokManager
highlights the first entry of every new menu)."""
import re
import socket
import sys
import time

sock_path, log_path, what = sys.argv[1:4]
code = sys.argv[4] if len(sys.argv) > 4 else ""
s = None
for _ in range(120):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        break
    except OSError:
        time.sleep(1)
s.settimeout(0.5)
log = open(log_path, "ab", buffering=0)
screen = ""


def pump(secs):
    """Read for secs seconds; keep what was drawn since the last clear."""
    global screen
    end = time.time() + secs
    while time.time() < end:
        try:
            d = s.recv(65536)
        except socket.timeout:
            continue
        if not d:
            break
        log.write(d)
        t = d.decode("utf-8", "replace")
        if "\x1b[2J" in t:
            screen = ""
            t = t.split("\x1b[2J")[-1]
        t = re.sub(r"\x1b\[\d+;\d+H", "\n", t)      # cursor moves: new line
        screen += re.sub(r"\x1b\[[0-9;?]*[A-Za-z]", "", t)


def wait(pattern, secs):
    end = time.time() + secs
    while time.time() < end:
        pump(1)
        if re.search(pattern, screen):
            return True
    print("mokmanager.py: timed out waiting for %r; screen:\n%s" % (pattern, screen[-1500:]))
    return False


def key(k, pause=0.6):
    s.sendall({"down": b"\x1b[B", "up": b"\x1b[A", "enter": b"\r"}.get(k, k.encode()))
    time.sleep(pause)


def choose(entry, entries):
    """Move from the first of entries (in screen order) to entry, Enter."""
    lines = [l.strip() for l in screen.splitlines() if l.strip()]
    present = []
    for l in lines:
        for e in entries:
            if l.startswith(e) and e not in present:
                present.append(e)
    if entry not in present:
        print("mokmanager.py: %r not on screen (found %s):\n%s" % (entry, present, screen[-1500:]))
        sys.exit(1)
    print("mokmanager.py: %s" % entry, flush=True)
    for _ in range(present.index(entry)):
        key("down")
    key("enter", 2)
    pump(3)


MAIN = ["Continue boot", "Enroll MOK", "Delete MOK", "Change Secure Boot state", "Set MOK password",
        "Reset MOK", "Enroll key from disk", "Enroll hash from disk"]

# shim first; a failed verification may show a message to dismiss; then
# MokManager's "Press any key" (10 s) when a request waits.
if not wait(r"Shim UEFI key management|Perform MOK management|Verification failed|Press any key", 1200):
    sys.exit(1)
if re.search(r"Verification failed|Failed to", screen) and not re.search(r"Perform MOK management", screen):
    key("enter", 3)
    pump(3)
if re.search(r"Press any key", screen) and not re.search(r"Perform MOK management", screen):
    key(" ", 3)
if not wait(r"Perform MOK management", 120):
    sys.exit(1)
pump(2)

if what == "from-disk":
    choose("Enroll key from disk", MAIN)
    wait(r"Select Key|EFI|\.cer", 60)
    pump(2)
    # The file systems: the stick's EFI image is the one to open (the first).
    lines = [l.strip() for l in screen.splitlines() if l.strip() and not l.strip().startswith("Select")]
    print("mokmanager.py: file systems: %s" % lines[:6], flush=True)
    key("enter", 3)
    pump(3)
    if not re.search(r"ENROLL_THIS_KEY_IN_MOKMANAGER\.cer", screen, re.I):
        print("mokmanager.py: the key file is not listed:\n%s" % screen[-1500:])
        sys.exit(1)
    files = [l.strip() for l in screen.splitlines() if l.strip()]
    entries = [f for f in files if f.endswith("/") or re.search(r"\.(cer|der|crt|efi)$", f, re.I)]
    target = next(f for f in entries if f.upper().startswith("ENROLL_THIS_KEY"))
    choose(target, entries)
elif what == "request":
    choose("Enroll MOK", MAIN)
else:
    sys.exit(2)

if not wait(r"Continue", 60):
    sys.exit(1)
choose("Continue", ["View key 0", "View key", "Continue"])
if not wait(r"Enroll the key", 60):
    sys.exit(1)
choose("Yes", ["No", "Yes"])
if what == "request":
    if not wait(r"[Pp]assword", 60):
        sys.exit(1)
    for ch in code:
        key(ch, 0.2)
    key("enter", 3)
    pump(3)
if not wait(r"Reboot", 60):
    sys.exit(1)
choose("Reboot", ["Reboot", "Continue boot"])
sys.exit(0)
