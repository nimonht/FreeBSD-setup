# Stage: system - services, power management, kernel tuning, device access.

say "services: D-Bus, time sync, power management"
pkg_install dbus
svc dbus
sysrc ntpd_enable=YES ntpd_sync_on_start=YES >/dev/null
sysrc clear_tmp_enable=YES >/dev/null
sysrc dumpdev=AUTO >/dev/null
loader_set autoboot_delay 3
kld_add fusefs

if [ "$HW_VM" = none ]; then
	sysrc powerd_enable=YES powerd_flags="-a hiadaptive -b adaptive -n adaptive" >/dev/null
	is_live && { service powerd status >/dev/null 2>&1 || service powerd start >> "$LOG" 2>&1 || true; }
fi

# Power profiles (power saver / balanced / performance) in KDE's battery
# applet and Caelestia: our own service answering as power-profiles-daemon
# (Linux-only) on D-Bus. It decides at every start whether this machine has
# a CPU power setting to change, and stays off when it has none.
say "power profiles service (power saver / balanced / performance)"
_py=$(pkg_flavor python3 'python3[0-9]+')
_pygo="py${_py#python}-pygobject"
[ -n "$_py" ] && pkg_try python3 polkit "$_pygo"
if [ -n "$_py" ] && [ -x /usr/local/bin/python3 ] && pkg info -e "$_pygo" 2>/dev/null; then
	_pp="$REPO_DIR/files/power-profiles"
	mkdir -p /usr/local/libexec /usr/local/share/dbus-1/system.d \
		/usr/local/share/polkit-1/actions /usr/local/etc/polkit-1/rules.d
	install_file "$_pp/fbs-power-profiles" /usr/local/libexec/fbs-power-profiles 755
	install_file "$_pp/fbs-power-profiles.conf" /usr/local/share/dbus-1/system.d/fbs-power-profiles.conf
	install_file "$_pp/org.freedesktop.UPower.PowerProfiles.policy" \
		/usr/local/share/polkit-1/actions/org.freedesktop.UPower.PowerProfiles.policy
	install_file "$_pp/50-fbs-power-profiles.rules" /usr/local/etc/polkit-1/rules.d/50-fbs-power-profiles.rules
	install_file "$REPO_DIR/files/rc.d/fbs_power_profiles" /usr/local/etc/rc.d/fbs_power_profiles 755
	sysrc fbs_power_profiles_enable=YES >/dev/null
	if is_live; then
		# read the new access rules (FreeBSD's rc.d/dbus has no "reload")
		dbus-send --system --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ReloadConfig >> "$LOG" 2>&1 || true
		service fbs_power_profiles restart >> "$LOG" 2>&1 || true
	fi
else
	warn "the power profile switch is not available: Python's GObject package could not be installed (rerun: freebsd-setup system)"
fi

# Lock the desktop before every suspend (lid, sleep key, menus, zzz): the
# desktops only lock when they start the suspend themselves.
install_file "$REPO_DIR/files/rc.d/fbs_lock_on_suspend" /usr/local/etc/rc.d/fbs_lock_on_suspend 755
sysrc fbs_lock_on_suspend_enable=YES >/dev/null

if [ "$HW_LAPTOP" = yes ]; then
	say "laptop: deeper idle states, unused devices powered down"
	sysrc performance_cx_lowest=Cmax economy_cx_lowest=Cmax >/dev/null
	sysctl_set hw.pci.do_power_nodriver 3
	# Suspend on lid close only where S3 exists and no NVIDIA driver is loaded
	# (resume with the NVIDIA driver is unreliable on FreeBSD).
	case " $HW_SLEEP " in
	*" S3 "*)
		if ! pkg query -g %n 'nvidia-driver*' 2>/dev/null | grep -q .; then
			sysctl_set hw.acpi.lid_switch_state S3
			say "closing the lid suspends (S3)"
		else
			say "lid close does nothing while the NVIDIA driver is in use (resume is unreliable)"
		fi ;;
	esac
fi

say "kernel settings for a desktop (/etc/sysctl.conf)"
sysctl_set vfs.usermount 1                       # users may mount their own drives
sysctl_set kern.coredump 0                       # no core files in your home folder
sysctl_set hw.acpi.power_button_state S5         # power button = clean shutdown
sysctl_set kern.ipc.shm_allow_removed 1          # needed by Chromium/Electron apps
sysctl_set net.local.stream.recvspace 65536      # recommended for KDE Plasma
sysctl_set net.local.stream.sendspace 65536
sysctl_set kern.maxfiles 524288
sysctl_set kern.maxfilesperproc 262144
sysctl_set security.bsd.unprivileged_chroot 1    # Steam runtime and sandboxed apps
loader_set kern.ipc.shmseg 1024
loader_set kern.ipc.shmmni 1024

# /proc and /dev/fd are expected by a lot of desktop software.
add_line /etc/fstab "proc	/proc	procfs	rw	0	0"
add_line /etc/fstab "fdescfs	/dev/fd	fdescfs	rw	0	0"
if is_live; then mount /proc 2>/dev/null || true; mount /dev/fd 2>/dev/null || true; fi

# Device access for the desktop user: GPU, backlight, webcam, printers.
say "device permissions (/etc/devfs.rules)"
if [ -f /etc/devfs.rules ] && ! grep -q 'FreeBSD-setup' /etc/devfs.rules; then
	cp /etc/devfs.rules /etc/devfs.rules.before-freebsd-setup
	say "your previous /etc/devfs.rules was saved as /etc/devfs.rules.before-freebsd-setup"
fi
# No raw access to disks (da*): that would let the user read and overwrite
# any file system on them, past all file permissions. USB drives are mounted
# through bsdisks (see the desktop stage), which needs no such access.
install_file "$REPO_DIR/files/devfs.rules" /etc/devfs.rules
sysrc devfs_system_ruleset=localrules >/dev/null
is_live && { service devfs restart >> "$LOG" 2>&1 || true; }

# brightnessctl look-alike on top of backlight(8): Caelestia and many
# Wayland tools call brightnessctl.
install_file "$REPO_DIR/files/bin/brightnessctl" /usr/local/bin/brightnessctl 755

true   # (a stage must not end on a failed test: setup.sh runs under set -e)
