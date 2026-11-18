# Stage: security - a desktop firewall and a few safe kernel defaults.

if is_yes FIREWALL; then
	say "firewall (pf): block unsolicited incoming connections, allow everything outgoing"
	if [ -f /etc/pf.conf ] && ! grep -q 'FreeBSD-setup' /etc/pf.conf; then
		cp /etc/pf.conf "/etc/pf.conf.before-freebsd-setup"
		say "your previous /etc/pf.conf was saved as /etc/pf.conf.before-freebsd-setup"
	fi
	install_file "$REPO_DIR/files/pf.conf" /etc/pf.conf 600
	# The user's own rules: created once, never replaced.
	[ -f /etc/pf.local.conf ] || {
		cat > /etc/pf.local.conf <<'PFL'
# /etc/pf.local.conf - your own firewall rules, read after /etc/pf.conf.
# FreeBSD-setup creates this file once and never changes it.
# Example: open the ports KDE Connect uses, then run  doas service pf reload
# pass in proto { tcp, udp } to port 1714:1764
PFL
		chmod 600 /etc/pf.local.conf
	}
	# pfctl needs the pf module even for a syntax check (-n)
	is_live && { kldload -n pf 2>/dev/null || true; }
	if is_chroot || pfctl -nf /etc/pf.conf >> "$LOG" 2>&1; then
		sysrc pf_enable=YES >/dev/null
		if is_live; then
			kldload -n pf 2>/dev/null || true
			service pf status >/dev/null 2>&1 && service pf reload >> "$LOG" 2>&1 || service pf start >> "$LOG" 2>&1 || true
		fi
	else
		warn "the firewall rules did not load (details: $LOG) - firewall left off"
	fi
else
	say "firewall not selected"
fi

say "kernel hardening that does not get in a desktop user's way"
sysctl_set kern.randompid 1
sysctl_set security.bsd.unprivileged_read_msgbuf 0
sysctl_set security.bsd.hardlink_check_uid 1
sysctl_set security.bsd.hardlink_check_gid 1

true   # (a stage must not end on a failed test: setup.sh runs under set -e)
