#!/bin/sh
# tests/efiboot-test.sh - reading "efibootmgr -v" (lib/common.sh efi_entries,
# efi_first, efi_file): the installer uses it to find the system the computer
# starts today (FreeBSD's menu offers it with key L) and its own old entries.
# Fixtures: a real FreeBSD 15.1 capture (path on the entry's line) and the
# layout of later versions (path on "dp:" lines below it).
#
#   sh tests/efiboot-test.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
LOG=/dev/null
. "$HERE/../lib/common.sh"
F=$HERE/fixtures/efibootmgr
pass=0 fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); printf 'FAIL %s\n     want: %s\n     got:  %s\n' "$1" "$2" "$3"; fi; }
entry() { efi_entries < "$1" | awk -F'|' -v n="$2" '$1 == n { print; exit }'; }

f=$F/freebsd-15.1-qemu.txt
check "15.1: first in BootOrder" "000A" "$(efi_first < "$f")"
check "15.1: entry name" "FreeBSD" "$(entry "$f" 000A | cut -d'|' -f2)"
check "15.1: entry file" "/EFI/freebsd/loader.efi" "$(efi_file "$(entry "$f" 000A | cut -d'|' -f3-)")"
check "15.1: name with brackets kept whole" "UEFI PXEv4 (MAC:525400123456)" "$(entry "$f" 0005 | cut -d'|' -f2)"
check "15.1: firmware app has no file" "" "$(efi_file "$(entry "$f" 0000 | cut -d'|' -f3-)")"
check "15.1: all entries read" "9" "$(efi_entries < "$f" | wc -l | tr -d ' ')"

f=$F/freebsd-main-dp-lines.txt
check "dp lines: first in BootOrder" "0003" "$(efi_first < "$f")"
check "dp lines: entry name" "Limine" "$(entry "$f" 0003 | cut -d'|' -f2)"
check "dp lines: entry file" "/EFI/limine/limine_x64.efi" "$(efi_file "$(entry "$f" 0003 | cut -d'|' -f3-)")"
check "dp lines: Windows file" "/EFI/Microsoft/Boot/bootmgfw.efi" "$(efi_file "$(entry "$f" 0000 | cut -d'|' -f3-)")"
check "dp lines: our old entries by EFI partition" "000A" \
	"$(efi_entries < "$f" | awk -F'|' -v u="21541FD2-F358-42EB-970D-3923F3385672" '$2 == "FreeBSD" && index(tolower($3), tolower(u)) { print $1 }')"
check "dp lines: all entries read" "4" "$(efi_entries < "$f" | wc -l | tr -d ' ')"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
