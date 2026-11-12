# Stage: zfs - boot environments, automatic snapshots, scrub, TRIM, ARC cap.

POOL=$(root_pool)
if [ -z "$POOL" ]; then
	warn "root is not on ZFS - zfs stage skipped"
	return 0 2>/dev/null || true
fi

say "pool '$POOL': autotrim on, monthly scrub, ARC capped at ${ARC_MAX_GB} GiB"
zpool set autotrim=on "$POOL" 2>/dev/null || true
ARC_BYTES=$(( ARC_MAX_GB * 1024 * 1024 * 1024 ))
loader_set vfs.zfs.arc.max "$ARC_BYTES"
sysctl vfs.zfs.arc.max="$ARC_BYTES" >/dev/null 2>&1 || sysctl vfs.zfs.arc_max="$ARC_BYTES" >/dev/null 2>&1 || true

set_kv /etc/periodic.conf daily_scrub_zfs_enable '"YES"'
set_kv /etc/periodic.conf daily_scrub_zfs_default_threshold '"30"'   # days between scrubs
set_kv /etc/periodic.conf daily_status_zfs_enable '"YES"'
set_kv /etc/periodic.conf daily_trim_zfs_enable '"NO"'               # autotrim handles it

if [ "$AUTO_SNAPSHOTS" = yes ]; then
	pkg_install zfstools
	say "automatic snapshots: 4x15min, 24 hourly, 7 daily, 4 weekly, 6 monthly"
	mkdir -p /usr/local/etc/cron.d
	cat > /usr/local/etc/cron.d/zfs-auto-snapshot <<'CRON'
# Rolling ZFS snapshots (zfstools). Written by FreeBSD-setup.
SHELL=/bin/sh
PATH=/etc:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
15,30,45 * * * * root zfs-auto-snapshot frequent  4
0        * * * * root zfs-auto-snapshot hourly   24
7        0 * * * root zfs-auto-snapshot daily     7
14       0 * * 7 root zfs-auto-snapshot weekly    4
28       0 1 * * root zfs-auto-snapshot monthly   6
CRON
	# Snapshot everything on the pool, except data that is pointless to keep.
	zfs set com.sun:auto-snapshot=true "$POOL"
	for ds in tmp var/tmp var/crash var/audit usr/obj usr/ports usr/src; do
		zfs list -H "$POOL/$ds" >/dev/null 2>&1 && zfs set com.sun:auto-snapshot=false "$POOL/$ds"
	done
	service cron restart >> "$LOG" 2>&1 || true
fi

# sysup: update the whole system with a safety net (new boot environment).
install -m 755 "$REPO_DIR/files/bin/sysup" /usr/local/sbin/sysup
install -m 755 "$REPO_DIR/files/bin/snap"  /usr/local/sbin/snap
pkg_try httm
say "installed 'sysup' (safe system upgrade) and 'snap' (manual snapshots/rollback)"
