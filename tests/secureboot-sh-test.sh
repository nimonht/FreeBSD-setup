#!/bin/sh
# tests/secureboot-sh-test.sh - lib/secureboot.sh against a pretend
# firmware: efivar, sysctl and uefisign are replaced by small programs that
# keep UEFI variables in files (an authenticated write's header is removed,
# as firmware does; setting PK ends Setup Mode). Checks the firmware state,
# keys, the signed loader, the files on the EFI partition, the MOK request
# and the Setup Mode enrollment (order, flags, nothing duplicated).
# Runs on Linux and FreeBSD; needs python3 and openssl (sbsign optional).
#
#   sh tests/secureboot-sh-test.sh
set -u
REPO_DIR=$(cd "$(dirname "$0")/.." && pwd)
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
fail=0
check() { if eval "$2"; then echo "ok:   $1"; else echo "FAIL: $1"; fail=1; fi; }

mkdir -p "$T/bin" "$T/vars"
export SB_FAKE_VARS="$T/vars" SB_FAKE_BOOT=UEFI
cat > "$T/bin/efivar" <<'EOF'
#!/usr/bin/env python3
import os, struct, sys
d = os.environ["SB_FAKE_VARS"]
args = sys.argv[1:]
name = args[args.index("-n") + 1]
attr = int(args[args.index("-t") + 1], 16) if "-t" in args else 7
path = os.path.join(d, name)
def log(s):
    open(os.path.join(d, "log"), "a").write(s + "\n")
if "-w" in args or "-a" in args:
    data = sys.stdin.buffer.read()
    if "-a" in args:
        attr |= 0x40
    if attr & 0x20:                 # EFI_VARIABLE_AUTHENTICATION_2: time, then WIN_CERTIFICATE
        length, = struct.unpack_from("<I", data, 16)
        data = data[16 + length:]
    old = open(path, "rb").read() if os.path.exists(path) and attr & 0x40 else b""
    open(path, "wb").write(old + data)
    log("%s %s %x" % ("append" if attr & 0x40 else "write", name, attr))
    if name.endswith("-PK"):
        open(os.path.join(d, "8be4df61-93ca-11d2-aa0d-00e098032b8c-SetupMode"), "wb").write(b"\0")
        open(os.path.join(d, "8be4df61-93ca-11d2-aa0d-00e098032b8c-SecureBoot"), "wb").write(b"\1")
elif os.path.exists(path):
    sys.stdout.buffer.write(open(path, "rb").read())
else:
    sys.exit(1)
EOF
cat > "$T/bin/sysctl" <<'EOF'
#!/bin/sh
[ "$*" = "-n machdep.bootmethod" ] && echo "$SB_FAKE_BOOT"
EOF
cat > "$T/bin/uefisign" <<'EOF'
#!/bin/sh
# uefisign -k KEY -c CERT -o OUT IN
while getopts k:c:o: o; do case $o in k) k=$OPTARG ;; c) c=$OPTARG ;; o) out=$OPTARG ;; *) exit 2 ;; esac; done
shift $((OPTIND - 1))
if command -v sbsign >/dev/null 2>&1; then sbsign --key "$k" --cert "$c" --output "$out" "$1" 2>/dev/null
else cp "$1" "$out"; fi
EOF
chmod +x "$T/bin/"*
PATH="$T/bin:$PATH"
DISTRO_NAME=LunaBSD FREEBSD_RELEASE=15.1-RELEASE
. "$REPO_DIR/lib/secureboot.sh"
G=$SB_GLOBAL_GUID
setvar() { printf "\\$(printf '%03o' "$2")" > "$SB_FAKE_VARS/$G-$1"; }

# --- firmware state ----------------------------------------------------
check "no variables: unsupported" '[ "$(sb_state)" = unsupported ]'
setvar SetupMode 0; setvar SecureBoot 1
check "Secure Boot on" '[ "$(sb_state)" = on ] && [ "$(sb_plan on)" = shim ]'
setvar SecureBoot 0
check "Secure Boot off" '[ "$(sb_state)" = off ] && [ "$(sb_plan off)" = none ]'
setvar SetupMode 1
check "Setup Mode" '[ "$(sb_state)" = setup ] && [ "$(sb_plan setup)" = own ]'
SB_FAKE_BOOT=BIOS
check "BIOS start: unsupported" '[ "$(sb_state)" = unsupported ]'
SB_FAKE_BOOT=UEFI
check "the code is eight digits" 'sb_code | grep -qxE "[0-9]{8}"'

# --- keys and the signed loader --------------------------------------------
K=$T/keys
check "keys made" 'sb_keys "$K" testhost && for k in db KEK PK; do [ -s "$K/$k.key" ] && [ -s "$K/$k.cer" ] || exit 1; done'
check "keys are private (mode 700)" '[ "$(stat -c %a "$K" 2>/dev/null || stat -f %Lp "$K")" = 700 ]'
check "the owner GUID is a GUID" 'grep -qxE "[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[0-9a-f]{4}-[0-9a-f]{12}" "$K/GUID"'
_before=$(cat "$K/db.cer" | sb_sha256 /dev/stdin 2>/dev/null || sha256sum < "$K/db.cer")
sb_keys "$K" testhost
_after=$(cat "$K/db.cer" | sb_sha256 /dev/stdin 2>/dev/null || sha256sum < "$K/db.cer")
check "existing keys are kept" '[ "$_before" = "$_after" ]'
python3 - "$T/loader.efi" <<'EOF'
import struct, sys
data = bytearray(0x800)
data[0:2] = b"MZ"; struct.pack_into("<I", data, 0x3C, 0x80); data[0x80:0x84] = b"PE\0\0"
struct.pack_into("<HHIIIHH", data, 0x84, 0x8664, 1, 0, 0, 0, 0xF0, 0x22)
o = 0x98
struct.pack_into("<HBBIIIII", data, o, 0x20B, 0, 0, 0x200, 0, 0, 0x1000, 0x1000)
struct.pack_into("<II", data, o + 32, 0x1000, 0x200); struct.pack_into("<II", data, o + 56, 0x2000, 0x400)
struct.pack_into("<HH", data, o + 68, 10, 0); struct.pack_into("<I", data, o + 108, 16)
struct.pack_into("<8sIIIIIIHHI", data, o + 0xF0, b".text", 0x10, 0x1000, 0x200, 0x400, 0, 0, 0, 0, 0x60000020)
open(sys.argv[1], "wb").write(data)
EOF
check "loader signed, with SBAT" 'sb_sign_loader "$K" "$T/loader.efi" "$T/signed.efi" && sb_py sections "$T/signed.efi" | grep -q "^.sbat"'
if command -v sbverify >/dev/null 2>&1; then
	check "the signature is this computer's db key" 'sbverify --cert "$K/db.pem" "$T/signed.efi" >/dev/null 2>&1'
fi
check "no unsigned copy left behind" '[ ! -e "$T/signed.efi.unsigned" ]'

# --- files on the EFI partition -----------------------------------------------
mkdir -p "$T/shim"
printf shim > "$T/shim/shimx64.efi"; printf mm > "$T/shim/mmx64.efi"
E=$T/esp
sb_install_chain "$E" "$T/signed.efi" "$K" shim yes "$T/shim"
check "shim chain: EFI/freebsd has shim, MokManager, grubx64 = the signed loader" \
	'cmp -s "$E/EFI/freebsd/shimx64.efi" "$T/shim/shimx64.efi" && cmp -s "$E/EFI/freebsd/mmx64.efi" "$T/shim/mmx64.efi" && cmp -s "$E/EFI/freebsd/grubx64.efi" "$T/signed.efi"'
check "shim chain: loader.efi is the signed loader too (other boot menus)" 'cmp -s "$E/EFI/freebsd/loader.efi" "$T/signed.efi"'
check "shim chain: fallback path starts shim, which starts grubx64.efi" \
	'cmp -s "$E/EFI/BOOT/BOOTX64.EFI" "$T/shim/shimx64.efi" && cmp -s "$E/EFI/BOOT/grubx64.efi" "$T/signed.efi" && [ ! -e "$E/EFI/BOOT/fbx64.efi" ]'
check "shim chain: the key file for 'Enroll key from disk'" 'cmp -s "$E/EFI/freebsd/$SB_KEYFILE" "$K/db.cer"'
E2=$T/esp2
sb_install_chain "$E2" "$T/signed.efi" "$K" shim no "$T/shim"
check "next to other systems: EFI/BOOT is not touched" '[ ! -e "$E2/EFI/BOOT" ]'
E3=$T/esp3
sb_install_chain "$E3" "$T/signed.efi" "$K" own yes "$T/shim"
check "own keys: no shim, the signed loader is the fallback" \
	'[ ! -e "$E3/EFI/freebsd/shimx64.efi" ] && cmp -s "$E3/EFI/BOOT/BOOTX64.EFI" "$T/signed.efi"'

# --- MOK request ------------------------------------------------------------
S=$SB_SHIM_GUID
check "no key in the MOK list yet" '! sb_mok_has "$K/db.cer"'
check "MOK request written" 'sb_mok_request "$K/db.cer" 12345678'
check "MokNew and MokAuth written with NV|BS|RT (as mokutil)" \
	'grep -qx "write $S-MokNew 7" "$SB_FAKE_VARS/log" && grep -qx "write $S-MokAuth 7" "$SB_FAKE_VARS/log"'
python3 - "$REPO_DIR/lib" "$K/db.cer" "$SB_FAKE_VARS/$S-MokNew" "$SB_FAKE_VARS/$S-MokAuth" <<'EOF' && mokok=yes || mokok=no
import sys; sys.path.insert(0, sys.argv[1]); import secureboot as sb
new, auth = sb.mok_request(open(sys.argv[2], "rb").read(), "12345678")
sys.exit(not (open(sys.argv[3], "rb").read() == new and open(sys.argv[4], "rb").read() == auth))
EOF
check "MokNew/MokAuth contents are the request for this key and code" '[ "$mokok" = yes ]'
cp "$SB_FAKE_VARS/$S-MokNew" "$SB_FAKE_VARS/$S-MokListRT"
check "after MokManager: the key is in the MOK list" 'sb_mok_has "$K/db.cer"'

# --- Setup Mode: own keys ---------------------------------------------------
: > "$SB_FAKE_VARS/log"
setvar SetupMode 0; setvar SecureBoot 1
check "enrolling keys is refused outside Setup Mode" '! sb_enroll_own "$K" 2>/dev/null && [ ! -s "$SB_FAKE_VARS/log" ]'
setvar SetupMode 1; setvar SecureBoot 0
MS=$REPO_DIR/files/secureboot/microsoft
# The firmware already trusts Microsoft's UEFI CA 2011 (cleared PK only).
sb_py esl ms "$SB_FAKE_VARS/$SB_DB_GUID-db" "$MS/db/microsoft-uefi-ca-2011.der"
check "keys enrolled" 'REPO_DIR=$REPO_DIR sb_enroll_own "$K"'
check "order: db, then KEK, then PK last" \
	'[ "$(cut -d" " -f2 "$SB_FAKE_VARS/log" | sed "s/.*-//" | paste -sd, -)" = "db,KEK,PK" ]'
check "db and KEK appended (0x67), PK written (0x27)" \
	'grep -qx "append $SB_DB_GUID-db 67" "$SB_FAKE_VARS/log" && grep -qx "append $G-KEK 67" "$SB_FAKE_VARS/log" && grep -qx "write $G-PK 27" "$SB_FAKE_VARS/log"'
sb_py esl-certs "$SB_FAKE_VARS/$SB_DB_GUID-db" > "$T/db.list"
check "db: this computer's key and all 5 Microsoft certificates, none twice" \
	'[ "$(wc -l < "$T/db.list")" -eq 6 ] && [ "$(sort -u "$T/db.list" | wc -l)" -eq 6 ] && grep -qx "$(sb_sha256 "$K/db.cer")" "$T/db.list"'
sb_py esl-certs "$SB_FAKE_VARS/$G-KEK" > "$T/kek.list"
check "KEK: this computer's KEK and Microsoft's two" \
	'[ "$(wc -l < "$T/kek.list")" -eq 3 ] && grep -qx "$(sb_sha256 "$K/KEK.cer")" "$T/kek.list"'
check "PK: this computer's platform key" '[ "$(sb_py esl-certs "$SB_FAKE_VARS/$G-PK")" = "$(sb_sha256 "$K/PK.cer")" ]'
check "Setup Mode ended, Secure Boot on" '[ "$(sb_state)" = on ]'

exit "$fail"
