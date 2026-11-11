# Stage: kde - KDE Plasma 6 (Wayland session), only when DESKTOP is kde/both.

case "$DESKTOP" in kde|both) ;; *) say "DESKTOP=$DESKTOP - KDE skipped"; return 0 2>/dev/null || true ;; esac

say "KDE Plasma 6"
if ! env ASSUME_ALWAYS_YES=yes pkg install -y plasma6-plasma >> "$LOG" 2>&1; then
	warn "plasma6-plasma is not installable from the '$PKG_BRANCH' branch right now (it is rebuilt after Qt updates). Try again in a few days with: ./setup.sh kde   - or set PKG_BRANCH=quarterly"
	return 0 2>/dev/null || true
fi
pkg_try konsole dolphin kate ark gwenview okular plasma6-sddm-kcm plasma6-kde-gtk-config \
	plasma6-xdg-desktop-portal-kde
if [ "$DESKTOP" = kde ] || [ "$DISPLAY_MANAGER" = sddm ]; then
	pkg_install sddm
	sysrc sddm_enable=YES >/dev/null
fi
say "KDE installed - choose 'Plasma (Wayland)' at the login screen"
