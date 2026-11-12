# Stage: kde - KDE Plasma 6 (Wayland session, started by SDDM).

[ "$WANT_KDE" = yes ] || { say "KDE Plasma not selected - skipped"; return 0; }

say "KDE Plasma"
if ! env ASSUME_ALWAYS_YES=yes pkg install -y plasma6-plasma >> "$LOG" 2>&1; then
	warn "KDE Plasma (plasma6-plasma) cannot be installed from the '$PKG_BRANCH' package branch right now - FreeBSD rebuilds it after big updates. Try again in a few days: doas freebsd-setup kde"
	return 0
fi
pkg_try plasma6-xdg-desktop-portal-kde plasma6-sddm-kcm plasma6-kde-gtk-config \
	plasma6-spectacle konsole dolphin kate ark gwenview okular kcalc
is_yes INSTALL_PRINTING && pkg_try plasma6-print-manager skanlite

# Plasma's language and keyboard settings for the user (only when unset).
_cfg="$TARGET_HOME/.config"
mkdir -p "$_cfg"
if [ -n "${KEYBOARD_LAYOUT:-}" ] && [ ! -f "$_cfg/kxkbrc" ]; then
	_xkb=$KEYBOARD_LAYOUT _var=""
	case "$_xkb" in us-intl) _xkb=us _var=intl ;; esac
	printf '[Layout]\nLayoutList=%s\nVariantList=%s\nUse=true\n' "$_xkb" "$_var" > "$_cfg/kxkbrc"
fi
case "${DESKTOP_LANGUAGE:-}" in
""|en) ;;
*)	if [ ! -f "$_cfg/plasma-localerc" ]; then
		_l=$DESKTOP_LANGUAGE
		case "$_l" in pt-br) _l=pt_BR ;; zh-cn) _l=zh_CN ;; zh-tw) _l=zh_TW ;; esac
		printf '[Translations]\nLANGUAGE=%s\n' "$_l" > "$_cfg/plasma-localerc"
	fi ;;
esac
chown -R "$TARGET_USER" "$_cfg"
say "KDE Plasma installed - choose 'Plasma (Wayland)' at the login screen"
