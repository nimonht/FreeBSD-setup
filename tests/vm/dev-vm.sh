#!/bin/sh
#
# tests/vm/dev-vm.sh - a FreeBSD development VM for working on the stages and
# services: a read-only base image made by run-iso-test.sh, a throwaway
# overlay on top, SSH on 127.0.0.1, the working tree copied in on demand.
#
#   sh tests/vm/dev-vm.sh base WORKDIR   keep WORKDIR/target.qcow2 + vars.fd
#                                        (from run-iso-test.sh, BOOT_TEST=no)
#                                        as the base, enable SSH in it (once)
#   sh tests/vm/dev-vm.sh start          boot a new overlay (or the existing one)
#   sh tests/vm/dev-vm.sh gui            same, with a window (software graphics)
#   sh tests/vm/dev-vm.sh ssh [CMD...]   log in as root (or run CMD)
#   sh tests/vm/dev-vm.sh sync           copy the working tree to /root/fbs
#   sh tests/vm/dev-vm.sh stop           power off
#   sh tests/vm/dev-vm.sh reset          stop and throw the overlay away
#
# Files live in DEV_VM_DIR (default ~/VMs/freebsd-setup-dev). The VM only
# ever sees image files there, never a host disk. SSH key: a key made for
# this VM only (DEV_VM_DIR/ssh_key), not yours. Root password: the one in the
# install config (test123 in tests/install-*.conf).
set -eu
D=${DEV_VM_DIR:-$HOME/VMs/freebsd-setup-dev}
REPO=$(cd "$(dirname "$0")/../.." && pwd)
PORT=${DEV_VM_SSH_PORT:-2222}
OVMF_CODE=${OVMF_CODE:-/usr/share/edk2/x64/OVMF_CODE.4m.fd}
[ -f "$OVMF_CODE" ] || OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
ROOTPW=${DEV_VM_ROOTPW:-test123}
SSH="ssh -i $D/ssh_key -p $PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=$D/known_hosts -o LogLevel=ERROR -o ConnectTimeout=30"

running() { [ -f "$D/qemu.pid" ] && kill -0 "$(cat "$D/qemu.pid")" 2>/dev/null; }

boot() { # boot IMAGE VARS DISPLAY-ARGS...
	img=$1 vars=$2; shift 2
	qemu-system-x86_64 -machine q35 -accel kvm -cpu host -smp "${DEV_VM_CPUS:-4}" -m "${DEV_VM_MEM:-6G}" \
		-drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" -drive if=pflash,format=raw,file="$vars" \
		-drive file="$img",format=qcow2,if=virtio,cache=writeback,discard=unmap \
		-netdev user,id=n0,hostfwd=tcp:127.0.0.1:"$PORT"-:22 -device virtio-net-pci,netdev=n0 \
		-device qemu-xhci -device usb-tablet \
		-serial unix:"$D/serial.sock",server=on,wait=off -pidfile "$D/qemu.pid" "$@"
}

wait_ssh() {
	i=0
	while ! $SSH root@127.0.0.1 true 2>/dev/null; do
		i=$((i + 1)); [ $i -gt 120 ] && { echo "no SSH after 4 minutes (serial: $D/serial.sock)"; return 1; }
		sleep 2
	done
}

case "${1:-}" in
base)
	W=$(realpath "${2:?usage: dev-vm.sh base WORKDIR}")
	running && { echo "stop the VM first"; exit 1; }
	[ -f "$W/target.qcow2" ] && [ -f "$W/vars.fd" ] || { echo "no target.qcow2 + vars.fd in $W"; exit 1; }
	mkdir -p "$D"
	cp --reflink=auto "$W/target.qcow2" "$D/base.qcow2"; cp "$W/vars.fd" "$D/base-vars.fd"
	[ -f "$D/ssh_key" ] || ssh-keygen -q -t ed25519 -N "" -C freebsd-setup-dev-vm -f "$D/ssh_key"
	# Enable SSH with this key, through the serial console, in the base itself.
	key=$(cat "$D/ssh_key.pub")
	cmd="mkdir -p /root/.ssh && echo '$key' >> /root/.ssh/authorized_keys && chmod 700 /root/.ssh && chmod 600 /root/.ssh/authorized_keys && sysrc sshd_enable=YES && printf 'PermitRootLogin prohibit-password\nUseDNS no\n' >> /etc/ssh/sshd_config && echo 'pass in proto tcp to port 22' >> /etc/pf.local.conf && { grep -q pf.local.conf /etc/pf.conf || echo 'include \"/etc/pf.local.conf\"' >> /etc/pf.conf; } && echo PROVISION-'DONE' && shutdown -p now"
	# (the quotes keep the echoed command line itself from matching PROVISION-DONE)
	python3 - "$D/provision.json" "$ROOTPW" "$cmd" <<'PY'
import json, sys
out, pw, cmd = sys.argv[1:4]
json.dump([[r"Escape to loader prompt", "3", 900], [r"OK", 'set console="comconsole,efi"\r', 120],
           [r"OK", "boot\r", 60], [r"login:", "root\r", 3600], [r"Password:", pw + "\r", 60],
           [r"#\s*$", cmd + "\r", 120], [r"PROVISION-DONE", "", 120]], open(out, "w"))
PY
	rm -f "$D/serial.sock"
	boot "$D/base.qcow2" "$D/base-vars.fd" -display none -daemonize
	python3 "$REPO/tests/vm/drive.py" "$D/serial.sock" "$D/provision.log" "$D/provision.json" --stop
	i=0; while running && [ $i -lt 60 ]; do sleep 1; i=$((i + 1)); done
	running && kill "$(cat "$D/qemu.pid")"
	chmod a-w "$D/base.qcow2"
	echo "base ready: $D/base.qcow2 (read-only). Next: sh $0 start"
	;;
start|gui)
	running && { echo "already running (ssh: sh $0 ssh)"; exit 0; }
	[ -f "$D/base.qcow2" ] || { echo "no base image: run '$0 base WORKDIR' first"; exit 1; }
	[ -f "$D/overlay.qcow2" ] || { qemu-img create -q -f qcow2 -b "$D/base.qcow2" -F qcow2 "$D/overlay.qcow2"; cp "$D/base-vars.fd" "$D/overlay-vars.fd"; }
	rm -f "$D/serial.sock"
	if [ "$1" = gui ]; then boot "$D/overlay.qcow2" "$D/overlay-vars.fd" -vga none -device virtio-vga -display gtk,gl=off -daemonize
	else boot "$D/overlay.qcow2" "$D/overlay-vars.fd" -display none -daemonize; fi
	# The loader waits at its menu; pick the default entry.
	python3 - "$D/serial.sock" <<'PY' || true
import socket, sys, time
s = socket.socket(socket.AF_UNIX); t = time.time()
while time.time() - t < 30:
    try: s.connect(sys.argv[1]); break
    except OSError: time.sleep(0.5)
s.sendall(b"\r")
PY
	wait_ssh && echo "up: sh $0 ssh"
	;;
ssh)
	shift; exec $SSH root@127.0.0.1 "$@" ;;
sync)
	(cd "$REPO" && tar --exclude=.git --exclude=tests/vm/work -cf - .) | $SSH root@127.0.0.1 'rm -rf /root/fbs && mkdir -p /root/fbs && tar -xf - -C /root/fbs'
	echo "copied to /root/fbs: run a stage with  sh $0 ssh 'cd /root/fbs && sh setup.sh STAGE'" ;;
stop)
	running || exit 0
	$SSH root@127.0.0.1 'shutdown -p now' 2>/dev/null || kill "$(cat "$D/qemu.pid")"
	i=0; while running && [ $i -lt 60 ]; do sleep 1; i=$((i + 1)); done
	running && kill "$(cat "$D/qemu.pid")"; true ;;
reset)
	sh "$0" stop; rm -f "$D/overlay.qcow2" "$D/overlay-vars.fd"; echo "overlay removed" ;;
*)
	sed -n '3,20p' "$0"; exit 1 ;;
esac
