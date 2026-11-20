# lib/branding.sh - the distribution's look: logo, wallpaper, boot menu
# name, "About this System", os-release. POSIX sh, sourced.
#
#   branding_apply [ROOT]   install it into the system at ROOT ("" = this
#                           one). Used by stages/branding.sh on installed
#                           systems and by iso/build.sh for the live image.
#
# Needs REPO_DIR (this repository) and distro.conf already read. Only files
# carrying the marker "Written by FreeBSD-setup" (or new ones) are written;
# a file of the owner's own with the same name is left alone.

# _br_put SRC DEST [MODE]   copy, unless DEST is someone else's file
_br_put() {
	if [ -f "$2" ] && ! grep -q 'Written by FreeBSD-setup' "$2" 2>/dev/null &&
		! cmp -s "$1" "$2"; then
		case "$2" in *.svg|*.jpg|*.png|*.txt|*/metadata.json) ;; *) return 0 ;; esac
	fi
	mkdir -p "$(dirname "$2")"
	install -m "${3:-644}" "$1" "$2"
}

# _br_kv FILE KEY VALUE   loader.conf-style KEY="VALUE", replaced or added
_br_kv() {
	touch "$1"
	if grep -q "^$2=" "$1"; then
		sed -i '' "s|^$2=.*|$2=\"$3\"|" "$1" 2>/dev/null || sed -i "s|^$2=.*|$2=\"$3\"|" "$1"
	else
		printf '%s="%s"\n' "$2" "$3" >> "$1"
	fi
}

branding_apply() {
	_r=${1:-}
	_b="$REPO_DIR/branding"
	_s="$_r/usr/local/share/$DISTRO_ID"
	mkdir -p "$_s"
	for _f in logo.svg logo-reverse.svg logo-small.svg lockup.svg lockup-reverse.svg wordmark.svg \
		wallpaper.jpg wallpaper-night.jpg; do
		_br_put "$_b/lunabsd-$_f" "$_s/$DISTRO_ID-$_f"
	done
	_br_put "$_b/fastfetch-logo.txt" "$_s/fastfetch-logo.txt"
	# The logo under its icon name too (os-release LOGO=, KDE About).
	_br_put "$_b/lunabsd-logo.svg" "$_r/usr/local/share/icons/hicolor/scalable/apps/$DISTRO_ID.svg"
	_br_put "$_b/lunabsd-logo.svg" "$_r/usr/local/share/pixmaps/$DISTRO_ID.svg"

	# Wallpaper as a Plasma wallpaper package (parchment by day; Plasma
	# shows images_dark/ with a dark colour scheme), and the one-time script
	# that puts it on desktops still showing Plasma's default.
	_w="$_r/usr/local/share/wallpapers/LunaBSD"
	_br_put "$_b/plasma/metadata.json" "$_w/metadata.json"
	_br_put "$_b/lunabsd-wallpaper.jpg" "$_w/contents/images/3840x2160.jpg"
	_br_put "$_b/lunabsd-wallpaper-night.jpg" "$_w/contents/images_dark/3840x2160.jpg"
	_br_put "$_b/lunabsd-wallpaper-preview.jpg" "$_w/contents/screenshot.jpg"
	_br_put "$_b/plasma/lunabsd-wallpaper.js" \
		"$_r/usr/local/share/plasma/shells/org.kde.plasma.desktop/contents/updates/lunabsd-wallpaper.js"

	# KDE's "About this System". /etc/xdg comes before /usr/local/etc/xdg,
	# where the kinfocenter package puts FreeBSD's.
	mkdir -p "$_r/etc/xdg"
	_t=$(mktemp) || return 1
	cat > "$_t" <<ABOUT
# Written by FreeBSD-setup: KDE's "About this System" page.
[General]
Name=$DISTRO_NAME
LogoPath=/usr/local/share/$DISTRO_ID/$DISTRO_ID-logo.svg
Website=$DISTRO_URL
Variant=$DISTRO_CODENAME
ABOUT
	_br_put "$_t" "$_r/etc/xdg/kcm-about-distrorc"
	rm -f "$_t"

	# Login screen background (SDDM's Breeze theme reads theme.conf.user).
	_sd="$_r/usr/local/share/sddm/themes/breeze"
	if [ -d "$_sd" ]; then
		_t=$(mktemp) || return 1
		printf '# Written by FreeBSD-setup: LunaBSD login screen background.\n[General]\nbackground=/usr/local/share/%s/%s-wallpaper.jpg\n' \
			"$DISTRO_ID" "$DISTRO_ID" > "$_t"
		_br_put "$_t" "$_sd/theme.conf.user"
		rm -f "$_t"
	fi

	# Boot menu: the LunaBSD name and sunrise (FreeBSD's loader, our art).
	_br_put "$_b/loader/brand-luna.lua" "$_r/boot/lua/brand-luna.lua" 444
	_br_put "$_b/loader/logo-luna.lua" "$_r/boot/lua/logo-luna.lua" 444
	# the same as pictures, for framebuffer consoles (UEFI)
	_br_put "$_b/loader/lunabsd-brand.png" "$_r/boot/images/lunabsd-brand.png" 444
	_br_put "$_b/loader/lunabsd-logo.png" "$_r/boot/images/lunabsd-logo.png" 444
	if [ -z "${BRANDING_NO_LOADER_CONF:-}" ]; then
		_br_kv "$_r/boot/loader.conf" loader_brand luna
		_br_kv "$_r/boot/loader.conf" loader_logo luna
	fi

	# os-release names the distribution (FreeBSD's version stays in it).
	_br_put "$REPO_DIR/files/rc.d/lunabsd_osrelease" "$_r/usr/local/etc/rc.d/lunabsd_osrelease" 755
	return 0
}
