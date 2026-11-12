# Stage: input - fcitx5 input methods for typing Vietnamese, Chinese,
# Japanese, Korean and other scripts. Toggle with Ctrl+Space.

[ "$DESKTOP" = none ] && return 0
[ -n "$INPUT_METHODS" ] || { say "no extra input methods selected - skipped"; return 0; }

say "fcitx5 with: $INPUT_METHODS"
pkg_install fcitx5 fcitx5-configtool fcitx5-qt6 fcitx5-qt5 fcitx5-gtk3 fcitx5-gtk4
_ims=""
for _m in $INPUT_METHODS; do
	case "$_m" in
	vi)    pkg_install fcitx5-m17n m17n-db; _ims="$_ims m17n_vi_telex m17n_vi_vni" ;;
	m17n)  pkg_install fcitx5-m17n m17n-db ;;
	zh-cn) pkg_install zh-fcitx5-rime zh-rime-luna-pinyin zh-rime-prelude zh-rime-essay; _ims="$_ims rime" ;;
	zh-tw) pkg_install zh-fcitx5-chewing; _ims="$_ims chewing" ;;
	ja)    if pkg_has ja-fcitx5-mozc; then pkg_install ja-fcitx5-mozc; _ims="$_ims mozc"
	       else pkg_install ja-fcitx5-anthy; _ims="$_ims anthy"; fi ;;
	ko)    pkg_install ko-fcitx5-hangul; _ims="$_ims hangul" ;;
	*)     warn "unknown input method '$_m' (use vi, zh-cn, zh-tw, ja, ko, m17n)" ;;
	esac
done

# Start fcitx5 with the session and route programs to it.
mkdir -p /usr/local/etc/xdg/autostart
[ -f /usr/local/share/applications/org.fcitx.Fcitx5.desktop ] &&
	cp /usr/local/share/applications/org.fcitx.Fcitx5.desktop /usr/local/etc/xdg/autostart/
mkdir -p /usr/local/etc/profile.d
cat > /usr/local/etc/profile.d/fcitx5.sh <<'ENV'
# Written by FreeBSD-setup: input methods for X11/Wayland programs.
export XMODIFIERS=@im=fcitx
export QT_IM_MODULE=fcitx
export SDL_IM_MODULE=fcitx
ENV

# KDE Plasma (Wayland) hands keyboard input to fcitx5 itself.
_cfg="$TARGET_HOME/.config"
mkdir -p "$_cfg/fcitx5"
if [ "$WANT_KDE" = yes ] && ! grep -qs 'InputMethod' "$_cfg/kwinrc"; then
	printf '\n[Wayland]\nInputMethod=/usr/local/share/applications/org.fcitx.Fcitx5.desktop\n' >> "$_cfg/kwinrc"
fi
# A ready-made profile: your keyboard layout first, then the chosen methods.
if [ ! -f "$_cfg/fcitx5/profile" ]; then
	_kb="keyboard-${KEYBOARD_LAYOUT:-us}"
	case "$_kb" in keyboard-us-intl) _kb=keyboard-us-intl ;; esac
	{
		printf '[Groups/0]\nName=Default\nDefault Layout=%s\nDefaultIM=%s\n\n' "${KEYBOARD_LAYOUT:-us}" "$_kb"
		printf '[Groups/0/Items/0]\nName=%s\nLayout=\n\n' "$_kb"
		_i=1
		for _im in $_ims; do
			printf '[Groups/0/Items/%d]\nName=%s\nLayout=\n\n' "$_i" "$_im"
			_i=$((_i + 1))
		done
		printf '[GroupOrder]\n0=Default\n'
	} > "$_cfg/fcitx5/profile"
fi
chown -R "$TARGET_USER" "$_cfg"
