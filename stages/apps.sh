# Stage: apps - everyday software. Edit the lists to taste.

[ "$DESKTOP" = none ] && return 0

if is_yes INSTALL_APPS; then
	say "browser, office, media"
	pkg_install firefox vlc
	pkg_try libreoffice thunderbird gimp keepassxc
	# LibreOffice in the desktop language, when a translation exists
	case "${DESKTOP_LANGUAGE:-}" in
	""|en) ;;
	*)	_lo=$DESKTOP_LANGUAGE
		case "$_lo" in pt-br) _lo=pt_BR ;; zh-cn) _lo=zh_CN ;; zh-tw) _lo=zh_TW ;; esac
		pkg_has "$_lo-libreoffice" && pkg_try "$_lo-libreoffice" ;;
	esac
fi

if is_yes INSTALL_DEVTOOLS; then
	say "developer tools"
	pkg_install git gmake cmake ninja pkgconf python3 node npm
	pkg_try vscode
fi
