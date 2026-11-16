# Stage: kde - KDE Plasma 6 (Wayland session, started by SDDM).

[ "$WANT_KDE" = yes ] || { say "KDE Plasma not selected - skipped"; return 0; }

say "KDE Plasma (several hundred packages; the longest download)"
if ! run_shown '^\[[0-9]+/[0-9]+\] (Fetching|Installing|Upgrading)' \
	env ASSUME_ALWAYS_YES=yes pkg install -y plasma6-plasma; then
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
# File search indexing (Baloo) off by default: on FreeBSD it watches files
# through kqueue, which keeps a file open per watched file and can run out of
# file handles. Dolphin's search still works, only more slowly. Turn it back
# on in System Settings > Search.
mkdir -p /usr/local/etc/xdg
[ -e /usr/local/etc/xdg/baloofilerc ] ||
	printf '# Written by FreeBSD-setup\n[Basic Settings]\nIndexing-Enabled=false\n' > /usr/local/etc/xdg/baloofilerc
say "KDE Plasma installed - choose 'Plasma (Wayland)' at the login screen"

true   # (a stage must not end on a failed test: setup.sh runs under set -e)
