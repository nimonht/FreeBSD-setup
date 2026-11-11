#!/bin/sh
#
# zfs-install.sh - install FreeBSD on ZFS into the FREE SPACE of a disk that
# already holds other operating systems (GPT + UEFI), sharing the existing
# EFI System Partition.
#
# Run it from the FreeBSD installer USB stick: boot the stick, pick
# "Live System" (or "Shell"), log in as root, then:
#
#     sh zfs-install.sh            # asks for everything interactively
#     DISK=nda0 sh zfs-install.sh  # or preset answers through the environment
#
# What it does NOT do: it never deletes, resizes or formats an existing
# partition, and it never touches EFI/BOOT/BOOTX64.EFI or another OS's files
# on the ESP. It only ADDS two partitions (swap + ZFS) inside the largest
# unallocated region of the disk and adds an EFI/freebsd directory to the ESP.
# Nothing is written to the disk until you type YES at the summary.
#
# Tunables (environment variables, all optional):
#   DISK         target disk, e.g. nda0 / nvd0 / ada0 (asked if unset)
#   POOL         ZFS pool name                         (default: zroot)
#   SWAP_SIZE    swap size, e.g. 8g; 0 = no swap       (default: 8g)
#   ZFS_SIZE     ZFS partition size, e.g. 120g         (default: rest of the
#                largest free region)
#   HOSTNAME     host name                             (default: freebsd-laptop)
#   USERNAME     login of your everyday user           (asked if unset)
#   TIMEZONE     e.g. Asia/Ho_Chi_Minh                 (asked if unset)
#   RTC_LOCAL    yes if the hardware clock is local time (Windows default),
#                no if it is UTC                       (asked if unset)
#   DISTDIR      where base.txz/kernel.txz/lib32.txz are (default: the
#                installer media, else downloaded)
#   EFI_ENTRY    yes = also add a "FreeBSD" entry to the firmware boot menu,
#                appended AFTER the existing entries   (default: yes)
#   ASSUME_YES   yes = skip the YES prompt (for automated tests only)

set -eu

POOL="${POOL:-zroot}"
SWAP_SIZE="${SWAP_SIZE:-8g}"
ZFS_SIZE="${ZFS_SIZE:-}"
HOSTNAME="${HOSTNAME:-freebsd-laptop}"
EFI_ENTRY="${EFI_ENTRY:-yes}"
ASSUME_YES="${ASSUME_YES:-no}"
MNT=/mnt
SWAP_LABEL=fbsd-swap
ZFS_LABEL=fbsd-zfs

say()  { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

ask() { # ask VAR "prompt" [default]
	eval "_cur=\${$1:-}"
	[ -n "$_cur" ] && return 0
	if [ -n "${3:-}" ]; then printf '%s [%s]: ' "$2" "$3"; else printf '%s: ' "$2"; fi
	read -r _ans || die "no input"
	[ -z "$_ans" ] && _ans="${3:-}"
	[ -n "$_ans" ] || die "a value is required"
	eval "$1=\$_ans"
}

# size string (e.g. 8g, 512m) -> bytes
to_bytes() {
	case "$1" in
	*[gG]) echo $(( ${1%?} * 1024 * 1024 * 1024 )) ;;
	*[mM]) echo $(( ${1%?} * 1024 * 1024 )) ;;
	*[tT]) echo $(( ${1%?} * 1024 * 1024 * 1024 * 1024 )) ;;
	0)     echo 0 ;;
	*)     die "size '$1' must end in m, g or t (or be 0)" ;;
	esac
}

# ---------------------------------------------------------------- checks ---
[ "$(uname -s)" = FreeBSD ] || die "run this from the FreeBSD installer (Live System), not from $(uname -s)"
[ "$(id -u)" -eq 0 ] || die "must run as root"
[ "$(sysctl -n machdep.bootmethod 2>/dev/null)" = UEFI ] ||
	die "the installer was not booted in UEFI mode. Reboot the USB stick in UEFI mode (disable CSM/Legacy)."
kldload -n zfs 2>/dev/null || true

say "Disks in this machine"
geom disk list | awk '/^Geom name:/{n=$3} /Mediasize:/{s=$3" "$4} /descr:/{sub(/^ *descr: */,""); printf "  %-8s %-14s %s\n", n, s, $0}'
ask DISK "Disk to install FreeBSD on (name from the list above, e.g. nda0)"
DISK="${DISK#/dev/}"
[ -c "/dev/$DISK" ] || die "/dev/$DISK does not exist"
gpart show "$DISK" >/dev/null 2>&1 || die "$DISK has no partition table"
[ "$(gpart show "$DISK" | awk 'NR==1{print $5}')" = GPT ] || die "$DISK is not GPT partitioned (found: $(gpart show "$DISK" | awk 'NR==1{print $5}'))"

if gpart show -l "$DISK" | grep -qE " ($SWAP_LABEL|$ZFS_LABEL) "; then
	die "$DISK already has a partition labelled $SWAP_LABEL or $ZFS_LABEL - a previous run got this far. Inspect with 'gpart show -l $DISK'; delete those two partitions yourself if you want to start over."
fi
if zpool list -H -o name 2>/dev/null | grep -qx "$POOL" || zpool import 2>/dev/null | grep -qE "^ +pool: $POOL\$"; then
	die "a ZFS pool named '$POOL' already exists on this machine. Use another name: POOL=zfbsd sh $0"
fi

# The EFI System Partition: on the target disk if it has one, otherwise the
# only ESP in the machine (two-disk laptops), otherwise ask via ESP_DEV.
ESP_DEV="${ESP_DEV:-}"
ESP_DEV="${ESP_DEV#/dev/}"
if [ -z "$ESP_DEV" ]; then
	ESP_DEV=$(gpart show -p "$DISK" | awk '$4=="efi"{print $3; exit}')
fi
if [ -z "$ESP_DEV" ]; then
	_all=$(gpart show -p 2>/dev/null | awk '$4=="efi"{print $3}')
	[ "$(echo "$_all" | grep -c .)" -eq 1 ] ||
		die "no EFI System Partition on $DISK and $(echo "$_all" | grep -c .) elsewhere. Name the one Limine lives on: ESP_DEV=nda0p1 sh $0"
	ESP_DEV=$_all
fi
[ -c "/dev/$ESP_DEV" ] || die "ESP /dev/$ESP_DEV does not exist"
ESP_LABEL=$(gpart show -l -p 2>/dev/null | awk -v d="$ESP_DEV" '$3==d{print $4; exit}')

# Largest free region, in sectors.
SECSIZE=$(diskinfo "$DISK" | awk '{print $2}')
set -- $(gpart show "$DISK" | awk '$3=="-" && $4=="free" && $2>max {max=$2; start=$1} END{print start+0, max+0}')
FREE_START=$1; FREE_SECTORS=$2
[ "$FREE_SECTORS" -gt 0 ] || die "no unallocated space on $DISK. Shrink a partition from CachyOS/Windows first (see README, step 2)."

ALIGN=$(( 1024 * 1024 / SECSIZE ))                       # 1 MiB in sectors
START=$(( (FREE_START + ALIGN - 1) / ALIGN * ALIGN ))    # round up
USABLE=$(( (FREE_START + FREE_SECTORS - START) / ALIGN * ALIGN ))
SWAP_SECTORS=$(( $(to_bytes "$SWAP_SIZE") / SECSIZE ))
if [ -n "$ZFS_SIZE" ]; then
	ZFS_SECTORS=$(( $(to_bytes "$ZFS_SIZE") / SECSIZE ))
else
	ZFS_SECTORS=$(( USABLE - SWAP_SECTORS ))
fi
[ $(( ZFS_SECTORS + SWAP_SECTORS )) -le "$USABLE" ] ||
	die "not enough free space: need $(( (ZFS_SECTORS + SWAP_SECTORS) * SECSIZE / 1073741824 )) GiB, the largest free region has $(( USABLE * SECSIZE / 1073741824 )) GiB"
[ $(( ZFS_SECTORS * SECSIZE / 1073741824 )) -ge "${MIN_ZFS_GB:-20}" ] ||
	die "the ZFS partition would be only $(( ZFS_SECTORS * SECSIZE / 1073741824 )) GiB; at least 20 GiB is required (60+ GiB recommended for a desktop with games)"
ZFS_START=$START
SWAP_START=$(( START + ZFS_SECTORS ))

# Distribution sets.
REL=$(uname -r | sed 's/-p[0-9]*$//')
SETS="base kernel lib32"
if [ -z "${DISTDIR:-}" ]; then
	if [ -f /usr/freebsd-dist/base.txz ]; then DISTDIR=/usr/freebsd-dist; else DISTDIR=; fi
fi

ask USERNAME "Login name for your everyday user (lowercase, e.g. your first name)"
echo "$USERNAME" | grep -Eq '^[a-z_][a-z0-9_-]{0,15}$' || die "invalid user name '$USERNAME'"
ask TIMEZONE "Time zone (a path under /usr/share/zoneinfo)" "Asia/Ho_Chi_Minh"
[ -f "/usr/share/zoneinfo/$TIMEZONE" ] || die "unknown time zone '$TIMEZONE'"
ask RTC_LOCAL "Is the hardware clock in LOCAL time? Windows default = yes; if Windows shows the right time and CachyOS was told 'RTC in local TZ', answer yes; otherwise no (yes/no)" "no"

# --------------------------------------------------------------- summary ---
say "Current layout of $DISK"
gpart show -p "$DISK"
cat <<EOF

Plan - nothing has been written yet:
  * keep every existing partition exactly as it is
  * new ZFS partition : $(( ZFS_SECTORS * SECSIZE / 1073741824 )) GiB at sector $ZFS_START (label $ZFS_LABEL), pool "$POOL"
  * new swap partition: $(( SWAP_SECTORS * SECSIZE / 1048576 )) MiB (label $SWAP_LABEL)$([ "$SWAP_SECTORS" -eq 0 ] && echo " - skipped")
  * shared ESP        : /dev/$ESP_DEV  -> only adds EFI/freebsd/loader.efi (+ loader.env)
  * firmware entry    : $([ "$EFI_ENTRY" = yes ] && echo 'add "FreeBSD", placed LAST in the boot order (Limine stays default)' || echo 'not added')
  * FreeBSD $REL sets ($SETS) from ${DISTDIR:-download.freebsd.org}
  * host $HOSTNAME, user $USERNAME, time zone $TIMEZONE, RTC local time: $RTC_LOCAL

EOF
if [ "$ASSUME_YES" != yes ]; then
	printf 'Type YES (upper case) to write these changes to %s: ' "$DISK"
	read -r _ok
	[ "$_ok" = YES ] || die "aborted, nothing was changed"
fi

# ----------------------------------------------------------- partitioning ---
say "Creating partitions"
gpart add -t freebsd-zfs -l "$ZFS_LABEL" -b "$ZFS_START" -s "$ZFS_SECTORS" "$DISK"
if [ "$SWAP_SECTORS" -gt 0 ]; then
	gpart add -t freebsd-swap -l "$SWAP_LABEL" -b "$SWAP_START" -s "$SWAP_SECTORS" "$DISK"
fi
# wait for the label device nodes
for _i in 1 2 3 4 5 6 7 8 9 10; do [ -c "/dev/gpt/$ZFS_LABEL" ] && break; sleep 1; done
[ -c "/dev/gpt/$ZFS_LABEL" ] || die "/dev/gpt/$ZFS_LABEL did not appear"
gpart show -l "$DISK"

# -------------------------------------------------------------------- zfs ---
say "Creating pool $POOL and datasets"
mkdir -p "$MNT"
zpool create -f -o altroot="$MNT" -o ashift=12 -o autotrim=on \
	-O compression=lz4 -O atime=off -O xattr=sa \
	-O mountpoint=none "$POOL" "/dev/gpt/$ZFS_LABEL"

zfs create -o mountpoint=none                        "$POOL/ROOT"
zfs create -o mountpoint=/ -o canmount=noauto        "$POOL/ROOT/default"
zfs mount "$POOL/ROOT/default"
zfs create -o mountpoint=/home                       "$POOL/home"
zfs create -o mountpoint=/tmp  -o exec=on -o setuid=off "$POOL/tmp"
zfs create -o mountpoint=/usr  -o canmount=off       "$POOL/usr"
zfs create -o setuid=off                             "$POOL/usr/ports"
zfs create                                           "$POOL/usr/src"
zfs create                                           "$POOL/usr/obj"
zfs create -o mountpoint=/var  -o canmount=off       "$POOL/var"
zfs create -o exec=off -o setuid=off                 "$POOL/var/audit"
zfs create -o exec=off -o setuid=off                 "$POOL/var/crash"
zfs create -o exec=off -o setuid=off                 "$POOL/var/log"
zfs create -o atime=on                               "$POOL/var/mail"
zfs create -o setuid=off                             "$POOL/var/tmp"
zpool set bootfs="$POOL/ROOT/default" "$POOL"
chmod 1777 "$MNT/tmp" "$MNT/var/tmp"

# -------------------------------------------------------------- base system ---
if [ -z "$DISTDIR" ]; then
	DISTDIR="$MNT/var/tmp/freebsd-dist"
	mkdir -p "$DISTDIR"
	say "Downloading distribution sets for $REL (needs network: try 'dhclient <nic>' first if this fails)"
	for s in $SETS; do
		fetch -o "$DISTDIR/$s.txz" "https://download.freebsd.org/releases/amd64/$REL/$s.txz"
	done
	fetch -o "$DISTDIR/MANIFEST" "https://download.freebsd.org/releases/amd64/$REL/MANIFEST"
	DOWNLOADED=yes
fi
if [ -f "$DISTDIR/MANIFEST" ]; then
	say "Verifying checksums"
	for s in $SETS; do
		want=$(awk -v f="$s.txz" '$1==f{print $2}' "$DISTDIR/MANIFEST")
		have=$(sha256 -q "$DISTDIR/$s.txz")
		[ "$want" = "$have" ] || die "checksum mismatch for $s.txz"
	done
fi
for s in $SETS; do
	say "Extracting $s.txz"
	tar -xpf "$DISTDIR/$s.txz" -C "$MNT"
done
[ "${DOWNLOADED:-no}" = yes ] && rm -rf "$DISTDIR"

# ------------------------------------------------------------ configuration ---
say "Writing system configuration"
cat > "$MNT/boot/loader.conf" <<EOF
zfs_load="YES"
cryptodev_load="YES"
kern.geom.label.disk_ident.enable="0"
kern.geom.label.gptid.enable="0"
autoboot_delay="3"
EOF

# Mount the ESP by partition label when it has one, else by device name.
if [ -n "$ESP_LABEL" ] && [ "$ESP_LABEL" != "(null)" ] && [ -c "/dev/gpt/$ESP_LABEL" ]; then
	ESP_FSTAB="/dev/gpt/$ESP_LABEL"
else
	ESP_FSTAB="/dev/$ESP_DEV"
fi
{
	echo "# Device                Mountpoint      FStype  Options         Dump    Pass#"
	echo "$ESP_FSTAB	/boot/efi	msdosfs	rw,failok	0	0"
	[ "$SWAP_SECTORS" -gt 0 ] && echo "/dev/gpt/$SWAP_LABEL	none	swap	sw	0	0"
	echo "fdescfs	/dev/fd	fdescfs	rw	0	0"
	echo "proc	/proc	procfs	rw	0	0"
} > "$MNT/etc/fstab"

cat > "$MNT/etc/rc.conf" <<EOF
hostname="$HOSTNAME"
zfs_enable="YES"
ifconfig_DEFAULT="DHCP inet6 accept_rtadv"
sshd_enable="NO"
ntpd_enable="YES"
ntpd_sync_on_start="YES"
powerd_enable="YES"
powerd_flags="-a hiadaptive -b adaptive"
moused_nondefault_enable="NO"
dumpdev="AUTO"
clear_tmp_enable="NO"
EOF
cat > "$MNT/etc/sysctl.conf" <<EOF
vfs.zfs.vdev.min_auto_ashift=12
EOF

cp "/usr/share/zoneinfo/$TIMEZONE" "$MNT/etc/localtime"
echo "$TIMEZONE" > "$MNT/var/db/zoneinfo"
case "$RTC_LOCAL" in [yY]*) touch "$MNT/etc/wall_cmos_clock" ;; esac
cp /etc/resolv.conf "$MNT/etc/resolv.conf" 2>/dev/null || true

# Wi-Fi: if the installer sees a wireless card, offer to configure it so the
# new system has network on first boot.
WLAN_DEV=$(sysctl -n net.wlan.devices 2>/dev/null | awk '{print $1}')
if [ -n "$WLAN_DEV" ] && [ "$ASSUME_YES" != yes ]; then
	printf '\nWireless card %s found. Wi-Fi network name (SSID), or just Enter to skip: ' "$WLAN_DEV"
	read -r _ssid
	if [ -n "$_ssid" ]; then
		stty -echo; printf 'Wi-Fi password: '; read -r _psk; stty echo; echo
		umask 077
		wpa_passphrase "$_ssid" "$_psk" | grep -v '#psk=' > "$MNT/etc/wpa_supplicant.conf"
		umask 022
		{
			echo "wlans_$WLAN_DEV=\"wlan0\""
			echo "ifconfig_wlan0=\"WPA SYNCDHCP\""
			echo "create_args_wlan0=\"country ${WLAN_COUNTRY:-VN}\""
		} >> "$MNT/etc/rc.conf"
	fi
fi

# ------------------------------------------------------------------ users ---
say "Accounts"
if [ "$ASSUME_YES" = yes ]; then
	echo "${TEST_PASSWORD:-freebsd}" | chroot "$MNT" pw usermod root -h 0
	echo "${TEST_PASSWORD:-freebsd}" | chroot "$MNT" pw useradd "$USERNAME" -m -G wheel,operator,video -s /bin/sh -h 0
else
	echo "Set the ROOT password:"
	until chroot "$MNT" passwd root; do :; done
	chroot "$MNT" pw useradd "$USERNAME" -m -G wheel,operator,video -s /bin/sh
	echo "Set the password for $USERNAME:"
	until chroot "$MNT" passwd "$USERNAME"; do :; done
fi

# Keep a copy of this repository on the new system for setup.sh.
SRC_DIR=$(cd "$(dirname "$0")/.." 2>/dev/null && pwd || true)
if [ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/setup.sh" ]; then
	mkdir -p "$MNT/home/$USERNAME/FreeBSD-setup"
	( cd "$SRC_DIR" && tar -cf - . ) | tar -xf - -C "$MNT/home/$USERNAME/FreeBSD-setup"
	chroot "$MNT" chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/FreeBSD-setup"
fi

# ------------------------------------------------------------- boot loader ---
say "Installing loader.efi on the shared ESP (/dev/$ESP_DEV)"
mkdir -p "$MNT/boot/efi"
mount -t msdosfs "/dev/$ESP_DEV" "$MNT/boot/efi"
mkdir -p "$MNT/boot/efi/EFI/freebsd"
cp "$MNT/boot/loader.efi" "$MNT/boot/efi/EFI/freebsd/loader.efi"
# Tell the loader exactly which dataset to boot, so it never guesses on a
# disk shared with other systems.
printf 'rootdev=zfs:%s/ROOT/default:\n' "$POOL" > "$MNT/boot/efi/EFI/freebsd/loader.env"
ls -l "$MNT/boot/efi/EFI/freebsd/"

if [ "$EFI_ENTRY" = yes ]; then
	OLD_ORDER=$(efibootmgr | awk -F': *' '/^BootOrder/{gsub(/ /,"",$2); print $2}')
	if efibootmgr -c -a -l "$MNT/boot/efi/EFI/freebsd/loader.efi" -L FreeBSD >/dev/null 2>&1; then
		NEW=$(efibootmgr | awk '/FreeBSD$/ || / FreeBSD /{sub(/^[ +]*Boot/,""); sub(/\*.*/,""); print $1}' | tail -1)
		# Put the old order back in front; FreeBSD goes last.
		if [ -n "$OLD_ORDER" ] && [ -n "$NEW" ]; then
			efibootmgr -o "$OLD_ORDER,$NEW" >/dev/null 2>&1 || warn "could not restore the boot order; check it in the firmware setup"
		fi
		efibootmgr | grep -E '^BootOrder|FreeBSD'
	else
		warn "could not add a firmware boot entry (harmless - boot FreeBSD through Limine)"
	fi
fi
umount "$MNT/boot/efi"

# ---------------------------------------------------------------- finish ---
say "Snapshotting the pristine install"
zfs snapshot -r "$POOL@fresh-install"

zfs unmount -a 2>/dev/null || true
zpool export "$POOL"

cat <<EOF

$(printf '\033[1;32mDone.\033[0m') FreeBSD $REL is installed on $POOL (/dev/gpt/$ZFS_LABEL).

Next:
  1. 'reboot', remove the USB stick, boot CachyOS (or use the firmware boot
     menu entry "FreeBSD" to test right away).
  2. Add the FreeBSD entry to Limine - see limine/freebsd.conf in this repo.
  3. Boot FreeBSD, log in as $USERNAME, then:
         cd ~/FreeBSD-setup && su -m root -c './setup.sh'
EOF
