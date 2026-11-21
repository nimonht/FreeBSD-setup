# lib/secureboot.sh - Secure Boot: the firmware's state, this computer's
# keys, the signed boot chain and enrolling the key (docs/SECUREBOOT.md).
# Sourced by install.sh and files/bin/secureboot. Needs REPO_DIR (for
# lib/secureboot.py) and FreeBSD's own tools: efivar(8) reads and writes
# UEFI variables, uefisign(8) signs, openssl(1) makes keys.
#
# The two ways, as Linux distributions do it:
#   shim  Secure Boot is on with Microsoft's keys (almost every PC). A shim
#         signed by Microsoft (Fedora's) starts FreeBSD's loader.efi, which
#         is signed with this computer's own key. The key is added once to
#         shim's list (MOK): at the next start shim's MokManager asks to
#         confirm it with a code. Arch's shim-signed and Ventoy work so.
#   own   The firmware is in Setup Mode (its keys were cleared, as sbctl and
#         CachyOS's guide ask). This computer's keys become the firmware's,
#         next to Microsoft's (Windows and graphics card firmware need
#         those); no shim. What `sbctl enroll-keys --microsoft` does.
# Either way FreeBSD's loader does not check the kernel (FreeBSD's default
# build has no such check), so this keeps Secure Boot on rather than adding
# a verified boot chain.

SB_GLOBAL_GUID=8be4df61-93ca-11d2-aa0d-00e098032b8c
SB_DB_GUID=d719b2cb-3d3a-4596-a3bc-dad00e67656f
SB_SHIM_GUID=605dab50-e046-4300-abb6-3dd810dd8b23
SB_KEYS=/var/db/lunabsd-secureboot
SB_SHARE=/usr/local/share/lunabsd/secureboot
# Fedora's shim 16.1-7 (the build Arch's shim-signed package uses): signed
# by both Microsoft UEFI CA 2011 and Microsoft UEFI CA 2023, so it starts
# on older PCs and on new ones that trust only the 2023 key. Checked by
# hash before use.
SB_SHIM_RPM_URL=https://kojipkgs.fedoraproject.org/packages/shim/16.1/7/x86_64/shim-x64-16.1-7.x86_64.rpm
SB_SHIM_RPM_SHA256=0a119f3488e5da27ca55c1864ee8e131afa5ecf27689385ba09b805eb00dd608
SB_SHIM_SHA256=351e131d3c4a636704e9cae7d1296baf8a05beca9922cfebbfa48933c9bf1ad3
SB_MM_SHA256=ed4442fa88cccba3a9e6a32d21a8f4c56bf5aab184f1fb9aadde8d3a9d04dc27
SB_KEYFILE=ENROLL_THIS_KEY_IN_MOKMANAGER.cer

sb_sha256() {
	if command -v sha256 >/dev/null 2>&1; then sha256 -q "$1"; else sha256sum "$1" | cut -d' ' -f1; fi
}

sb_py() {
	_sbp=$(command -v python3 2>/dev/null || ls /usr/local/bin/python3.* 2>/dev/null | head -1)
	[ -n "$_sbp" ] || { echo "secure boot: python3 is missing" >&2; return 1; }
	"$_sbp" "$REPO_DIR/lib/secureboot.py" "$@"
}

# sb_var NAME   a UEFI variable's value on stdout (nothing if it is absent)
sb_var() { efivar -N -b -p -q -n "$1" 2>/dev/null || true; }
sb_byte() { sb_var "$1" | od -An -tu1 -N1 | tr -d ' \n'; }

# sb_state   unsupported (BIOS, or no UEFI variables), setup (Setup Mode: no
# platform key, keys can be enrolled), on (Secure Boot enforced), off
sb_state() {
	[ "$(sysctl -n machdep.bootmethod 2>/dev/null)" = UEFI ] || { echo unsupported; return 0; }
	command -v efivar >/dev/null 2>&1 || { echo unsupported; return 0; }
	_sbm=$(sb_byte "$SB_GLOBAL_GUID-SetupMode")
	_sbo=$(sb_byte "$SB_GLOBAL_GUID-SecureBoot")
	if [ "$_sbm" = 1 ]; then echo setup
	elif [ "$_sbo" = 1 ]; then echo on
	elif [ -n "$_sbm$_sbo" ]; then echo off
	else echo unsupported
	fi
}

# sb_plan STATE   what an installation does: shim, own or none
sb_plan() {
	case "$1" in
	on) echo shim ;;
	setup) echo own ;;
	*) echo none ;;
	esac
}

# sb_shim_ok DIR   DIR holds the checked shimx64.efi and mmx64.efi
sb_shim_ok() {
	[ -f "$1/shimx64.efi" ] && [ -f "$1/mmx64.efi" ] &&
		[ "$(sb_sha256 "$1/shimx64.efi")" = "$SB_SHIM_SHA256" ] &&
		[ "$(sb_sha256 "$1/mmx64.efi")" = "$SB_MM_SHA256" ]
}

# sb_fetch_shim DIR   download Fedora's signed shim into DIR (checked)
sb_fetch_shim() {
	sb_shim_ok "$1" && return 0
	_sbt=$(mktemp -d)
	if command -v fetch >/dev/null 2>&1; then
		fetch -q -o "$_sbt/shim.rpm" "$SB_SHIM_RPM_URL"
	else
		curl -fsSL -o "$_sbt/shim.rpm" "$SB_SHIM_RPM_URL"
	fi || { rm -rf "$_sbt"; echo "secure boot: could not download the shim" >&2; return 1; }
	if [ "$(sb_sha256 "$_sbt/shim.rpm")" != "$SB_SHIM_RPM_SHA256" ]; then
		rm -rf "$_sbt"; echo "secure boot: the downloaded shim is not the expected file" >&2; return 1
	fi
	mkdir -p "$_sbt/x" "$1"
	(cd "$_sbt/x" && bsdtar -xf ../shim.rpm) || { rm -rf "$_sbt"; return 1; }
	cp "$_sbt"/x/usr/lib/efi/shim/*/EFI/fedora/shimx64.efi "$_sbt"/x/usr/lib/efi/shim/*/EFI/fedora/mmx64.efi "$1/"
	rm -rf "$_sbt"
	sb_shim_ok "$1" || { echo "secure boot: the shim files are not the expected ones" >&2; return 1; }
}

# sb_code   eight random digits: what the user types in MokManager (digits
# are where they are on every keyboard layout, which the firmware ignores)
sb_code() {
	od -An -N8 -tu1 /dev/urandom | awk '{ for (i = 1; i <= NF; i++) printf "%d", $i % 10 } END { print "" }'
}

# sb_keys DIR NAME   this computer's keys: db signs the loader; KEK and PK
# are only enrolled in Setup Mode. Kept, never replaced, once made.
sb_keys() {
	mkdir -p "$1" && chmod 700 "$1" || return 1
	for _sbk in db KEK PK; do
		[ -f "$1/$_sbk.key" ] && [ -f "$1/$_sbk.cer" ] && continue
		(umask 077 && openssl req -new -x509 -newkey rsa:2048 -nodes -sha256 -days 10950 \
			-subj "/O=$DISTRO_NAME/CN=$DISTRO_NAME $_sbk key ($2)" \
			-keyout "$1/$_sbk.key" -out "$1/$_sbk.pem") >/dev/null 2>&1 || return 1
		openssl x509 -in "$1/$_sbk.pem" -outform DER -out "$1/$_sbk.cer" || return 1
	done
	[ -f "$1/GUID" ] || sb_py guid > "$1/GUID"
	printf '# Written by FreeBSD-setup\nThis computer'"'"'s Secure Boot keys (docs/SECUREBOOT.md).\nKeep them secret: what they sign, this computer starts.\n' > "$1/README"
}

# sb_sign_loader KEYS IN OUT   FreeBSD's loader with SBAT data (shim needs
# it), signed with this computer's db key
sb_sign_loader() {
	_sbv=$(printf '%s' "${FREEBSD_RELEASE:-$(uname -r)}" | sed 's/-.*//')
	rm -f "$3.unsigned" "$3"
	sb_py sbat "$2" "$3.unsigned" "$_sbv" &&
		uefisign -k "$1/db.key" -c "$1/db.pem" -o "$3" "$3.unsigned" >/dev/null
	_sbr=$?
	rm -f "$3.unsigned"
	return "$_sbr"
}

# sb_install_chain ESP SIGNED-LOADER KEYS MODE FALLBACK SHIM-DIR   put the
# boot files on the EFI partition mounted at ESP. MODE shim:
# EFI/freebsd/shimx64.efi starts grubx64.efi next to it (the name shim
# looks for: our signed loader); FALLBACK yes also makes shim the firmware's
# fallback path EFI/BOOT/BOOTX64.EFI (whole-disk installs; without fbx64.efi
# there, shim starts grubx64.efi directly). MODE own: the signed loader
# alone. loader.efi is signed too: other boot menus (GRUB, systemd-boot,
# rEFInd) start that one.
sb_install_chain() {
	_sbe=$1/EFI/freebsd
	mkdir -p "$_sbe"
	cp "$2" "$_sbe/loader.efi"
	cp "$3/db.cer" "$_sbe/$SB_KEYFILE"
	if [ "$4" = shim ]; then
		cp "$6/shimx64.efi" "$6/mmx64.efi" "$_sbe/"
		cp "$2" "$_sbe/grubx64.efi"
	fi
	[ "$5" = yes ] || return 0
	mkdir -p "$1/EFI/BOOT"
	if [ "$4" = shim ]; then
		cp "$6/shimx64.efi" "$1/EFI/BOOT/BOOTX64.EFI"
		cp "$6/mmx64.efi" "$1/EFI/BOOT/mmx64.efi"
		cp "$2" "$1/EFI/BOOT/grubx64.efi"
	else
		cp "$2" "$1/EFI/BOOT/BOOTX64.EFI"
	fi
}

# sb_mok_has CERT   shim's MOK list already holds this certificate
sb_mok_has() {
	_sbt=$(mktemp)
	sb_var "$SB_SHIM_GUID-MokListRT" > "$_sbt"
	_sbh=$(sb_sha256 "$1")
	sb_py esl-certs "$_sbt" 2>/dev/null | grep -qx "$_sbh"
	_sbr=$?
	rm -f "$_sbt"
	return "$_sbr"
}

# sb_mok_request CERT CODE   ask shim to add CERT to its list at the next
# start (what `mokutil --import` does); typing CODE in MokManager confirms
sb_mok_request() {
	_sbt=$(mktemp -d)
	sb_py mok-request "$1" "$2" "$_sbt" &&
		efivar -w -t 7 -n "$SB_SHIM_GUID-MokNew" < "$_sbt/MokNew" &&
		efivar -w -t 7 -n "$SB_SHIM_GUID-MokAuth" < "$_sbt/MokAuth"
	_sbr=$?
	rm -rf "$_sbt"
	return "$_sbr"
}

# sb_enroll_own KEYS   Setup Mode only: add this computer's db and KEK keys
# and Microsoft's certificates (those missing) to db and KEK, then set the
# platform key, which ends Setup Mode. Existing entries are kept (appended
# to, never replaced), so firmware-specific keys stay.
sb_enroll_own() {
	[ "$(sb_state)" = setup ] || { echo "secure boot: the firmware is not in Setup Mode" >&2; return 1; }
	_sbt=$(mktemp -d) _sbms=$REPO_DIR/files/secureboot/microsoft _sbg=$(cat "$1/GUID")
	for _sbv in db KEK; do
		if [ "$_sbv" = db ]; then _sbguid=$SB_DB_GUID; else _sbguid=$SB_GLOBAL_GUID; fi
		sb_var "$_sbguid-$_sbv" > "$_sbt/$_sbv.old"
		sb_py esl-certs "$_sbt/$_sbv.old" > "$_sbt/$_sbv.have" 2>/dev/null || : > "$_sbt/$_sbv.have"
		_sbmine=""
		grep -qx "$(sb_sha256 "$1/$_sbv.cer")" "$_sbt/$_sbv.have" || _sbmine="$1/$_sbv.cer"
		_sbmissing=""
		for _sbc in "$_sbms/$_sbv"/*.der; do
			grep -qx "$(sb_sha256 "$_sbc")" "$_sbt/$_sbv.have" || _sbmissing="$_sbmissing $_sbc"
		done
		: > "$_sbt/$_sbv.esl"
		[ -n "$_sbmine" ] && { sb_py esl "$_sbg" "$_sbt/mine.esl" "$_sbmine" && cat "$_sbt/mine.esl" >> "$_sbt/$_sbv.esl"; }
		# shellcheck disable=SC2086
		[ -n "$_sbmissing" ] && { sb_py esl ms "$_sbt/ms.esl" $_sbmissing && cat "$_sbt/ms.esl" >> "$_sbt/$_sbv.esl"; }
		[ -s "$_sbt/$_sbv.esl" ] || continue
		# 27: non-volatile, boot and run time, time-based authenticated
		# write; -a adds the append flag (the signed data includes it).
		sb_py auth "$_sbv" "$_sbt/$_sbv.esl" "$_sbt/$_sbv.auth" --cert "$1/PK.pem" --key "$1/PK.key" --append >/dev/null &&
			efivar -a -t 27 -n "$_sbguid-$_sbv" < "$_sbt/$_sbv.auth" ||
			{ rm -rf "$_sbt"; echo "secure boot: the firmware did not accept the new $_sbv entries" >&2; return 1; }
	done
	sb_py esl "$_sbg" "$_sbt/PK.esl" "$1/PK.cer" &&
		sb_py auth PK "$_sbt/PK.esl" "$_sbt/PK.auth" --cert "$1/PK.pem" --key "$1/PK.key" >/dev/null &&
		efivar -w -t 27 -n "$SB_GLOBAL_GUID-PK" < "$_sbt/PK.auth" ||
		{ rm -rf "$_sbt"; echo "secure boot: the firmware did not accept the platform key" >&2; return 1; }
	rm -rf "$_sbt"
}
