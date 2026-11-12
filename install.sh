#!/bin/sh
#
# install.sh - guided FreeBSD installer for desktops and laptops.
#
# Boot the official FreeBSD 15 USB stick, choose "Live System", log in as
# root, connect to the internet (bsdinstall netconfig), then run this script
# (the one-line bootstrap does all of that for you; see README). It asks a
# few questions, then installs FreeBSD on ZFS and sets up the desktop in one
# go:
#   - erase a whole disk, or install next to Windows/Linux in free space
#   - user account, language, keyboard, time zone, Wi-Fi carried over
#   - KDE Plasma or Hyprland + Caelestia, drivers for the detected hardware
#   - boot menu: FreeBSD added next to your other systems
#
# Nothing is written to any disk before the final "Install" confirmation.
#
# Options:
#   --config FILE   answers for unattended installs (see tests/*.conf)
#   --yes           do not ask anything (needs --config)
#   --dry-run       ask everything, show the plan, write nothing
#   --base-only     install FreeBSD only; run the desktop setup later
#   --force         allow running from an installed system (testing)

set -eu

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
FBS_LIB="$REPO_DIR/lib"
. "$FBS_LIB/common.sh"
. "$FBS_LIB/hw.sh"
. "$FBS_LIB/ui.sh"
. "$FBS_LIB/wizard.sh"
. "$FBS_LIB/defaults.conf"

LOG=/tmp/freebsd-install.log
: > "$LOG"
UI_TITLE="FreeBSD-setup installer"
MNT=/mnt
CONFIG_FILE="" ASSUME_YES=no DRY_RUN=no BASE_ONLY=no FORCE=no
while [ $# -gt 0 ]; do
	case "$1" in
	--config) CONFIG_FILE=${2:?}; shift ;;
	--yes|-y) ASSUME_YES=yes ;;
	--dry-run) DRY_RUN=yes ;;
	--base-only) BASE_ONLY=yes ;;
	--force) FORCE=yes ;;
	-h|--help) sed -n '3,27p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
	*) die "unknown option $1" ;;
	esac
	shift
done

# Installer answers (all can come from --config).
INSTALL_DISK="" INSTALL_MODE="" ZFS_SIZE_GB="" SWAP_SIZE="auto" POOL=zroot
HOSTNAME_NEW="" USERNAME="" USER_FULLNAME="" USER_PASSWORD="" ROOT_PASSWORD=""
TIMEZONE="" RTC_LOCAL="auto" BOOT_DEFAULT="keep" BOOT_INTEGRATION="yes"
WIZ_LANG="" DESKTOP_LANGUAGE=""
MIN_GB=30
[ -n "$CONFIG_FILE" ] && . "$CONFIG_FILE"
TARGET_USER=$USERNAME

# ----------------------------------------------------------------- checks ---
[ "$(uname -s)" = FreeBSD ] || die "run this from the FreeBSD installer's Live System"
[ "$(id -u)" -eq 0 ] || die "must run as root"
hw_detect
case "$HW_OSREL" in 1[5-9].*) ;; *) die "this installer needs FreeBSD 15 or newer media (this is $HW_OSREL)" ;; esac
[ "$HW_ARCH" = amd64 ] || die "this installer supports amd64 machines"
_rootfs=$(mount -p | awk '$2 == "/" { print $3 " ," $4 ","; exit }')
case "$_rootfs" in
cd9660*|*,ro,*) LIVE_MEDIA=yes ;;
*) LIVE_MEDIA=no ;;
esac
[ "$LIVE_MEDIA" = yes ] || [ "$FORCE" = yes ] ||
	die "this is meant to run from the FreeBSD USB stick's Live System, not from an installed FreeBSD. To set up the desktop on this system instead, run: setup.sh"
kldload -n zfs 2>/dev/null || true
ui_init
if [ "$UI_MODE" = auto ] && [ -z "$CONFIG_FILE" ]; then
	die "unattended mode needs --config FILE with the answers"
fi

# Extra CA for networks with a TLS-intercepting proxy: SSL_CA_CERT_FILE
# replaces the whole trust store, so merge it with the system's own CAs.
EXTRA_CA=""
if [ -n "${SSL_CA_CERT_FILE:-}" ] && [ -f "$SSL_CA_CERT_FILE" ]; then
	EXTRA_CA=$SSL_CA_CERT_FILE
	cat /etc/ssl/cert.pem "$EXTRA_CA" > /tmp/fbs-ca-bundle.pem 2>/dev/null &&
		export SSL_CA_CERT_FILE=/tmp/fbs-ca-bundle.pem
fi

# Where the base system comes from: this FreeBSD version, release sets.
REL=$(uname -r | sed 's/-p[0-9]*$//')
DIST_URL="https://download.freebsd.org/releases/amd64/$REL"

# ------------------------------------------------------------ disk helpers ---

# Disks that can be installed on: everything except the install media.
disk_candidates() {
	_media=""
	_dev=$(mount -p | awk '$2 == "/" { print $1; exit }')
	case "$_dev" in
	/dev/iso9660/*|/dev/ufs/*|/dev/gpt/*|/dev/label/*)
		_lab=${_dev#/dev/}
		_media=$(glabel status -s 2>/dev/null | awk -v l="$_lab" '$1 == l { print $3; exit }')
		_media=$(echo "$_media" | sed -E 's/(p|s)[0-9]+[a-z]?$//') ;;
	/dev/*) _media=$(echo "${_dev#/dev/}" | sed -E 's/(p|s)[0-9]+[a-z]?$//') ;;
	esac
	# Disks holding mounted file systems, swap or imported pools are in use.
	_busy=$( { mount -p | awk '{ print $1 }'; swapctl -l 2>/dev/null | awk 'NR > 1 { print $1 }'
		zpool status -P 2>/dev/null | awk '$1 ~ /^\/dev\// { print $1 }'; } |
		sed -E 's#^/dev/##; s#^(gpt|gptid|label|ufs|iso9660)/.*##; s/(p|s)[0-9]+[a-z]?$//' | sort -u)
	for _d in $(sysctl -n kern.disks); do
		case "$_d" in cd*|md*) continue ;; esac
		[ "$_d" = "$_media" ] && continue
		echo "$_busy" | grep -qx "$_d" && continue
		echo "$_d"
	done
}

disk_bytes() { diskinfo "$1" | awk '{ print $3 }'; }
disk_secsize() { diskinfo "$1" | awk '{ print $2 }'; }
disk_descr() {
	_ds=$(geom disk list "$1" 2>/dev/null | awk -F': ' '/descr:/ { print $2; exit }')
	echo "${_ds:-disk}"
}
disk_scheme() { gpart show "$1" 2>/dev/null | awk 'NR == 1 { print $5 }'; }
gb() { echo $(( $1 / 1073741824 )); }

# What is on the disk now, in words.
disk_contents() {
	gpart show -p "$1" 2>/dev/null | awk '
	NR > 1 && $4 != "-" {
		t = $4
		if (t == "efi") e++
		else if (t == "ms-basic-data") w++
		else if (t == "ms-reserved" || t == "ms-recovery") r++
		else if (t ~ /^linux/) l++
		else if (t ~ /^freebsd/) f++
		else if (t ~ /^apple/) a++
		else o++
	}
	END {
		s = ""
		if (w) s = s "Windows/data (" w ") "
		if (l) s = s "Linux (" l ") "
		if (f) s = s "FreeBSD (" f ") "
		if (a) s = s "macOS (" a ") "
		if (e) s = s "EFI "
		if (o) s = s "other (" o ") "
		print (s == "" ? "empty" : s)
	}'
}

# Largest free region on a GPT disk: "start-sector sectors"
disk_free() {
	gpart show "$1" 2>/dev/null | awk '$3 == "-" && $4 == "free" && $2 > max { max = $2; start = $1 } END { print start + 0, max + 0 }'
}

esp_of() { gpart show -p "$1" 2>/dev/null | awk '$4 == "efi" { print $3; exit }'; }

# ---------------------------------------------------------------- questions ---

ask_network() {
	while ! fetch -q -T 15 -o /dev/null "$DIST_URL/MANIFEST" 2>/dev/null; do
		[ "$UI_MODE" = auto ] && die "no internet connection (could not reach download.freebsd.org)"
		_a=$(ui_menu "No internet" "The installer downloads FreeBSD and your desktop, so it needs the internet.

Wired: plug in the cable and choose Retry.
Wi-Fi: choose 'Connect' to pick a network." connect \
			connect "Connect to a network (Wi-Fi or wired)" \
			retry "Retry" \
			quit "Quit the installer") || exit 1
		case "$_a" in
		connect) BSDINSTALL_TMPETC=/tmp/bsdinstall_etc bsdinstall netconfig < /dev/tty > /dev/tty 2>&1 || true ;;
		quit) exit 1 ;;
		esac
	done
}

ask_disk() {
	_args=""
	for _d in $(disk_candidates); do
		_args="$_args$_d$NL$(gb "$(disk_bytes "$_d")") GB  $(disk_descr "$_d")  [$(disk_contents "$_d")]$NL"
	done
	[ -n "$_args" ] || die "no disk found to install on"
	_def=${INSTALL_DISK:-$(disk_candidates | head -1)}
	_old=$IFS; IFS=$NL
	# shellcheck disable=SC2086
	INSTALL_DISK=$(ui_menu "Disk" "Install FreeBSD on which disk?" "$_def" $_args) || exit 1
	IFS=$_old
	[ -c "/dev/$INSTALL_DISK" ] || die "/dev/$INSTALL_DISK does not exist"
}

ask_mode() {
	SECSIZE=$(disk_secsize "$INSTALL_DISK")
	_scheme=$(disk_scheme "$INSTALL_DISK")
	_contents=$(disk_contents "$INSTALL_DISK")
	# shellcheck disable=SC2046
	set -- $(disk_free "$INSTALL_DISK"); FREE_START=$1 FREE_SECTORS=$2
	FREE_GB=$(( FREE_SECTORS * SECSIZE / 1073741824 ))
	HAS_WINDOWS=no
	case "$_contents" in *Windows*) HAS_WINDOWS=yes ;; esac

	_alongside_ok=yes _why=""
	if [ "$_contents" = empty ]; then _alongside_ok=no _why="the disk is empty"
	elif [ "$HW_BOOT" != UEFI ]; then _alongside_ok=no _why="this computer started the installer in legacy BIOS mode; installing next to other systems needs UEFI mode"
	elif [ "$_scheme" != GPT ]; then _alongside_ok=no _why="the disk uses the old MBR partition table; only GPT disks are supported for side-by-side installs"
	elif [ -z "$(esp_of "$INSTALL_DISK")" ]; then _alongside_ok=no _why="there is no EFI system partition on this disk"
	elif [ "$FREE_GB" -lt "$MIN_GB" ]; then _alongside_ok=no _why="only $FREE_GB GB is unallocated; at least $MIN_GB GB is needed (shrink a partition in Windows Disk Management or with GParted first)"
	fi

	_def=${INSTALL_MODE:-}
	[ -z "$_def" ] && { [ "$_alongside_ok" = yes ] && _def=alongside || _def=erase; }
	if [ "$_alongside_ok" = yes ]; then
		INSTALL_MODE=$(ui_menu "Installation type" "$INSTALL_DISK currently holds: $_contents" "$_def" \
			alongside "Install next to the existing systems ($FREE_GB GB free space)" \
			erase "Erase the whole disk and install FreeBSD") || exit 1
	else
		[ "$INSTALL_MODE" = alongside ] && die "cannot install next to the existing systems: $_why"
		INSTALL_MODE=erase
		[ "$_contents" = empty ] || ui_msg "Installation type" "FreeBSD cannot be installed next to the existing systems on $INSTALL_DISK: $_why.

The only option on this disk is to ERASE it completely."
	fi
	if [ "$INSTALL_MODE" = alongside ] && [ "$UI_MODE" != auto ]; then
		ZFS_SIZE_GB=$(ui_input "Size" "How many GB of the $FREE_GB GB free space should FreeBSD use? (swap is taken from it)" "${ZFS_SIZE_GB:-$FREE_GB}") || exit 1
	fi
}

# A login name: valid characters, and not one of the system's own accounts.
valid_user() {
	echo "$1" | grep -Eq '^[a-z_][a-z0-9_-]{0,15}$' || return 1
	! awk -F: -v u="$1" '$1 == u && ($3 < 1000 || $3 >= 65530) { f = 1 } END { exit !f }' /etc/passwd
}

ask_account() {
	[ "$UI_MODE" = auto ] && { [ -n "$USERNAME" ] && [ -n "$USER_PASSWORD" ] || die "the config file must set USERNAME and USER_PASSWORD"; }
	USER_FULLNAME=$(ui_input "Your account" "Your full name:" "$USER_FULLNAME") || exit 1
	_sug=$(echo "${USER_FULLNAME%% *}" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9_-')
	while :; do
		USERNAME=$(ui_input "Your account" "Login name (lower case, no spaces):" "${USERNAME:-$_sug}") || exit 1
		valid_user "$USERNAME" && break
		[ "$UI_MODE" = auto ] && die "USERNAME '$USERNAME' cannot be used (invalid or a system account)"
		ui_msg "Your account" "'$USERNAME' cannot be used: use lower-case letters, digits, - or _, starting with a letter, and not a system name such as root or operator."
	done
	[ "$UI_MODE" = auto ] || while :; do
		_p1=$(ui_password "Your account" "Password for $USERNAME:") || exit 1
		_p2=$(ui_password "Your account" "Type the password again:") || exit 1
		[ "$_p1" = "$_p2" ] && [ -n "$_p1" ] && { USER_PASSWORD=$_p1; break; }
		ui_msg "Your account" "The passwords are empty or do not match. Try again."
	done
	if [ "$UI_MODE" != auto ] && ! ui_yesno "Administrator" "Use the same password for the administrator account (root)?

You type it when installing software or changing system settings." yes; then
		while :; do
			_p1=$(ui_password "Administrator" "Password for root:") || exit 1
			_p2=$(ui_password "Administrator" "Type it again:") || exit 1
			[ "$_p1" = "$_p2" ] && [ -n "$_p1" ] && { ROOT_PASSWORD=$_p1; break; }
			ui_msg "Administrator" "The passwords are empty or do not match. Try again."
		done
	fi
	[ -n "$ROOT_PASSWORD" ] || ROOT_PASSWORD=$USER_PASSWORD
	TARGET_USER=$USERNAME
	_hn=${HOSTNAME_NEW:-freebsd}
	HOSTNAME_NEW=$(ui_input "Computer name" "A name for this computer on the network:" "$_hn") || exit 1
}

ask_timezone() {
	_tab=/usr/share/zoneinfo/zone1970.tab
	_cur=${TIMEZONE:-}
	_region_def=${_cur%%/*}; [ -n "$_region_def" ] || _region_def=Europe
	_regions=$(awk '$1 !~ /^#/ { split($3, p, "/"); print p[1] }' "$_tab" | sort -u)
	_args=""
	for _r in $_regions; do _args="$_args$_r$NL$_r$NL"; done
	_args="${_args}UTC${NL}Coordinated Universal Time$NL"
	_old=$IFS; IFS=$NL
	# shellcheck disable=SC2086
	_r=$(ui_menu "Time zone" "Region:" "$_region_def" $_args) || { IFS=$_old; exit 1; }
	IFS=$_old
	if [ "$_r" = UTC ]; then TIMEZONE=UTC; return; fi
	_args=$(awk -F'\t' -v r="$_r/" '$1 !~ /^#/ && index($3, r) == 1 { print $3 "\t" $4 }' "$_tab" | sort | awk -F'\t' -v r="$_r/" '{
		city = substr($1, length(r) + 1); gsub(/_/, " ", city)
		printf "%s\n%s%s\n", $1, city, ($2 != "" ? " - " $2 : "") }')
	_old=$IFS; IFS=$NL
	# shellcheck disable=SC2086
	TIMEZONE=$(ui_menu "Time zone" "City or area:" "${_cur:-}" $_args) || { IFS=$_old; exit 1; }
	IFS=$_old
}

ask_region() {
	wiz_language || exit 1
	wiz_keyboard || exit 1
	if [ "$UI_MODE" != auto ] || [ -z "$TIMEZONE" ]; then ask_timezone; fi
	[ -f "/usr/share/zoneinfo/$TIMEZONE" ] || die "unknown time zone '$TIMEZONE'"
	if [ "$RTC_LOCAL" = auto ]; then
		RTC_LOCAL=no
		[ "${HAS_WINDOWS:-no}" = yes ] && RTC_LOCAL=yes
	fi
	if [ "$UI_MODE" != auto ]; then
		_d=no; [ "$RTC_LOCAL" = yes ] && _d=yes
		if ui_yesno "Clock" "Is the computer's hardware clock set to local time?

Answer Yes when Windows is installed on this computer (Windows keeps the clock in local time), No otherwise." $_d
		then RTC_LOCAL=yes; else RTC_LOCAL=no; fi
	fi
}

# ------------------------------------------------------------- boot managers ---

ESP_TMP=/tmp/fbs-esp
esp_mount_ro() { mkdir -p "$ESP_TMP"; mount -t msdosfs -o ro "/dev/$1" "$ESP_TMP" 2>/dev/null; }
esp_umount()   { umount "$ESP_TMP" 2>/dev/null || true; }

# Detect boot managers on the ESP: sets LIMINE_CONF, HAS_SDBOOT, HAS_REFIND,
# HAS_GRUB, HAS_WINBOOT and CHAIN_PATH/CHAIN_NAME (the current default loader)
detect_boot() {
	LIMINE_CONF="" HAS_SDBOOT=no HAS_REFIND=no HAS_GRUB=no HAS_WINBOOT=no CHAIN_PATH="" CHAIN_NAME=""
	ESP_DEV=$(esp_of "$INSTALL_DISK")
	[ -n "$ESP_DEV" ] && esp_mount_ro "$ESP_DEV" || return 0
	for _c in limine.conf limine/limine.conf boot/limine.conf boot/limine/limine.conf EFI/BOOT/limine.conf EFI/limine/limine.conf EFI/Limine/limine.conf; do
		[ -f "$ESP_TMP/$_c" ] && { LIMINE_CONF=$_c; break; }
	done
	[ -f "$ESP_TMP/loader/loader.conf" ] && [ -d "$ESP_TMP/EFI/systemd" ] && HAS_SDBOOT=yes
	[ -d "$ESP_TMP/EFI/refind" ] && HAS_REFIND=yes
	ls "$ESP_TMP"/EFI/*/grubx64.efi >/dev/null 2>&1 && HAS_GRUB=yes
	[ -f "$ESP_TMP/EFI/Microsoft/Boot/bootmgfw.efi" ] && HAS_WINBOOT=yes
	esp_umount

	# The loader the firmware starts today: offer it in FreeBSD's menu too.
	if [ "$HW_BOOT" = UEFI ]; then
		_first=$(efibootmgr 2>/dev/null | awk -F': *' '/^BootOrder/ { split($2, a, ","); gsub(/ /, "", a[1]); print a[1] }')
		_line=$(efibootmgr -v 2>/dev/null | grep -E "^[ +]*Boot${_first}\*?" | head -1)
		CHAIN_PATH=$(echo "$_line" | sed -n 's/.*File(\([^)]*\)).*/\1/p' | tr '\\' '/')
		CHAIN_NAME=$(echo "$_line" | sed -E 's/^[ +]*Boot[0-9A-Fa-f]{4}\*? //; s/ (HD|PciRoot|Fv)\(.*//')
		case "$CHAIN_PATH" in /EFI/*|/efi/*) ;; *) CHAIN_PATH="" ;; esac
		case "$CHAIN_PATH" in */freebsd/*) CHAIN_PATH="" ;; esac
	fi
	if [ -z "$CHAIN_PATH" ] && [ "$HAS_WINBOOT" = yes ]; then
		CHAIN_PATH=/EFI/Microsoft/Boot/bootmgfw.efi CHAIN_NAME="Windows Boot Manager"
	fi
}

ask_boot() {
	[ "$INSTALL_MODE" = alongside ] || return 0
	detect_boot
	_where=""
	[ -n "$LIMINE_CONF" ] && _where="$_where
  - an entry in your Limine menu ($LIMINE_CONF)"
	[ "$HAS_SDBOOT" = yes ] && _where="$_where
  - an entry in your systemd-boot menu"
	[ "$HAS_REFIND" = yes ] && _where="$_where
  - rEFInd finds FreeBSD by itself"
	[ "$HAS_GRUB" = yes ] && _where="$_where
  - GRUB: add FreeBSD from Linux later (see docs/DUAL-BOOT.md)"
	_where="$_where
  - 'FreeBSD' in the firmware boot menu"
	[ -n "$CHAIN_PATH" ] && _where="$_where
  - FreeBSD's own boot menu gets 'Start ${CHAIN_NAME:-the other system}' (key L)"
	BOOT_SUMMARY=$_where
	[ "$UI_MODE" = auto ] && return 0
	BOOT_DEFAULT=$(ui_menu "Starting the computer" "FreeBSD will be reachable through:$_where

Which system should start when you turn the computer on?" keep \
		keep "Keep the current default (${CHAIN_NAME:-unchanged})" \
		freebsd "FreeBSD's menu (other systems with key L)") || exit 1
}

ask_desktop() {
	wiz_desktop || exit 1
	if [ "$DESKTOP" != none ]; then wiz_input_methods || exit 1; fi
	wiz_extras || exit 1
}

# ---------------------------------------------------------------- the plan ---

plan_sizes() {
	SECSIZE=$(disk_secsize "$INSTALL_DISK")
	ALIGN=$(( 1048576 / SECSIZE ))
	if [ "$SWAP_SIZE" = auto ]; then
		_g=$(( (HW_RAM_MB + 1023) / 1024 )); [ "$_g" -lt 2 ] && _g=2; [ "$_g" -gt 8 ] && _g=8
		SWAP_SIZE="${_g}g"
	fi
	case "$SWAP_SIZE" in 0) SWAP_SECTORS=0 ;; *[gG]) SWAP_SECTORS=$(( ${SWAP_SIZE%?} * 1073741824 / SECSIZE )) ;;
	*) die "SWAP_SIZE must be like 8g or 0" ;; esac
	if [ "$INSTALL_MODE" = alongside ]; then
		START=$(( (FREE_START + ALIGN - 1) / ALIGN * ALIGN ))
		USABLE=$(( (FREE_START + FREE_SECTORS - START) / ALIGN * ALIGN ))
		if [ -n "$ZFS_SIZE_GB" ] && [ "$ZFS_SIZE_GB" -lt "$FREE_GB" ] 2>/dev/null; then
			USABLE=$(( ZFS_SIZE_GB * 1073741824 / SECSIZE / ALIGN * ALIGN ))
		fi
		ZFS_SECTORS=$(( USABLE - SWAP_SECTORS ))
	else
		USABLE=$(( $(disk_bytes "$INSTALL_DISK") / SECSIZE - 2 * ALIGN - 300 * 1048576 / SECSIZE ))
		ZFS_SECTORS=$(( USABLE - SWAP_SECTORS ))
	fi
	ZFS_GB=$(( ZFS_SECTORS * SECSIZE / 1073741824 ))
	[ "$ZFS_GB" -ge "$MIN_GB" ] || die "FreeBSD would get only $ZFS_GB GB; at least $MIN_GB GB is needed"
	# Pool name must not clash with a pool already on this machine.
	_n=0 _p=$POOL
	while zpool list -H -o name 2>/dev/null | grep -qx "$_p" || zpool import 2>/dev/null | grep -qE "^ +pool: $_p\$"; do
		_n=$((_n + 1)); _p="${POOL}${_n}"
	done
	POOL=$_p
}

plan_text() {
	cat <<EOF
Disk:        $INSTALL_DISK ($(disk_descr "$INSTALL_DISK"), $(gb "$(disk_bytes "$INSTALL_DISK")") GB)
EOF
	if [ "$INSTALL_MODE" = erase ]; then
		echo "Action:      ERASE THE WHOLE DISK - everything on it is deleted"
	else
		echo "Action:      add FreeBSD in the free space; existing partitions are not touched"
	fi
	cat <<EOF
FreeBSD:     $ZFS_GB GB ZFS (pool "$POOL") + $(( SWAP_SECTORS * SECSIZE / 1073741824 )) GB swap
User:        $USERNAME${USER_FULLNAME:+ ($USER_FULLNAME)}, computer name $HOSTNAME_NEW
Language:    ${WIZ_LANG:-en}, keyboard ${KEYBOARD_LAYOUT:-us}, time zone $TIMEZONE$( [ "$RTC_LOCAL" = yes ] && echo ", clock in local time")
EOF
	[ "$BASE_ONLY" = yes ] && { echo "Desktop:     not now (--base-only)"; return; }
	wiz_summary_text
	[ "$INSTALL_MODE" = alongside ] && printf 'Boot:        %s%s\n' "$( [ "$BOOT_DEFAULT" = freebsd ] && echo "FreeBSD starts first" || echo "current default kept")" "${BOOT_SUMMARY:-}"
	return 0
}

confirm() {
	_txt="$(plan_text)

Downloads several GB; takes 30-90 minutes depending on the internet connection."
	if [ "$DRY_RUN" = yes ]; then ui_msg "Plan (dry run - nothing written)" "$_txt"; printf '%s\n' "$_txt"; exit 0; fi
	[ "$UI_MODE" = auto ] && { printf '%s\n' "$_txt"; return 0; }
	ui_yesno "Ready to install" "$_txt

Install now?" no || exit 1
	if [ "$INSTALL_MODE" = erase ]; then
		_t=$(ui_input "Last check" "ALL DATA ON $INSTALL_DISK WILL BE DELETED.

Type the disk name ($INSTALL_DISK) to confirm:" "") || exit 1
		[ "$_t" = "$INSTALL_DISK" ] || { ui_msg "Cancelled" "Nothing was changed."; exit 1; }
	fi
}

# --------------------------------------------------------------- installing ---

run() { _log "+ $*"; "$@" >> "$LOG" 2>&1; }

do_partition() {
	step "Partitioning $INSTALL_DISK"
	if [ "$INSTALL_MODE" = erase ]; then
		gpart destroy -F "$INSTALL_DISK" >> "$LOG" 2>&1 || true
		run gpart create -s gpt "$INSTALL_DISK"
		run gpart add -a 1m -t efi -s 260m -l fbsd-esp "$INSTALL_DISK"
		run gpart add -a 4k -t freebsd-boot -s 512k -l fbsd-boot "$INSTALL_DISK"
		[ "$SWAP_SECTORS" -gt 0 ] && run gpart add -a 1m -t freebsd-swap -s "$SWAP_SECTORS" -l fbsd-swap "$INSTALL_DISK"
		run gpart add -a 1m -t freebsd-zfs -l fbsd-zfs "$INSTALL_DISK"
		ESP_DEV=$(esp_of "$INSTALL_DISK")
		run newfs_msdos -F 32 -c 1 -L EFISYS "/dev/$ESP_DEV"
	else
		gpart show -l "$INSTALL_DISK" | grep -qE ' (fbsd-swap|fbsd-zfs) ' &&
			die "$INSTALL_DISK already has partitions labelled fbsd-zfs/fbsd-swap from an earlier attempt; remove them first"
		run gpart add -t freebsd-zfs -l fbsd-zfs -b "$START" -s "$ZFS_SECTORS" "$INSTALL_DISK"
		[ "$SWAP_SECTORS" -gt 0 ] && run gpart add -t freebsd-swap -l fbsd-swap -b $(( START + ZFS_SECTORS )) -s "$SWAP_SECTORS" "$INSTALL_DISK"
		ESP_DEV=$(esp_of "$INSTALL_DISK")
	fi
	for _i in 1 2 3 4 5 6 7 8 9 10; do [ -c /dev/gpt/fbsd-zfs ] && break; sleep 1; done
	[ -c /dev/gpt/fbsd-zfs ] || die "/dev/gpt/fbsd-zfs did not appear"
	gpart show -l "$INSTALL_DISK" | tee -a "$LOG"
}

do_pool() {
	step "Creating the ZFS pool $POOL"
	mkdir -p "$MNT"
	run zpool create -f -o altroot="$MNT" -o ashift=12 -o autotrim=on \
		-O compression=lz4 -O atime=off -O xattr=sa -O mountpoint=none "$POOL" /dev/gpt/fbsd-zfs
	run zfs create -o mountpoint=none "$POOL/ROOT"
	run zfs create -o mountpoint=/ -o canmount=noauto "$POOL/ROOT/default"
	run zfs mount "$POOL/ROOT/default"
	run zfs create -o mountpoint=/home "$POOL/home"
	run zfs create -o mountpoint=/tmp -o exec=on -o setuid=off "$POOL/tmp"
	run zfs create -o mountpoint=/usr -o canmount=off "$POOL/usr"
	run zfs create -o setuid=off "$POOL/usr/ports"
	run zfs create "$POOL/usr/src"
	run zfs create "$POOL/usr/obj"
	run zfs create -o mountpoint=/var -o canmount=off "$POOL/var"
	for _d in audit crash log; do run zfs create -o exec=off -o setuid=off "$POOL/var/$_d"; done
	run zfs create -o atime=on "$POOL/var/mail"
	run zfs create -o setuid=off "$POOL/var/tmp"
	run zpool set bootfs="$POOL/ROOT/default" "$POOL"
	chmod 1777 "$MNT/tmp" "$MNT/var/tmp"
}

do_base() {
	step "Downloading and installing FreeBSD $REL"
	_dist="$MNT/var/tmp/freebsd-dist"
	mkdir -p "$_dist"
	# Checksums from the install media when it has them, else from the mirror.
	if [ -f /usr/freebsd-dist/MANIFEST ]; then cp /usr/freebsd-dist/MANIFEST "$_dist/"
	else fetch -q -o "$_dist/MANIFEST" "$DIST_URL/MANIFEST" || die "could not download the MANIFEST"; fi
	for _s in base kernel lib32; do
		if [ -f "/usr/freebsd-dist/$_s.txz" ]; then
			cp "/usr/freebsd-dist/$_s.txz" "$_dist/"
		else
			say "downloading $_s.txz"
			fetch -o "$_dist/$_s.txz" "$DIST_URL/$_s.txz" || die "download of $_s.txz failed"
		fi
		_want=$(awk -v f="$_s.txz" '$1 == f { print $2 }' "$_dist/MANIFEST")
		[ "$(sha256 -q "$_dist/$_s.txz")" = "$_want" ] || die "checksum mismatch for $_s.txz - the download is damaged, try again"
		say "unpacking $_s.txz"
		tar -xpf "$_dist/$_s.txz" -C "$MNT" || die "unpacking $_s.txz failed"
	done
	rm -rf "$_dist"
	if [ "${SKIP_FREEBSD_UPDATE:-no}" != yes ]; then
		say "applying security patches (freebsd-update)"
		mkdir -p "$MNT/var/db/freebsd-update"
		if env PAGER=cat freebsd-update -b "$MNT" -d "$MNT/var/db/freebsd-update" -f "$MNT/etc/freebsd-update.conf" \
			--not-running-from-cron --currently-running "$REL" fetch >> "$LOG" 2>&1; then
			env PAGER=cat freebsd-update -b "$MNT" -d "$MNT/var/db/freebsd-update" -f "$MNT/etc/freebsd-update.conf" \
				--not-running-from-cron --currently-running "$REL" install >> "$LOG" 2>&1 || true
		else
			warn "could not fetch security patches now; run 'sysup' after the first boot"
		fi
	fi
}

do_config() {
	step "Configuring the new system"
	cat > "$MNT/boot/loader.conf" <<EOF
zfs_load="YES"
kern.geom.label.disk_ident.enable="0"
kern.geom.label.gptid.enable="0"
autoboot_delay="3"
EOF
	{
		echo "# Device		Mountpoint	FStype	Options		Dump	Pass#"
		_lab=$(gpart show -l -p "$INSTALL_DISK" | awk -v d="$ESP_DEV" '$3 == d { print $4; exit }')
		if [ -n "$_lab" ] && [ "$_lab" != "(null)" ] && [ -c "/dev/gpt/$_lab" ]; then
			echo "/dev/gpt/$_lab	/boot/efi	msdosfs	rw,failok	0	0"
		elif [ -n "$ESP_DEV" ]; then
			echo "/dev/$ESP_DEV	/boot/efi	msdosfs	rw,failok	0	0"
		fi
		[ "$SWAP_SECTORS" -gt 0 ] && echo "/dev/gpt/fbsd-swap	none	swap	sw	0	0"
	} > "$MNT/etc/fstab"
	cat > "$MNT/etc/rc.conf" <<EOF
hostname="$HOSTNAME_NEW"
zfs_enable="YES"
ifconfig_DEFAULT="DHCP inet6 accept_rtadv"
sshd_enable="NO"
ntpd_enable="YES"
ntpd_sync_on_start="YES"
dumpdev="AUTO"
EOF
	# Network set up in the live system (bsdinstall netconfig) carries over.
	if [ -f /tmp/bsdinstall_etc/rc.conf.net ]; then
		cat /tmp/bsdinstall_etc/rc.conf.net >> "$MNT/etc/rc.conf"
	fi
	[ -f /tmp/bsdinstall_etc/wpa_supplicant.conf ] &&
		install -m 600 /tmp/bsdinstall_etc/wpa_supplicant.conf "$MNT/etc/wpa_supplicant.conf"
	cp /etc/resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true
	echo 'vfs.zfs.vdev.min_auto_ashift=12' > "$MNT/etc/sysctl.conf"
	cp "/usr/share/zoneinfo/$TIMEZONE" "$MNT/etc/localtime"
	echo "$TIMEZONE" > "$MNT/var/db/zoneinfo"
	[ "$RTC_LOCAL" = yes ] && touch "$MNT/etc/wall_cmos_clock"
	# A TLS-intercepting proxy (company networks) needs its CA in the new system.
	if [ -n "$EXTRA_CA" ]; then
		mkdir -p "$MNT/usr/local/share/certs"
		awk -v d="$MNT/usr/local/share/certs" '/BEGIN CERT/ { n++ } { print > (d "/fbs-extra-ca-" n ".pem") }' "$EXTRA_CA"
		chroot "$MNT" certctl rehash >> "$LOG" 2>&1 || true
	fi
}

do_users() {
	step "Creating the user account"
	printf '%s\n' "$ROOT_PASSWORD" | chroot "$MNT" pw usermod root -h 0
	printf '%s\n' "$USER_PASSWORD" | chroot "$MNT" pw useradd "$USERNAME" -m -c "${USER_FULLNAME:-$USERNAME}" \
		-G wheel,operator,video -s /bin/sh -h 0
	chroot "$MNT" pw usershow "$USERNAME" >/dev/null || die "creating the user failed"
}

do_boot() {
	step "Making it bootable"
	if [ -n "$ESP_DEV" ]; then
		mkdir -p "$MNT/boot/efi"
		run mount -t msdosfs "/dev/$ESP_DEV" "$MNT/boot/efi"
		mkdir -p "$MNT/boot/efi/EFI/freebsd"
		cp "$MNT/boot/loader.efi" "$MNT/boot/efi/EFI/freebsd/loader.efi"
		# Tell the loader which dataset to boot, so it never guesses on a
		# disk shared with other systems.
		printf 'rootdev=zfs:%s/ROOT/default:\n' "$POOL" > "$MNT/boot/efi/EFI/freebsd/loader.env"
		if [ "$INSTALL_MODE" = erase ]; then
			# The fallback path firmware uses when its boot entries are lost.
			mkdir -p "$MNT/boot/efi/EFI/BOOT"
			cp "$MNT/boot/loader.efi" "$MNT/boot/efi/EFI/BOOT/BOOTX64.EFI"
		else
			boot_integrate
		fi
		if [ "$HW_BOOT" = UEFI ]; then efi_entry; fi
		umount "$MNT/boot/efi"
	fi
	if [ "$INSTALL_MODE" = erase ]; then
		_bi=$(gpart show -l "$INSTALL_DISK" | awk '$4 == "fbsd-boot" { print $3 }')
		[ -n "$_bi" ] && run gpart bootcode -b "$MNT/boot/pmbr" -p "$MNT/boot/gptzfsboot" -i "$_bi" "$INSTALL_DISK"
	fi
}

efi_entry() {
	# Remove entries left by an earlier attempt, then add ours.
	for _b in $(efibootmgr | awk '/^[ +]*Boot[0-9A-Fa-f]{4}\*? FreeBSD$/ { sub(/^[ +]*Boot/, ""); sub(/\*.*/, ""); print $1 }'); do
		efibootmgr -B -b "$_b" >/dev/null 2>&1 || true
	done
	_old=$(efibootmgr | awk -F': *' '/^BootOrder/ { gsub(/ /, "", $2); print $2 }')
	if efibootmgr -c -a -l "$MNT/boot/efi/EFI/freebsd/loader.efi" -L FreeBSD >> "$LOG" 2>&1; then
		_new=$(efibootmgr | awk '/^[ +]*Boot[0-9A-Fa-f]{4}\*? FreeBSD$/ { sub(/^[ +]*Boot/, ""); sub(/\*.*/, ""); print $1 }' | tail -1)
		_old=$(echo "$_old" | tr ',' '\n' | grep -vx "$_new" | paste -sd, -)
		if [ "$INSTALL_MODE" = erase ] || [ "$BOOT_DEFAULT" = freebsd ]; then
			_order="$_new${_old:+,$_old}"
		else
			_order="${_old:+$_old,}$_new"
		fi
		efibootmgr -o "$_order" >> "$LOG" 2>&1 || warn "could not set the boot order; choose FreeBSD in the firmware boot menu"
	else
		warn "could not add a firmware boot entry; FreeBSD still starts from the menus listed in the summary"
	fi
}

boot_integrate() {
	_esp="$MNT/boot/efi"
	if yes BOOT_INTEGRATION && [ -n "$LIMINE_CONF" ] && [ -f "$_esp/$LIMINE_CONF" ]; then
		if ! grep -q 'EFI/freebsd/loader.efi' "$_esp/$LIMINE_CONF"; then
			cp "$_esp/$LIMINE_CONF" "$_esp/$LIMINE_CONF.before-freebsd"
			printf '\n/FreeBSD\n    comment: FreeBSD on ZFS (added by FreeBSD-setup)\n    protocol: efi\n    path: boot():/EFI/freebsd/loader.efi\n' >> "$_esp/$LIMINE_CONF"
			say "added FreeBSD to the Limine menu ($LIMINE_CONF; backup: $LIMINE_CONF.before-freebsd)"
		fi
	fi
	if yes BOOT_INTEGRATION && [ "$HAS_SDBOOT" = yes ]; then
		mkdir -p "$_esp/loader/entries"
		printf 'title   FreeBSD\nefi     /EFI/freebsd/loader.efi\n' > "$_esp/loader/entries/freebsd.conf"
		say "added FreeBSD to the systemd-boot menu"
	fi
	# FreeBSD's own menu: an entry to start the other system (key L).
	if [ -n "$CHAIN_PATH" ]; then
		cat >> "$MNT/boot/loader.conf" <<EOF
fbs_chain_path="$CHAIN_PATH"
fbs_chain_name="${CHAIN_NAME:-other system}"
EOF
		install -m 444 "$REPO_DIR/files/local.lua" "$MNT/boot/lua/local.lua"
	fi
}

do_setup() {
	step "Copying FreeBSD-setup into the new system"
	_share="$MNT$FBS_SHARE"
	mkdir -p "$_share"
	(cd "$REPO_DIR" && tar -cf - --exclude .git .) | tar -xf - -C "$_share"
	mkdir -p "$MNT/usr/local/sbin"
	ln -sf "$FBS_SHARE/setup.sh" "$MNT/usr/local/sbin/freebsd-setup"
	TARGET_USER=$USERNAME
	save_config "$MNT$FBS_CONF"
	[ "$BASE_ONLY" = yes ] && return 0

	step "Installing the desktop (the long part)"
	mount -t devfs devfs "$MNT/dev"
	_rc=0
	chroot "$MNT" /usr/bin/env FBS_TARGET=chroot SSL_CA_CERT_FILE= \
		/bin/sh "$FBS_SHARE/setup.sh" --chroot --yes --user "$USERNAME" || _rc=$?
	umount "$MNT/dev" 2>/dev/null || umount -f "$MNT/dev" 2>/dev/null || true
	if [ "$_rc" -ne 0 ]; then
		warn "the desktop setup stopped with an error. FreeBSD itself is installed and will boot; after logging in, run: doas freebsd-setup   (log: /var/log/freebsd-setup.log)"
	fi
}

do_finish() {
	step "Finishing"
	cp "$LOG" "$MNT/var/log/freebsd-install.log" 2>/dev/null || true
	zfs snapshot -r "$POOL@installed" 2>/dev/null || true
	zfs unmount -a 2>/dev/null || true
	zpool export "$POOL" >> "$LOG" 2>&1 || warn "could not export the pool cleanly; it is still fine to reboot"
}

# --------------------------------------------------------------------- main ---

if [ "$UI_MODE" != auto ]; then
	_rep=$(mktemp)
	{
		echo "Welcome! This installs FreeBSD with a ready-to-use desktop."
		echo "First, what was found in this computer:"
		echo
		hw_report
	} > "$_rep"
	ui_text "Welcome" "$_rep"
	rm -f "$_rep"
	if [ "$HW_DESKTOP" != yes ] && ! ui_yesno "Desktop not possible" "$HW_DESKTOP_WHY.

You can still install FreeBSD (text console only, or to try things). Continue?" no; then exit 1; fi
fi
ask_network
ask_disk
ask_mode
ask_account
ask_region
[ "$BASE_ONLY" = yes ] || ask_desktop
ask_boot
resolve_config
plan_sizes
confirm

do_partition
do_pool
do_base
do_config
do_users
do_boot
do_setup
do_finish

_done="FreeBSD is installed.

Remove the USB stick and restart the computer.$( [ "$INSTALL_MODE" = alongside ] && [ "$BOOT_DEFAULT" != freebsd ] && echo "
Start FreeBSD from:${BOOT_SUMMARY:-
  - the firmware boot menu}")$( [ -n "$WARNINGS" ] && echo "

Things that need attention:$WARNINGS")"
ui_msg "Done" "$_done"
printf '%s\n' "$_done"
if [ "$UI_MODE" != auto ] && ui_yesno "Restart" "Restart now?" yes; then shutdown -r now; fi
