# Stage: system - laptop tuning for an Intel (Kaby Lake) ASUS ROG laptop.

say "boot loader settings (/boot/loader.conf)"
loader_set coretemp_load YES            # CPU temperature sensors
loader_set acpi_asus_wmi_load YES       # ASUS hotkeys / keyboard backlight
loader_set ig4_load YES                 # Intel I2C controller ...
loader_set iichid_load YES              # ... for the I2C HID touchpad
loader_set cpuctl_load YES
loader_set hw.usb.usbhid.enable 1       # modern HID stack (multitouch, evdev)
loader_set kern.ipc.shmseg 1024
loader_set kern.ipc.shmmni 1024
loader_set autoboot_delay 3

pkg_install cpu-microcode-intel
loader_set cpu_microcode_load YES
loader_set cpu_microcode_name /boot/firmware/intel-ucode.bin

say "kernel tunables (/etc/sysctl.conf)"
sysctl_set vfs.usermount 1                      # users may mount USB sticks
sysctl_set kern.coredump 0
sysctl_set kern.evdev.rcpt_mask 6               # route keyboard/mouse through evdev
sysctl_set hw.acpi.power_button_state S5
sysctl_set security.bsd.unprivileged_chroot 1   # needed by the Steam runtime (bwrap replacement)

say "services (/etc/rc.conf)"
pkg_install dbus seatd
sysrc dbus_enable=YES seatd_enable=YES >/dev/null
sysrc powerd_enable=YES powerd_flags="-a hiadaptive -b adaptive -n adaptive" >/dev/null
sysrc performance_cx_lowest=Cmax economy_cx_lowest=Cmax >/dev/null
sysrc ntpd_enable=YES ntpd_sync_on_start=YES >/dev/null
sysrc clear_tmp_enable=YES >/dev/null
kld_add fusefs
service dbus status >/dev/null 2>&1 || service dbus start >> "$LOG" 2>&1 || true
service seatd status >/dev/null 2>&1 || service seatd start >> "$LOG" 2>&1 || true

# /proc and /dev/fd are expected by a lot of desktop software.
add_line /etc/fstab "proc	/proc	procfs	rw	0	0"
add_line /etc/fstab "fdescfs	/dev/fd	fdescfs	rw	0	0"
mount /proc 2>/dev/null || true
mount /dev/fd 2>/dev/null || true

# Screen backlight: let the video group change it without root.
cat > /etc/devfs.rules <<'RULES'
[localrules=10]
add path 'backlight/*' mode 0660 group video
add path 'dri/*'       mode 0660 group video
add path 'drm/*'       mode 0660 group video
add path 'video*'      mode 0660 group video
add path 'cuse'        mode 0660 group operator
RULES
sysrc devfs_system_ruleset=localrules >/dev/null
service devfs restart >> "$LOG" 2>&1 || true

# A brightnessctl look-alike on top of backlight(8) - Caelestia and most
# Hyprland configs call brightnessctl.
install -m 755 "$REPO_DIR/files/bin/brightnessctl" /usr/local/bin/brightnessctl
