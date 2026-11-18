#!/bin/sh
# tests/limine-test.sh - limine_locked (lib/common.sh): the installer must
# never change limine.conf when a Limine binary has the file's checksum
# enrolled (Limine then refuses to start), nor when it cannot tell.
#
#   sh tests/limine-test.sh
#
# Uses the real Limine binary and tool when installed (limine package:
# /usr/share/limine/BOOTX64.EFI and "limine enroll-config"), and small
# stand-in files otherwise. Runs on Linux and FreeBSD.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
LOG=/dev/null
. "$HERE/../lib/common.sh"

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
pass=0 fail=0
check() { # check NAME EXPECTED(locked|free) ESP_DIR
	if limine_locked "$3"; then _r=locked; else _r=free; fi
	if [ "$_r" = "$2" ]; then pass=$((pass + 1)); echo "ok   $1 -> $2"
	else fail=$((fail + 1)); echo "FAIL $1: got $_r, want $2"; fi
}
esp() { rm -rf "$T/esp"; mkdir -p "$T/esp/EFI/BOOT" "$T/esp/EFI/Microsoft/Boot"; printf 'timeout: 3\n' > "$T/esp/limine.conf"; }
zeros=$(printf '%0128d' 0)
hash=$(printf '%0127d1' 0)

# Stand-in binaries: some bytes, the signature, the 128-character slot.
fake() { printf 'MZ\001\002binary++CONFIG_B2SUM_SIGNATURE++%s\000\377tail' "$2" > "$1"; }
esp; fake "$T/esp/EFI/BOOT/BOOTX64.EFI" "$zeros"
check "stand-in: no checksum enrolled" free "$T/esp"
esp; fake "$T/esp/EFI/BOOT/BOOTX64.EFI" "$hash"
check "stand-in: checksum enrolled" locked "$T/esp"
esp; fake "$T/esp/EFI/BOOT/BOOTX64.EFI" "$zeros"; fake "$T/esp/EFI/Microsoft/Boot/bootmgfw.efi" "$hash"
check "stand-in: one of two binaries enrolled" locked "$T/esp"
esp; printf 'MZ not limine' > "$T/esp/EFI/BOOT/BOOTX64.EFI"
check "no Limine binary found: leave it alone" locked "$T/esp"
esp; fake "$T/esp/EFI/BOOT/bootx64.efi" "$zeros"
check "lower-case file name" free "$T/esp"

# The real thing, when the limine package is installed.
for b in /usr/share/limine/BOOTX64.EFI /usr/local/share/limine/BOOTX64.EFI; do
	[ -f "$b" ] || continue
	esp; cp "$b" "$T/esp/EFI/BOOT/BOOTX64.EFI"
	check "real Limine ($b), as shipped" free "$T/esp"
	if command -v limine >/dev/null && command -v b2sum >/dev/null; then
		limine enroll-config "$T/esp/EFI/BOOT/BOOTX64.EFI" "$(b2sum "$T/esp/limine.conf" | cut -d' ' -f1)" --quiet 2>/dev/null ||
			limine enroll-config "$T/esp/EFI/BOOT/BOOTX64.EFI" "$(b2sum "$T/esp/limine.conf" | cut -d' ' -f1)" >/dev/null
		check "real Limine, config checksum enrolled" locked "$T/esp"
	else
		echo "skip real Limine with enrolled checksum (needs limine and b2sum)"
	fi
	break
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
