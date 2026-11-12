# Stage: base - package branch, updates, core tools, privileges, locale.

POOL=$(root_pool)
[ -n "$POOL" ] || warn "the root filesystem is not ZFS - boot environments and snapshots will be skipped"

# A boot environment to fall back to, before anything is changed.
if [ -n "$POOL" ] && ! bectl list -H | grep -q '^pre-setup'; then
	BE="pre-setup-$(date +%Y%m%d-%H%M)"
	bectl create "$BE" && say "boot environment '$BE' created (undo: bectl activate $BE && reboot)"
fi

say "package branch: $PKG_BRANCH"
mkdir -p /usr/local/etc/pkg/repos
cat > /usr/local/etc/pkg/repos/FreeBSD.conf <<CONF
# Written by FreeBSD-setup. Overrides /etc/pkg/FreeBSD.conf.
FreeBSD-ports: {
  url: "pkg+https://pkg.FreeBSD.org/\${ABI}/$PKG_BRANCH"
}
FreeBSD-ports-kmods: {
  url: "pkg+https://pkg.FreeBSD.org/\${ABI}/kmods_${PKG_BRANCH}_\${VERSION_MINOR}"
}
CONF

say "bootstrapping pkg and updating the catalogue"
env ASSUME_ALWAYS_YES=yes pkg bootstrap -f >> "$LOG" 2>&1 || die "pkg bootstrap failed - is the network up? (ping pkg.freebsd.org)"
pkg update -f >> "$LOG" 2>&1 || die "pkg update failed (details: $LOG)"
say "upgrading installed packages"
env ASSUME_ALWAYS_YES=yes pkg upgrade -y >> "$LOG" 2>&1 || warn "pkg upgrade reported a problem (details: $LOG)"

if [ "$RUN_FREEBSD_UPDATE" = yes ] && ! is_vm; then
	say "freebsd-update: fetching and installing base system patches (a few minutes)"
	if env PAGER=cat freebsd-update --not-running-from-cron fetch >> "$LOG" 2>&1; then
		env PAGER=cat freebsd-update --not-running-from-cron install >> "$LOG" 2>&1 || true
	else
		warn "freebsd-update fetch failed; run 'freebsd-update fetch install' later"
	fi
fi

pkg_install doas sudo git curl bash fish neovim htop tmux rsync unzip zip jq \
	ca_root_nss pciutils usbutils dmidecode smartmontools

# doas for the wheel group; "persist" remembers the password for a few minutes.
if [ ! -f /usr/local/etc/doas.conf ]; then
	cat > /usr/local/etc/doas.conf <<CONF
permit persist :wheel
permit nopass :wheel cmd /sbin/shutdown
permit nopass :wheel cmd /usr/sbin/zzz
CONF
	chmod 600 /usr/local/etc/doas.conf
fi
# sudo too: several desktop tools and scripts written for Linux call it.
mkdir -p /usr/local/etc/sudoers.d
echo '%wheel ALL=(ALL:ALL) ALL' > /usr/local/etc/sudoers.d/wheel
chmod 440 /usr/local/etc/sudoers.d/wheel

say "adding $TARGET_USER to wheel, operator, video"
pw groupmod wheel    -m "$TARGET_USER"
pw groupmod operator -m "$TARGET_USER"
pw groupmod video    -m "$TARGET_USER"

# UTF-8 locale for the desktop user.
if [ ! -f "$TARGET_HOME/.login_conf" ]; then
	say "setting $TARGET_USER's locale to en_US.UTF-8"
	cat > "$TARGET_HOME/.login_conf" <<CONF
me:\\
	:charset=UTF-8:\\
	:lang=en_US.UTF-8:
CONF
	chown "$TARGET_USER" "$TARGET_HOME/.login_conf"
fi
