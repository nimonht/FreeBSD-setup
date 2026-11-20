#!/bin/sh
#
# tests/vm/run-live-test.sh - boot the LumenBSD live ISO in QEMU and check
# that the live system starts: boot menu -> ramdisk -> system copied into
# memory -> reroot -> live session. A plain QEMU guest has no KMS graphics,
# so the expected session is the installer alone on a basic framebuffer
# (scfb on UEFI, vesa on BIOS); the test saves a picture of the screen.
#
#   sh tests/vm/run-live-test.sh iso/out/lumenbsd-0.1-amd64.iso [uefi|bios]
#
# Needs qemu-system-x86_64, OVMF (for uefi), python3. Works without KVM
# (slow: several minutes). Result: tests/vm/live-work/serial.log and
# screen.png; exit status 0 when every check passed.
set -eu
ISO=$(realpath "${1:?usage: run-live-test.sh ISO [uefi|bios]}")
FW=${2:-uefi}
HERE=$(cd "$(dirname "$0")" && pwd)
W="${WORK:-$HERE/live-work}"
OVMF_CODE=${OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}
OVMF_VARS=${OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}
ACCEL=tcg,thread=multi CPU=Westmere
[ -w /dev/kvm ] && ACCEL=kvm CPU=max

rm -rf "$W"; mkdir -p "$W"
FWARGS=""
if [ "$FW" = uefi ]; then
	cp "$OVMF_VARS" "$W/vars.fd"
	FWARGS="-drive if=pflash,format=raw,readonly=on,file=$OVMF_CODE -drive if=pflash,format=raw,file=$W/vars.fd"
fi

# Checks run as root on the live system's serial console.
checks="printf 'CHECKS-%s\\n' BEGIN; cat /var/run/lumen-live/session /var/run/lumen-live/reason; \
mount -p | head -3; zpool list -H -o name,size,alloc lumenlive; . /etc/os-release; echo \"\$PRETTY_NAME\"; \
sleep 120; pgrep -lf 'Xorg|sddm|lumen-installer' | cut -c1-90; \
ls /usr/local/etc/sddm.conf.d /usr/local/etc/X11/xorg.conf.d; \
grep -h 'EE)' /var/log/Xorg.0.log 2>/dev/null | head -5; printf 'CHECKS-%s\\n' DONE"
python3 - "$W/steps.json" "$FW" "$checks" <<'PY'
import json, sys
out, fw, checks = sys.argv[1:4]
steps = []
if fw == "uefi":
    # the boot menu is on the serial line too (OVMF); send the kernel there
    steps += [[r"Escape to loader prompt", "3", 900],
              [r"OK", 'set console="comconsole,efi"\r', 300],
              [r"OK", "boot\r", 60]]
steps += [[r"loading LumenBSD into memory", "", 1800],
          [r"LumenBSD: live session: ", "", 3600],
          [r"login:", "root\r", 1800],
          [r"#\s*$", checks + "\r", 300],
          [r"CHECKS-DONE", "", 900]]
json.dump(steps, open(out, "w"))
PY

# shellcheck disable=SC2086
qemu-system-x86_64 -machine q35 -accel "$ACCEL" -cpu "$CPU" -smp 4 -m "${VM_MEM:-6G}" $FWARGS \
	-drive file="$ISO",media=cdrom,readonly=on -boot d \
	-netdev user,id=n0 -device virtio-net-pci,netdev=n0 -vga std \
	-display none -serial unix:"$W/ser.sock",server=on,wait=off \
	-monitor unix:"$W/mon.sock",server=on,wait=off -daemonize -pidfile "$W/qemu.pid"
# BIOS boots: the kernel's console is the screen; the serial line only gets a
# login prompt once the live system runs (ttyu0 is "onifconsole" -> not
# there). Then the test can only wait and take a picture.
rc=0
if [ "$FW" = uefi ]; then
	python3 "$HERE/drive.py" "$W/ser.sock" "$W/serial.log" "$W/steps.json" --stop || rc=$?
else
	sleep "${BIOS_WAIT:-900}"
fi
python3 - "$W/mon.sock" "$W/screen.ppm" <<'PY'
import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); time.sleep(0.5); s.recv(65536)
s.sendall(("screendump %s\n" % sys.argv[2]).encode()); time.sleep(2); s.sendall(b"quit\n"); time.sleep(1)
PY
python3 -c "
from PIL import Image; import sys
Image.open('$W/screen.ppm').save('$W/screen.png')" 2>/dev/null || cp "$W/screen.ppm" "$W/screen.png"
[ "$rc" -eq 0 ] || { echo "FAIL: the live system did not get to the checks (see $W/serial.log)"; exit 1; }
log=$(tr -d '\r' < "$W/serial.log" | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g')
fail=0
check() { if printf '%s\n' "$log" | grep -a -q -E "$2"; then echo "ok:   $1"; else echo "FAIL: $1"; fail=1; fi; }
check "system copied into memory" 'loading LumenBSD into memory'
check "rerooted into the memory pool" '^lumenlive[[:space:]]+/[[:space:]]+zfs'
check "installer session chosen (no KMS in QEMU)" 'LumenBSD: live session: installer'
check "os-release names LumenBSD" '^LumenBSD [0-9.]+ \(FreeBSD 15'
check "X server running" 'Xorg'
check "installer running" 'lumen-installer'
echo "screen: $W/screen.png"
exit "$fail"
