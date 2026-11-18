# Stage: finish - snapshot and summary.

POOL=$(root_pool)
if [ -n "$POOL" ]; then
	_snap="setup-$(date +%Y%m%d-%H%M)"
	zfs snapshot -r "$POOL@$_snap" && say "snapshot $POOL@$_snap taken"
fi

# Accounts added later (adduser) get the groups the desktop needs: video
# (graphics, brightness), webcamd (cameras), games (game controllers). Only
# when /etc/adduser.conf is missing or ours, and only groups that exist.
if [ "$DESKTOP" != none ] && { [ ! -f /etc/adduser.conf ] || grep -q 'Written by FreeBSD-setup' /etc/adduser.conf; }; then
	_dg=""
	for _g in video webcamd games; do pw groupshow "$_g" >/dev/null 2>&1 && _dg="$_dg $_g"; done
	printf '# Written by FreeBSD-setup: groups for new accounts (see adduser.conf(5)).\ndefaultgroups="%s"\n' "${_dg# }" > /etc/adduser.conf
fi

# The downloaded packages (several GB after a desktop install) are not needed
# any more; removed now, before long-lived snapshots keep them for months.
env ASSUME_ALWAYS_YES=yes pkg clean -a -y >> "$LOG" 2>&1 || true

# Make "freebsd-setup" available as a command for later changes.
if [ "$REPO_DIR" != "$FBS_SHARE" ]; then
	mkdir -p "$FBS_SHARE"
	(cd "$REPO_DIR" && tar -cf - --exclude .git .) | tar -xf - -C "$FBS_SHARE"
fi
ln -sf "$FBS_SHARE/setup.sh" /usr/local/sbin/freebsd-setup

printf '\n\033[1;32mSetup finished.\033[0m Log: %s\n' "$LOG"
if [ -n "${WARNINGS:-}" ]; then
	printf '\n\033[1;33mThings that need your attention:\033[0m%s\n' "$WARNINGS"
fi
case "$DESKTOP" in
kde)      _login="choose \"Plasma (Wayland)\" at the login screen" ;;
hyprland) _login="log in at the login screen (Hyprland starts)" ;;
both)     _hn="Hyprland (FreeBSD)"; is_yes INSTALL_CAELESTIA && _hn="Hyprland (Caelestia)"
          _login="pick \"Plasma (Wayland)\" or \"$_hn\" at the login screen" ;;
*)        _login="log in on the console" ;;
esac
is_live && cat <<EOF

Next steps
  1. Restart:   shutdown -r now
  2. Then $_login as $TARGET_USER.
  3. Change your choices any time:  doas freebsd-setup
  4. Updates:   sysup     (makes a boot environment first, so you can go back)
  5. Snapshots: snap      (list) - every folder has old versions in .zfs/snapshot
EOF
[ "$INSTALL_GAMING" = yes ] && is_live && echo "  6. Steam:     steam-setup (once), then: steam"
is_live && echo "  Problems? docs/TROUBLESHOOTING.md in $FBS_SHARE"
true
