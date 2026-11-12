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
cat > /etc/devfs.rules <<'RULES'
# Written by FreeBSD-setup.
[localrules=10]
add path 'backlight/*' mode 0660 group video
add path 'dri/*'       mode 0660 group video
add path 'drm/*'       mode 0660 group video
add path 'video*'      mode 0660 group video
add path 'cuse'        mode 0660 group operator
add path 'ugen*'       mode 0660 group operator
add path 'usb/*'       mode 0660 group operator
add path 'da*'         mode 0660 group operator
add path 'cd*'         mode 0660 group operator
RULES
sysrc devfs_system_ruleset=localrules >/dev/null
is_live && { service devfs restart >> "$LOG" 2>&1 || true; }

# brightnessctl look-alike on top of backlight(8): Caelestia and many
# Wayland tools call brightnessctl.
install_file "$REPO_DIR/files/bin/brightnessctl" /usr/local/bin/brightnessctl 755
