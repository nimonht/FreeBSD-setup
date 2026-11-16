#!/bin/sh
#
# tests/desktop-probe.sh - record what the desktop can and cannot see on this
# machine: power settings, sensors, sleep, network, Bluetooth, D-Bus services
# and the desktop logs. Used to plan fixes for controls that are missing or
# broken, and to build test fixtures for machines the developers do not have.
#
# Run it as your normal user, in a terminal INSIDE the desktop (KDE Plasma or
# Hyprland), once in each desktop you use:
#
#   sh desktop-probe.sh
#
# It asks for your password (doas) for the parts only root can read.
# The result is one file, saved to the EFI partition (shared with Linux and
# Windows on the same disk) and to /tmp. Network names, hardware addresses
# and serial numbers are removed. Nothing is changed on the system.
set -u
STAMP=$(date +%Y%m%d-%H%M%S)
SESSION=${XDG_CURRENT_DESKTOP:-none}
NAME="fbs-probe-$(echo "$SESSION" | tr -c 'A-Za-z0-9\n' '_')-$STAMP"

# Remove MAC addresses, Wi-Fi network names, serial numbers and UUIDs.
redact() {
	sed -E \
		-e 's/([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}/xx:xx:xx:xx:xx:xx/g' \
		-e 's/ssid .* channel/ssid <ssid> channel/' \
		-e 's/(ssid[=:" ]+)[^ ,"]+/\1<ssid>/Ig' \
		-e 's/(psk|password|passwd|wep_key[0-9]?)([=:" ]+)[^ ,"]+/\1\2<secret>/Ig' \
		-e 's/(serial[^=:]*[=:] *)[^ ]+/\1<serial>/Ig' \
		-e 's/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/<uuid>/g'
}

# section TITLE COMMAND...   run a command, record its output and exit status
section() {
	_t=$1; shift
	printf '\n===== %s\n$ %s\n' "$_t" "$*"
	"$@" 2>&1 | head -n 400
	printf '[exit %s]\n' "$?"
}
sec_sh() { section "$1" sh -c "$2"; }

# dbus NAME_OF_BUS   list the D-Bus names that are running and that can be started
dbus_names() {
	_b=$1
	for m in ListNames ListActivatableNames; do
		printf -- '-- %s %s\n' "$_b" "$m"
		dbus-send --"$_b" --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
			"org.freedesktop.DBus.$m" 2>&1 | sed -n 's/.*string "\(.*\)"/\1/p' | grep -v '^:' | sort
	done
}

# introspect BUS DEST PATH   the interfaces/properties a service offers
introspect() {
	dbus-send --"$1" --print-reply --dest="$2" "$3" org.freedesktop.DBus.Introspectable.Introspect 2>&1 |
		grep -E '<(interface|method|property|node) ' | head -n 80
}

root_part() {
	sec_sh "battery (acpiconf)" 'for u in 0 1; do acpiconf -i $u 2>/dev/null; done'
	sec_sh "rc.conf (desktop-related)" 'sysrc -a | grep -E "^(powerd|powerdxx|performance|economy|wlans_|ifconfig_|create_args_|hcsecd|sdpd|bthidd|ubt|dbus|sddm|seatd|upower|consolekit|moused|ntpd|kld_list|cupsd|pf_)"'
	sec_sh "loader.conf" 'grep -v "^#" /boot/loader.conf | grep .'
	sec_sh "wpa_cli status" 'wpa_cli status 2>&1; wpa_cli list_networks 2>&1 | awk -F "\t" "{print \$1, \"<ssid>\", \$3, \$4}" | head -20'
	sec_sh "doas/sudo rules" 'cat /usr/local/etc/doas.conf 2>/dev/null; ls /usr/local/etc/sudoers.d 2>/dev/null; cat /usr/local/etc/sudoers.d/* 2>/dev/null | grep -v "^#"'
	sec_sh "polkit rules" 'ls -l /usr/local/etc/polkit-1/rules.d /usr/local/share/polkit-1/rules.d 2>/dev/null'
	sec_sh "Bluetooth controller" 'hccontrol -n ubt0hci read_local_version_information 2>&1; hccontrol -n ubt0hci read_local_supported_features 2>&1 | head -20'
	sec_sh "freebsd-setup log: warnings" 'grep -n -E "WARNING|ERROR|failed" /var/log/freebsd-setup.log | tail -60'
	sec_sh "SDDM / X log errors" 'grep -h -E "\(EE\)|\(WW\)" /var/log/Xorg.0.log 2>/dev/null | head -40; tail -40 /var/log/sddm.log 2>/dev/null'
	sec_sh "kernel messages (errors)" 'dmesg | grep -i -E "error|fail|timeout|unsupported|not found|firmware" | tail -60'
}

if [ "${1:-}" = --root-part ]; then
	root_part
	exit 0
fi

OUT="/tmp/$NAME.txt"
{
	printf 'desktop-probe %s  session=%s  wayland=%s  user=%s\n' "$STAMP" "$SESSION" "${WAYLAND_DISPLAY:-}" "$(id -un)"
	section "system" uname -a
	sec_sh "machine" 'kenv -q smbios.system.maker; kenv -q smbios.system.product; sysctl -n hw.model hw.ncpu hw.physmem'
	section "kernel modules" kldstat
	sec_sh "session environment" 'env | grep -E "^(XDG_|WAYLAND|DISPLAY|DESKTOP_SESSION|KDE_|QT_QPA|HYPRLAND_INSTANCE|DBUS_SESSION)" | sort'
	sec_sh "sessions (ConsoleKit2)" 'ck-list-sessions 2>&1 | head -30'

	# --- power and CPU ---------------------------------------------------------
	sec_sh "CPU power: Intel HWP" 'sysctl dev.hwpstate_intel 2>&1 | head -40; sysctl machdep.hwpstate_pkg_ctrl 2>&1'
	sec_sh "CPU power: AMD" 'sysctl dev.hwpstate 2>&1 | head -20; sysctl dev.amdtemp 2>&1 | head -10'
	sec_sh "CPU frequencies" 'sysctl dev.cpu.0 2>&1 | grep -v "%"; sysctl dev.cpufreq 2>&1 | head -20'
	sec_sh "powerd" 'pgrep -l -f "powerd" ; ps -o args= -p "$(pgrep -d, powerd 2>/dev/null)" 2>/dev/null'
	sec_sh "ACPI" 'sysctl hw.acpi 2>&1 | grep -v -i serial'
	sec_sh "ACPI devices (laptop extras)" 'sysctl dev.acpi_asus dev.acpi_asus_wmi dev.acpi_ibm dev.acpi_video dev.acpi_wmi 2>&1 | head -60'
	sec_sh "scheduler" 'sysctl kern.sched 2>&1 | grep -v "kern.sched.topology_spec"'

	# --- sensors ------------------------------------------------------------------
	sec_sh "temperatures and fans" 'sysctl -a 2>/dev/null | grep -i -E "temperature|thermal|fan|tz[0-9]" | head -60'
	sec_sh "backlight" 'backlight -l 2>&1; for b in /dev/backlight/*; do backlight -f "$b" 2>&1; done'

	# --- network ------------------------------------------------------------------
	sec_sh "interfaces" 'ifconfig -a | grep -v -E "inet6 fe80|nd6 options"'
	sec_sh "Wi-Fi scan (cached)" 'for w in $(ifconfig -l | tr " " "\n" | grep "^wlan"); do ifconfig "$w" list scan 2>&1 | awk "NR==1{print; next}{print \"<network>\", substr(\$0, 34)}" | cut -c1-200 | head -15; done'
	sec_sh "network processes" 'ps -axo user,pid,args | grep -E "wpa_supplicant|dhclient|dhcpcd|networkmgr|wifimgr|nm-applet|NetworkManager" | grep -v grep'
	sec_sh "NetworkMgr install" 'pkg info -l networkmgr 2>&1 | grep -E "\.desktop|bin/|sudoers|share/networkmgr" ; cat /usr/local/etc/xdg/autostart/networkmgr.desktop 2>/dev/null'

	# --- Bluetooth -------------------------------------------------------------------
	sec_sh "Bluetooth" 'usbconfig list 2>&1; kldstat | grep -E "ng_|ubt"; ls /dev | grep -i -E "ubt|bt" ; service -e | grep -E "hcsecd|sdpd|bthidd|bluetooth"'

	# --- sleep -------------------------------------------------------------------------
	sec_sh "sleep" 'sysctl hw.acpi.supported_sleep_state hw.acpi.suspend_state hw.acpi.lid_switch_state hw.acpi.sleep_button_state hw.acpi.power_button_state 2>&1'

	# --- D-Bus -------------------------------------------------------------------------
	printf '\n===== D-Bus names\n'
	dbus_names system
	dbus_names session
	printf '\n===== D-Bus: do these services answer?\n'
	for s in org.freedesktop.UPower net.hadess.PowerProfiles org.freedesktop.UPower.PowerProfiles \
		org.freedesktop.NetworkManager org.bluez org.freedesktop.ConsoleKit org.freedesktop.login1 \
		org.freedesktop.PolicyKit1 org.freedesktop.hostname1 org.freedesktop.timedate1 org.freedesktop.locale1 \
		org.freedesktop.Accounts org.freedesktop.UDisks2 org.freedesktop.PackageKit org.freedesktop.fwupd; do
		if dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
			org.freedesktop.DBus.NameHasOwner "string:$s" 2>/dev/null | grep -q 'boolean true'; then
			printf 'running      %s\n' "$s"
		elif dbus-send --system --print-reply --dest=org.freedesktop.DBus /org/freedesktop/DBus \
			org.freedesktop.DBus.ListActivatableNames 2>/dev/null | grep -q "\"$s\""; then
			printf 'startable    %s\n' "$s"
		else
			printf 'MISSING      %s\n' "$s"
		fi
	done
	sec_sh "UPower devices" 'upower -d 2>&1 | head -80'
	printf '\n===== ConsoleKit2: can the session sleep?\n'
	for m in CanSuspend CanHibernate CanHybridSleep CanPowerOff CanReboot; do
		printf '%s: ' "$m"
		dbus-send --system --print-reply --dest=org.freedesktop.ConsoleKit /org/freedesktop/ConsoleKit/Manager \
			"org.freedesktop.ConsoleKit.Manager.$m" 2>&1 | sed -n 's/.*string "\(.*\)"/\1/p;s/.*Error.*/&/p'
	done
	printf '\n===== UPower introspection\n'
	introspect system org.freedesktop.UPower /org/freedesktop/UPower

	# --- KDE ---------------------------------------------------------------------------
	sec_sh "KDE sensors (kstatsviewer)" 'command -v kstatsviewer >/dev/null && timeout 20 kstatsviewer --list 2>&1 | head -300 || echo "kstatsviewer not installed"'
	sec_sh "KDE system monitor backends" 'pkg info -l plasma6-ksystemstats plasma6-libksysguard 2>/dev/null | grep -E "\.so" '
	sec_sh "/proc" 'mount | grep -E "procfs|linprocfs|fdescfs"; ls /proc | head -5'
	sec_sh "Discover backends" 'pkg info -l plasma6-discover 2>/dev/null | grep -i -E "backend|\.so" | head -20'

	# --- Caelestia ----------------------------------------------------------------------
	sec_sh "Caelestia config" 'ls -la ~/.config/caelestia 2>&1; cat ~/.config/caelestia/shell.json 2>/dev/null | head -80'
	sec_sh "Caelestia / Quickshell log (warnings)" 'timeout 15 qs log -c caelestia 2>&1 | grep -i -E "warn|error|fail|not found|cannot|unable" | sort | uniq -c | sort -rn | head -80'

	# --- packages ------------------------------------------------------------------------
	sec_sh "packages" 'pkg query "%n %v" | grep -E "^(plasma6-(powerdevil|ksystemstats|libksysguard|plasma-systemmonitor|discover|bluedevil|plasma-nm|kinfocenter)|kf6-(bluez-qt|networkmanager-qt|solid)|quickshell|upower|consolekit2|polkit|networkmgr|wifimgr|powerd|virtual_oss|hyprland|sddm|xdg-desktop-portal)" '
	sec_sh "package repositories" 'pkg -vv 2>/dev/null | sed -n "/Repositories:/,\$p" | grep -E "url|enabled|^  [A-Za-z]"'

	printf '\n===== root-only parts (asks for your password)\n'
	if [ "$(id -u)" = 0 ]; then root_part
	elif [ ! -t 0 ]; then echo "skipped: not run from a terminal, so the password cannot be asked"
	elif command -v doas >/dev/null; then doas sh "$0" --root-part
	else su root -c "sh '$0' --root-part"
	fi
} 2>&1 | redact > "$OUT"

# Save to the EFI partition so the file can be read from Linux on the same disk.
_esp=""
for d in /boot/efi /efi; do mount -p | awk '{print $2}' | grep -qx "$d" && { _esp=$d; break; }; done
if [ -n "$_esp" ]; then
	if [ "$(id -u)" = 0 ]; then mkdir -p "$_esp/fbs-probe" && cp "$OUT" "$_esp/fbs-probe/"
	elif [ -t 0 ] && command -v doas >/dev/null; then doas sh -c "mkdir -p '$_esp/fbs-probe' && cp '$OUT' '$_esp/fbs-probe/'"
	else false
	fi && echo "Saved: $_esp/fbs-probe/$NAME.txt (from Linux on this disk: /boot/fbs-probe or /boot/efi/fbs-probe)"
fi
echo "Saved: $OUT"
