#!/bin/sh
#
# tests/vm/run-iso-test.sh - end-to-end test of the guided installer on the
# official FreeBSD install image, in QEMU, driven through the serial console.
#
#   sh tests/vm/run-iso-test.sh FreeBSD-15.1-RELEASE-amd64-disc1.iso tests/install-erase-kde.conf
#
# Needs: qemu-system-x86_64, OVMF (UEFI firmware), genisoimage, python3.
# Works without KVM (slow: the KDE install takes a few hours under emulation).
# Memory: 4 GB for the install VM (VM_MEM=...), 2 GB for the boot test.
# Optional:
#   EXTRA_CA=/path/ca.pem   for networks with a TLS-intercepting proxy
#   DISK_SETUP=dualboot     start from a disk that looks like a Windows/Linux
#                           machine: GPT, EFI partition with the Limine boot
#                           manager, a Linux and a Windows partition and free
#                           space (needs sgdisk and mtools). After installing,
#                           the test boots the disk: Limine -> FreeBSD entry ->
#                           FreeBSD, logs in, restarts, and uses "Start ... (L)"
#                           in FreeBSD's menu to chain back to the other loader.
#   LIMINE_EFI=/path/BOOTX64.EFI   Limine binary for DISK_SETUP=dualboot
#                           (default: downloaded from the Limine project)
#
# Result: tests/vm/work/serial.log (and boot.log); exit status 0 on success.
set -eu
ISO=$(realpath "${1:?usage: run-iso-test.sh ISO CONFIG}")
CONF=$(realpath "${2:?usage: run-iso-test.sh ISO CONFIG}")
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
W="${WORK:-$HERE/work}"   # WORK=dir runs several scenarios side by side
OVMF_CODE=${OVMF_CODE:-/usr/share/OVMF/OVMF_CODE_4M.fd}
OVMF_VARS=${OVMF_VARS:-/usr/share/OVMF/OVMF_VARS_4M.fd}
# Without KVM, QEMU's "max" CPU model makes FreeBSD 15 panic at boot; an
# older model works.
ACCEL=tcg,thread=multi CPU=Westmere
[ -w /dev/kvm ] && ACCEL=kvm CPU=max

rm -rf "$W"; mkdir -p "$W/cfg/repo"
(cd "$REPO" && tar --exclude=.git --exclude=tests/vm/work -cf - .) | tar -xf - -C "$W/cfg/repo"
# Inside the test VM the target disk is the first virtio disk.
sed 's/^INSTALL_DISK=.*/INSTALL_DISK=vtbd0/' "$CONF" > "$W/cfg/answers.conf"
CA_CMD=""
if [ -n "${EXTRA_CA:-}" ]; then cp "$EXTRA_CA" "$W/cfg/ca.pem"; CA_CMD="export SSL_CA_CERT_FILE=/media/ca.pem && "; fi
genisoimage -quiet -R -J -o "$W/cfg.iso" "$W/cfg"
cp "$OVMF_VARS" "$W/vars.fd"
TARGET="$W/target.qcow2" FMT=qcow2
if [ "${DISK_SETUP:-}" = dualboot ]; then
	# A disk like a dual-boot PC: EFI (Limine), Linux, Windows, 30 GB free.
	TARGET="$W/target.raw" FMT=raw
	truncate -s 40G "$TARGET"
	sgdisk -n1:2048:+260M -t1:ef00 -c1:EFI -n2:0:+4G -t2:8300 -n3:0:+5G -t3:0700 "$TARGET" >/dev/null
	LIMINE_EFI=${LIMINE_EFI:-$W/limine.efi}
	[ -f "$LIMINE_EFI" ] || curl -sSL -o "$LIMINE_EFI" https://raw.githubusercontent.com/limine-bootloader/limine/v10.x-binary/BOOTX64.EFI
	img="$TARGET@@1M"
	mformat -i "$img" -F -T $((260 * 2048)) -h 64 -s 32 -v EFI ::
	mmd -i "$img" ::/EFI ::/EFI/BOOT ::/EFI/Microsoft ::/EFI/Microsoft/Boot
	mcopy -i "$img" "$LIMINE_EFI" ::/EFI/BOOT/BOOTX64.EFI
	# Stand-in for Windows: another copy of Limine, so chainloading it shows
	# a recognisable menu.
	mcopy -i "$img" "$LIMINE_EFI" ::/EFI/Microsoft/Boot/bootmgfw.efi
	printf 'timeout: 3\nserial: yes\n\n/Other OS (stand-in)\n    protocol: efi\n    path: boot():/EFI/Microsoft/Boot/bootmgfw.efi\n' > "$W/limine.conf"
	mcopy -i "$img" "$W/limine.conf" ::/limine.conf
else
	qemu-img create -q -f qcow2 "$TARGET" 40G
fi

python3 - "$W/steps.json" "$CA_CMD" <<'PY'
import json, sys
out, ca = sys.argv[1], sys.argv[2]
cmd = ("dhclient vtnet0 >/dev/null 2>&1; mount_cd9660 /dev/vtbd1 /media && cp -R /media/repo /tmp/fbs && "
       + ca + "sh /tmp/fbs/install.sh --yes --config /media/answers.conf; echo INSTALLER-EXIT=$?\r")
steps = [
    [r"Escape to loader prompt", "3", 900],                    # loader menu
    [r"OK", 'set console="comconsole,efi"\r', 300],            # serial console for the kernel
    [r"OK", "boot\r", 60],
    [r"Welcome to FreeBSD|Live System", "\x1b[C\x1b[C\r", 1800],  # -> Live System
    [r"login:", "root\r", 600],
    [r"#\s*$", cmd, 600],
    [r"INSTALLER-EXIT=\d", "poweroff\r", 6 * 3600],
]
json.dump(steps, open(out, "w"))
PY

qemu-system-x86_64 -machine q35 -accel "$ACCEL" -cpu "$CPU" -smp 3 -m "${VM_MEM:-4G}" \
	-drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" -drive if=pflash,format=raw,file="$W/vars.fd" \
	-drive file="$TARGET",format=$FMT,if=virtio,cache=unsafe,discard=unmap,detect-zeroes=unmap \
	-drive file="$W/cfg.iso",if=virtio,format=raw,readonly=on \
	-drive file="$ISO",media=cdrom,readonly=on \
	-netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
	-display none -serial unix:"$W/ser.sock",server=on,wait=off -daemonize -pidfile "$W/qemu.pid"
python3 "$HERE/drive.py" "$W/ser.sock" "$W/serial.log" "$W/steps.json"
tr -d '\r' < "$W/serial.log" | grep -a -q 'INSTALLER-EXIT=0' || { echo "FAIL: installer did not finish"; exit 1; }
tr -d '\r' < "$W/serial.log" | grep -a -q 'FreeBSD is installed' || { echo "FAIL: no success message"; exit 1; }
if tr -d '\r' < "$W/serial.log" | grep -a -q 'desktop setup stopped with an error'; then
	echo "FAIL: the setup stages stopped with an error:"
	tr -d '\r' < "$W/serial.log" | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' | grep -a -E '^(ERROR|WARNING):' | head -5
	exit 1
fi
echo "PASS: installer"
[ "${BOOT_TEST:-yes}" = yes ] || exit 0

# ---- boot test --------------------------------------------------------------
# Boot the installed disk on its own, log in on the serial console, run a few
# checks. Dual boot: start FreeBSD from Limine, then restart and use
# "Start ... (L)" in FreeBSD's menu to chain back to the other loader.
# Encrypted installs: answer the boot loader's passphrase prompt.
. "$W/cfg/answers.conf"
python3 - "$W/boot-steps.json" "$USERNAME" "$USER_PASSWORD" "${DISK_SETUP:-}" "${ENCRYPT:-no}" "${ENCRYPT_PASSPHRASE:-}" <<'PY'
import json, sys
out, user, pw, setup, enc, encpw = sys.argv[1:7]
checks = ("echo CHECKS-BEGIN; freebsd-version; zfs list -H -o name | head -3; "
          "kenv -q vfs.root.mountfrom; geli status 2>/dev/null; "
          "sysrc -n hostname sddm_enable pf_enable cupsd_enable 2>/dev/null; "
          "pkg -N >/dev/null 2>&1 && pkg info -q plasma6-plasma firefox cups hyprland 2>/dev/null; "
          "ls /usr/local/share/wayland-sessions 2>/dev/null; command -v caelestia Hyprland startplasma-wayland sddm ly fcitx5 steam-setup 2>/dev/null; "
          "grep -c WARNING /var/log/freebsd-setup.log; tail -3 /var/log/freebsd-setup.log; "
          "zfs list -H -t snapshot -o name | head -3; grep fbs_chain /boot/loader.conf; echo CHECKS-DONE\r")
steps = []
if setup == "dualboot":
    steps.append([r"FreeBSD", "\x1b[B\r", 600])            # Limine menu: FreeBSD entry
if enc == "yes":
    steps.append([r"[Pp]assphrase", (encpw or pw) + "\r", 900])
steps += [
    [r"Escape to loader prompt", "3", 900],
    [r"OK", 'set console="comconsole,efi"\r', 120],
    [r"OK", "boot\r", 60],
    [r"login:", user + "\r", 3600],
    [r"Password:", pw + "\r", 60],
    [r"\$\s*$", checks, 120],
    [r"CHECKS-DONE\s", "su -m root -c 'shutdown -%s now'\r" % ("r" if setup == "dualboot" else "p"), 120],
    [r"Password:", pw + "\r", 60],
]
if setup == "dualboot":
    steps.append([r"FreeBSD", "\x1b[B\r", 900])             # Limine again
    if enc == "yes":
        steps.append([r"[Pp]assphrase", (encpw or pw) + "\r", 900])
    steps += [
        [r"Start Windows Boot Manager", "l", 600],            # FreeBSD menu: chain back
        [r"Other OS \(stand-in\)", "", 300],                    # the chained loader's menu
    ]
json.dump(steps, open(out, "w"))
PY
# Keep the NVRAM the installer wrote (its "FreeBSD" entry), as on a real PC.
cp "$W/vars.fd" "$W/vars2.fd"
qemu-system-x86_64 -machine q35 -accel "$ACCEL" -cpu "$CPU" -smp 2 -m 2G \
	-drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" -drive if=pflash,format=raw,file="$W/vars2.fd" \
	-drive file="$TARGET",format=$FMT,if=virtio,cache=unsafe \
	-netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
	-display none -serial unix:"$W/ser2.sock",server=on,wait=off -daemonize -pidfile "$W/qemu2.pid"
rc=0
python3 "$HERE/drive.py" "$W/ser2.sock" "$W/boot.log" "$W/boot-steps.json" --stop || rc=$?
kill "$(cat "$W/qemu2.pid")" 2>/dev/null || true
# Judge on the text without terminal escape codes (boot menus draw with them).
tr -d '\r' < "$W/boot.log" | sed 's/\x1b\[[0-9;?]*[A-Za-z]//g' > "$W/boot.txt"
[ "$rc" -eq 0 ] && grep -a -q 'CHECKS-DONE' "$W/boot.txt" || { echo "FAIL: boot test (see $W/boot.txt)"; exit 1; }
sed -n '/^CHECKS-BEGIN/,/^CHECKS-DONE/p' "$W/boot.txt" | grep -av 'CHECKS-'
if [ "${DISK_SETUP:-}" = dualboot ]; then
	grep -a -q 'Other OS (stand-in)' "$W/boot.txt" || { echo "FAIL: chainloading from FreeBSD's menu"; exit 1; }
	echo "PASS: boot through Limine, login, and chainload from FreeBSD's menu"
else
	echo "PASS: the installed system boots and logs in"
fi
