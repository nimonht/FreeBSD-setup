# Stage: security - a desktop firewall and a few safe kernel defaults.

if is_yes FIREWALL; then
	say "firewall (pf): block unsolicited incoming connections, allow everything outgoing"
	if [ -f /etc/pf.conf ] && ! grep -q 'FreeBSD-setup' /etc/pf.conf; then
		cp /etc/pf.conf "/etc/pf.conf.before-freebsd-setup"
		say "your previous /etc/pf.conf was saved as /etc/pf.conf.before-freebsd-setup"
	fi
	install_file "$REPO_DIR/files/pf.conf" /etc/pf.conf 600
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
