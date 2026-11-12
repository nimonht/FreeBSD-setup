#!/bin/sh
# tests/collect-fixture.sh - record this machine's hardware as a test profile.
#
#   sh tests/collect-fixture.sh my-laptop-model
#
# Creates tests/fixtures/<name>/ with the raw output of the probes the
# hardware detection uses (no personal files, no serial numbers). Check
# expect.txt, adjust it to what really works on the machine, and send it in
# a pull request: from then on every change is tested against your hardware.
set -eu
name=${1:?usage: collect-fixture.sh NAME}
here=$(cd "$(dirname "$0")" && pwd)
d="$here/fixtures/$name"
mkdir -p "$d"
pciconf -lv > "$d/pciconf.txt"
{ usbconfig dump_device_desc; usbconfig dump_curr_config_desc; } 2>/dev/null |
	grep -v -i 'iSerialNumber' > "$d/usb.txt" || true
for k in hw.machine kern.osrelease machdep.bootmethod kern.vm_guest hw.model hw.ncpu hw.physmem \
	hw.acpi.battery.units hw.acpi.supported_sleep_state hw.pci.default_vgapci_unit net.wlan.devices; do
	v=$(sysctl -n "$k" 2>/dev/null) && printf '%s=%s\n' "$k" "$v"
done > "$d/sysctl.txt"
for k in smbios.system.maker smbios.system.product smbios.system.version smbios.system.family smbios.chassis.type; do
	v=$(kenv -q "$k" 2>/dev/null) && printf '%s="%s"\n' "$k" "$v"
done > "$d/kenv.txt"
cat /dev/sndstat > "$d/sndstat.txt" 2>/dev/null || true
grep -m1 'Origin=' /var/run/dmesg.boot > "$d/dmesg.txt" 2>/dev/null || true
mount -p | awk '$2 == "/"' > "$d/mount.txt"
# Current detection results as the starting expectation.
(
	FBS_LIB="$here/../lib"; HW_FIXTURES="$d/"
	. "$FBS_LIB/hw.sh"; hw_detect
	for v in HW_GPU_PRIMARY HW_GPU_HYBRID HW_NVIDIA_BRANCH HW_AMD_KMOD HW_DESKTOP HW_LAPTOP HW_ACPI_KMOD HW_VM HW_BOOT; do
		eval "printf '%s=%s\n' $v \"\$$v\""
	done
) > "$d/expect.txt"
echo "Recorded $d - review expect.txt, then: sh tests/run.sh -v $name"
