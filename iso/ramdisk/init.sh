#!/rescue/sh
#
# init.sh - first stage of the LunaBSD live media, run by init(8) from the
# ramdisk (loader.conf: init_script="/init.sh"). Only /rescue is available.
#
# 1. find the media by its volume label (/dev/iso9660/@LABEL@)
# 2. copy the compressed live system (luna/system.zfs, a ZFS stream) into a
#    ZFS pool in memory: the stick can be removed afterwards, and the live
#    system can be written to (settings, downloads, pkg install)
# 3. the ramdisk's /etc/rc then switches to that pool (reboot -r)
#
# The same approach as GhostBSD's live media. Copying instead of reading
# from the stick is required: reboot -r unmounts the media.

# shellcheck disable=SC2123  # only /rescue exists in the ramdisk
PATH=/rescue
export PATH
LABEL="@LABEL@"
POOL=lunalive

say() { echo "==> $*"; }
fail() {
	echo
	echo "LunaBSD could not start: $*"
	echo "Press Enter to turn the computer off."
	read -r _ < /dev/console
	halt -p
	exit 1
}

case "$(ps -o command 1 | tail -n 1)" in
*" -s"*)
	say "single-user mode: a shell in the ramdisk (type exit to continue)"
	exit 0 ;;
esac

mount -u -w /
mkdir -p /cdrom

say "looking for the LunaBSD media"
n=0
while [ ! -e "/dev/iso9660/$LABEL" ]; do
	n=$((n + 1))
	[ "$n" -gt 60 ] && fail "the USB stick or DVD was not found. Write the ISO to the stick again (Rufus: DD image mode), or try another USB port."
	sleep 1
done
mount_cd9660 "/dev/iso9660/$LABEL" /cdrom || fail "the media could not be read"
[ -f /cdrom/luna/system.zfs ] || fail "luna/system.zfs is missing on the media"

# Memory: the compressed system stays in RAM; the desktop needs the rest.
img=$(ls -l /cdrom/luna/system.zfs | { read -r _ _ _ _ s _; echo "$s"; })
mem=$(sysctl -n hw.physmem)
need=$(( img + 2147483648 ))
if [ "$mem" -lt "$need" ]; then
	fail "this computer has $((mem / 1048576)) MB of memory; the live system needs at least $((need / 1048576)) MB (4 GB or more)."
fi

say "loading LunaBSD into memory ($((img / 1048576)) MB, this takes a minute)"
# A swap-backed memory disk: only what is written uses memory. Room for
# the system plus half of the remaining memory for changes made while live.
md_mb=$(( (img + (mem - img) / 2) / 1048576 ))
mdconfig -a -t swap -s "${md_mb}m" -u 1 || fail "could not create the memory disk"
zpool create -f -m none -O primarycache=metadata -O atime=off "$POOL" /dev/md1 ||
	fail "could not create the memory pool"
dd if=/cdrom/luna/system.zfs bs=1m status=progress |
	zfs receive -u -F -o compression=lz4 "$POOL" ||
	fail "copying the system failed: the media may be damaged (check the ISO's checksum)"
sync
say "done; starting the live system"
exit 0
