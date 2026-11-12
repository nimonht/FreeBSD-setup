# Stage: printing - CUPS, driverless network printers (IPP Everywhere /
# AirPrint) found through mDNS, and scanners through SANE.

is_yes INSTALL_PRINTING || { say "printing not selected - skipped"; return 0; }

say "CUPS printing system and drivers"
pkg_install cups cups-filters gutenprint avahi-app nss_mdns sane-backends sane-airscan
svc avahi_daemon avahi-daemon
svc cupsd
pw groupmod cups -m "$TARGET_USER" 2>/dev/null || true

# Let programs resolve printer.local names from the network.
if ! grep -q 'mdns' /etc/nsswitch.conf; then
	sed -i '' 's/^hosts:.*/hosts: files dns mdns/' /etc/nsswitch.conf
fi

# Graphical printer setup for desktops other than KDE (KDE gets its own).
if [ "$WANT_HYPR" = yes ]; then
	pkg_try system-config-printer simple-scan
fi
say "printers: open http://localhost:631 or your desktop's printer settings; most network printers are found automatically"
