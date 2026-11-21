#!/bin/sh
#
# tests/vm/run-secureboot-test.sh - Secure Boot on real UEFI firmware (OVMF,
# EDK2's), in QEMU, driven through the serial console.
#
#   sh tests/vm/run-secureboot-test.sh ISO setup
#       Firmware in Setup Mode (no keys). The live system makes keys and
#       enrolls them with Microsoft's (lib/secureboot.sh, sb_enroll_own), then
#       writes FreeBSD's loader signed with its db key to a disk, and an
#       unsigned copy. With Secure Boot then enforced, the firmware must start
#       the signed loader and refuse the unsigned one. Uses no shim: give it
#       an ISO built with SECURE_BOOT=no (the live system has the same tools).
#
#   sh tests/vm/run-secureboot-test.sh ISO mok
#       Secure Boot on with Microsoft's keys (OVMF_VARS_4M.ms.fd), an ISO
#       built with SECURE_BOOT=yes. Fedora's shim starts; the loader's key is
#       unknown, so MokManager comes up; the key file on the stick is
#       enrolled; the live system starts with Secure Boot on and makes a MOK
#       request for a new key (sb_mok_request, as the installer does); after a
#       restart MokManager takes it with the code; the key must then be in
#       shim's MOK list. (Runs Fedora's Microsoft-signed shim in the VM.)
#
# Needs qemu-system-x86_64, OVMF with Secure Boot (Ubuntu's ovmf:
# OVMF_CODE_4M.secboot.fd, OVMF_VARS_4M.fd, OVMF_VARS_4M.ms.fd), mtools,
# python3. Without KVM it is slow (minutes for each start of the live
# system). Result in tests/vm/sb-work/: serial logs and screenshots; exit 0
# when every check passed.
set -eu
ISO=$(realpath "${1:?usage: run-secureboot-test.sh ISO setup|mok}")
SCEN=${2:?usage: run-secureboot-test.sh ISO setup|mok}
HERE=$(cd "$(dirname "$0")" && pwd)
W="${WORK:-$HERE/sb-work}"
OVMF_CODE=${OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.secboot.fd}
OVMF_VARS=${OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}
OVMF_VARS_MS=${OVMF_VARS_MS:-/usr/share/OVMF/OVMF_VARS_4M.ms.fd}
ACCEL=tcg,thread=multi CPU=Westmere
[ -w /dev/kvm ] && ACCEL=kvm CPU=max
rm -rf "$W"; mkdir -p "$W"
W=$(cd "$W" && pwd)
DB=d719b2cb-3d3a-4596-a3bc-dad00e67656f
SHIM=605dab50-e046-4300-abb6-3dd810dd8b23
fail=0
check() { if tr -d '\r' < "$3" | grep -a -q -E "$2"; then echo "ok:   $1"; else echo "FAIL: $1"; fail=1; fi; }
nocheck() { if tr -d '\r' < "$3" | grep -a -q -E "$2"; then echo "FAIL: $1"; fail=1; else echo "ok:   $1"; fi; }

# vm NAME DRIVE-ARGS...   start the VM on the firmware state in vars.fd
vm() {
	_n=$1; shift
	rm -f "$W/ser.sock" "$W/mon.sock"
	# shellcheck disable=SC2068
	qemu-system-x86_64 -machine q35,smm=on -global driver=cfi.pflash01,property=secure,value=on \
		-accel "$ACCEL" -cpu "$CPU" -smp 4 -m "${VM_MEM:-6G}" \
		-drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" -drive if=pflash,format=raw,file="$W/vars.fd" \
		$@ -netdev user,id=n0 -device virtio-net-pci,netdev=n0 -vga std -display none \
		-serial unix:"$W/ser.sock",server=on,wait=off -monitor unix:"$W/mon.sock",server=on,wait=off \
		-daemonize -pidfile "$W/qemu-$_n.pid"
}
vm_stop() { [ -f "$W/qemu-$1.pid" ] && kill "$(cat "$W/qemu-$1.pid")" 2>/dev/null; sleep 3; }
shot() {
	python3 - "$W/mon.sock" "$W/$1.ppm" <<'PY' || true
import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); time.sleep(0.5); s.recv(65536)
s.sendall(("screendump %s\n" % sys.argv[2]).encode()); time.sleep(2)
PY
	python3 -c "from PIL import Image; Image.open('$W/$1.ppm').save('$W/$1.png')" 2>/dev/null || true
}
# steps FILE [WAIT SEND TIMEOUT]...   a tests/vm/drive.py steps file
steps() {
	_f=$W/$1; shift
	python3 -c 'import json, sys; a = sys.argv[2:]; json.dump([[a[i], a[i+1], int(a[i+2])] for i in range(0, len(a), 3)], open(sys.argv[1], "w"))' "$_f" "$@"
}
drive() { python3 "$HERE/drive.py" "$W/ser.sock" "$W/$1" "$W/$2" --stop; }

LIB='REPO_DIR=/usr/local/share/freebsd-setup; . $REPO_DIR/distro.conf; . $REPO_DIR/lib/secureboot.sh'
# boot_and_run FILE COMMANDS AFTER   from the boot menu to a root shell (the
# kernel's console on the serial line too), run COMMANDS, then AFTER.
# "CHECKS-%s DONE" so that the echo of the typed line does not match.
CR=$(printf '\r')
boot_and_run() {
	steps "$1" "Escape to loader prompt" "3" 900 "OK" "set console=\"comconsole,efi\"$CR" 300 \
		"OK" "boot$CR" 60 "login:" "root$CR" 5400 '#\s*$' "$2; printf 'CHECKS-%s\\n' DONE$CR" 300 \
		'CHECKS-DONE' "$3$CR" 1800
}

if [ "$SCEN" = setup ]; then
	cp "$OVMF_VARS" "$W/vars.fd"
	qemu-img create -q -f raw "$W/disk.img" 256M
	vm live -drive file="$ISO",media=cdrom,readonly=on -drive file="$W/disk.img",format=raw,if=virtio -boot d
	boot_and_run s1.json "$LIB; echo STATE1=\$(sb_state); \
sh \$REPO_DIR/install.sh --probe 2>/dev/null | grep '^secureboot' | tr '\\t' ' ' | sed 's/^/PROBE: /'; \
sh \$REPO_DIR/files/bin/secureboot | sed 's/^/STATUS: /'; sb_keys /tmp/k vmtest && sb_enroll_own /tmp/k && echo ENROLLED=yes; \
echo STATE2=\$(sb_state); sb_var $DB-db > /tmp/db; echo DBCERTS=\$(sb_py esl-certs /tmp/db | wc -l); \
gpart create -s gpt vtbd0 >/dev/null && gpart add -a 1m -t efi vtbd0 >/dev/null && newfs_msdos -F 16 /dev/vtbd0p1 >/dev/null 2>&1 && \
mount -t msdosfs /dev/vtbd0p1 /mnt && mkdir -p /mnt/EFI/BOOT /mnt/EFI/unsigned && \
sb_sign_loader /tmp/k /boot/loader.efi /mnt/EFI/BOOT/BOOTX64.EFI && cp /boot/loader.efi /mnt/EFI/unsigned/BOOTX64.EFI && \
umount /mnt && echo DISK=ready" "shutdown -p now"
	drive serial-live.log s1.json || { shot live-fail; vm_stop live; echo "FAIL: the live system did not finish (see $W/serial-live.log)"; exit 1; }
	sleep 30; vm_stop live
	check "the firmware was in Setup Mode" '^STATE1=setup' "$W/serial-live.log"
	check "install.sh --probe: Setup Mode, own keys" '^PROBE: secureboot setup own' "$W/serial-live.log"
	check "secureboot (command): says Setup Mode" '^STATUS: Firmware: +Setup Mode' "$W/serial-live.log"
	check "keys enrolled from FreeBSD (efivar)" '^ENROLLED=yes' "$W/serial-live.log"
	check "Setup Mode ended" '^STATE2=(on|off)' "$W/serial-live.log"
	check "db: this computer's key and Microsoft's five" '^DBCERTS= *6' "$W/serial-live.log"
	check "disk prepared" '^DISK=ready' "$W/serial-live.log"

	# The same firmware, Secure Boot now enforced: the signed loader starts.
	vm signed -drive file="$W/disk.img",format=raw,if=virtio
	steps s2.json 'EFI loader|Access Denied|Security Violation|Shell>' "" 600
	drive serial-signed.log s2.json || true
	sleep 8; shot signed; vm_stop signed
	check "signed loader: started under Secure Boot" 'FreeBSD/amd64 EFI loader' "$W/serial-signed.log"
	nocheck "signed loader: not refused" 'Access Denied|Security Violation' "$W/serial-signed.log"

	# FreeBSD's unsigned loader in the same place must be refused.
	mcopy -o -i "$W/disk.img@@1M" ::/EFI/unsigned/BOOTX64.EFI "$W/unsigned-loader.efi"
	mcopy -o -i "$W/disk.img@@1M" "$W/unsigned-loader.efi" ::/EFI/BOOT/BOOTX64.EFI
	vm unsigned -drive file="$W/disk.img",format=raw,if=virtio
	steps s3.json 'EFI loader|Access Denied|Security Violation|Shell>' "" 600
	drive serial-unsigned.log s3.json || true
	sleep 8; shot unsigned; vm_stop unsigned
	nocheck "unsigned loader: not started" 'FreeBSD/amd64 EFI loader' "$W/serial-unsigned.log"
	check "unsigned loader: refused by the firmware" 'Access Denied|Security Violation' "$W/serial-unsigned.log"
	exit "$fail"
fi

[ "$SCEN" = mok ] || { echo "usage: run-secureboot-test.sh ISO setup|mok" >&2; exit 2; }
cp "$OVMF_VARS_MS" "$W/vars.fd"
vm live -drive file="$ISO",media=cdrom,readonly=on -boot d
# 1. shim starts; the loader's key is unknown; enroll the stick's key file.
python3 "$HERE/mokmanager.py" "$W/ser.sock" "$W/serial-1.log" from-disk ||
	{ shot mok1-fail; vm_stop live; echo "FAIL: could not enroll the key from the stick (see $W/serial-1.log, mok1-fail.png)"; exit 1; }
echo "ok:   MokManager came up and took the key file from the stick"
# 2. The stick again (now trusted): the live system, a MOK request, restart.
boot_and_run m2.json "$LIB; echo STATE=\$(sb_state); sb_keys /tmp/k vmtest >/dev/null && sb_mok_request /tmp/k/db.cer 31415926 && echo REQUEST=yes" "shutdown -r now"
drive serial-2.log m2.json || { shot live-fail; vm_stop live; echo "FAIL: the live system did not start after enrolling (see $W/serial-2.log)"; exit 1; }
check "the live system started through shim, Secure Boot on" '^STATE=on' "$W/serial-2.log"
check "MOK request written from FreeBSD (efivar)" '^REQUEST=yes' "$W/serial-2.log"
# 3. MokManager for the request: confirm it with the code.
python3 "$HERE/mokmanager.py" "$W/ser.sock" "$W/serial-3.log" request 31415926 ||
	{ shot mok3-fail; vm_stop live; echo "FAIL: could not confirm the request (see $W/serial-3.log)"; exit 1; }
echo "ok:   MokManager took the request with the code"
# 4. The live system again: two keys in the MOK list (the stick's and the new one).
boot_and_run m4.json "$LIB; sb_var $SHIM-MokListRT > /tmp/mok; echo MOKKEYS=\$(sb_py esl-certs /tmp/mok | wc -l)" "shutdown -p now"
drive serial-4.log m4.json || { shot end-fail; vm_stop live; echo "FAIL: the live system did not start after confirming (see $W/serial-4.log)"; exit 1; }
sleep 30; vm_stop live
check "both keys are in shim's MOK list" '^MOKKEYS= *2' "$W/serial-4.log"
exit "$fail"
