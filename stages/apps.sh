# Stage: apps - everyday software. Edit the lists to taste.

[ "$DESKTOP" = none ] && return 0

if is_yes INSTALL_APPS; then
	say "browser, office, media"
	pkg_install firefox vlc
	# Firefox privacy defaults: no telemetry, studies, sponsored tiles or
	# recommendation pop-ups (all can still be changed in Firefox).
	sys_file "$REPO_DIR/files/firefox/policies.json" /etc/firefox/policies/policies.json || true
	pkg_try libreoffice thunderbird gimp keepassxc
	# LibreOffice in the desktop language, when a translation exists
	case "${DESKTOP_LANGUAGE:-}" in
	""|en) ;;
	*)	_lo=$DESKTOP_LANGUAGE
		case "$_lo" in pt-br) _lo=pt_BR ;; zh-cn) _lo=zh_CN ;; zh-tw) _lo=zh_TW ;; esac
		if pkg_has "$_lo-libreoffice"; then pkg_try "$_lo-libreoffice"; fi ;;
	esac
fi

if is_yes INSTALL_DEVTOOLS; then
	say "developer tools"
	pkg_install git gmake cmake ninja pkgconf python3 node npm
	pkg_try vscode
fi

true   # (a stage must not end on a failed test: setup.sh runs under set -e)
