# Stage: apps - everyday software. Edit the lists to taste.

[ "$DESKTOP" = none ] && return 0

if is_yes INSTALL_APPS; then
	say "browser, office, media"
	pkg_install firefox vlc
	# Firefox privacy defaults: no telemetry, studies, sponsored tiles or
	# recommendation pop-ups (all can still be changed in Firefox).
	# In the desktop language when it is not English: Firefox then asks for
	# and installs its language pack on first start.
	_ffl=""
	case "${DESKTOP_LANGUAGE:-}" in
	""|en) ;;
	pt-br) _ffl=pt-BR ;; zh-cn) _ffl=zh-CN ;; zh-tw) _ffl=zh-TW ;; ja) _ffl=ja ;;
	*) _ffl=$DESKTOP_LANGUAGE ;;
	esac
	_ffp=$(mktemp)
	if [ -n "$_ffl" ] && command -v jq >/dev/null &&
		jq --arg l "$_ffl" '.policies.RequestedLocales = [$l]
			| .policies.ExtensionSettings = {("langpack-" + $l + "@firefox.mozilla.org"): {
				installation_mode: "normal_installed",
				install_url: ("https://addons.mozilla.org/firefox/downloads/latest/langpack-" + $l + "@firefox.mozilla.org/latest.xpi")}}' \
			"$REPO_DIR/files/firefox/policies.json" > "$_ffp"; then :
	else cp "$REPO_DIR/files/firefox/policies.json" "$_ffp"; fi
	sys_file "$_ffp" /etc/firefox/policies/policies.json || true
	rm -f "$_ffp"
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
