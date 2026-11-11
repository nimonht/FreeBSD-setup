# Stage: desktop - Hyprland, portals, tools, fonts, themes, login manager.

if [ "$DESKTOP" = kde ]; then
	say "DESKTOP=kde: Hyprland not installed"
else
	say "Hyprland and companions"
	pkg_install hyprland hyprlock hypridle hyprpaper hyprpicker hyprpolkitagent \
		xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
		qt6-wayland qt5-wayland qt6ct \
		foot fuzzel wl-clipboard cliphist grim slurp swappy wf-recorder libnotify \
		thunar gvfs polkit polkit-gnome gnome-keyring gammastep \
		xdg-user-dirs xdg-utils wlr-randr ydotool

	install -m 755 "$REPO_DIR/files/bin/hypr-session" /usr/local/bin/hypr-session
	mkdir -p /usr/local/share/wayland-sessions
	cat > /usr/local/share/wayland-sessions/hypr-session.desktop <<'DESK'
[Desktop Entry]
Name=Hyprland (Caelestia)
Comment=Hyprland with the FreeBSD-setup session environment
Exec=/usr/local/bin/hypr-session
Type=Application
DesktopNames=Hyprland
DESK
fi

say "fonts, icons, cursors"
pkg_install noto-basic noto-emoji noto-extra nerd-fonts-jetbrainsmono \
	nerd-fonts-caskaydiacove material-icons-ttf liberation-fonts-ttf dejavu \
	papirus-icon-theme bibata-cursor-theme nwg-look
pkg_try rubik cantarell-fonts webfonts

say "shell tools"
pkg_install fish starship eza zoxide direnv btop fastfetch micro bat ripgrep \
	lazygit py312-trash-cli
as_user 'xdg-user-dirs-update' >> "$LOG" 2>&1 || true

# ---- login manager ---------------------------------------------------------
dm="$DISPLAY_MANAGER"
[ "$DESKTOP" = kde ] && [ "$dm" = ly ] && dm=sddm
case "$dm" in
ly)
	pkg_install ly
	say "login manager: ly on ttyv1"
	if ! grep -q '^Ly:' /etc/gettytab; then
		cat >> /etc/gettytab <<'TAB'

# ly display manager (FreeBSD-setup)
Ly:\
	:lo=/usr/local/bin/ly_wrapper:\
	:al=root:
TAB
	fi
	# ttyv1 runs ly instead of a login prompt; ttyv0 and ttyv2+ stay as consoles.
	sed -i '' -E 's|^ttyv1[[:space:]]+"/usr/libexec/getty Pc"[[:space:]]+xterm[[:space:]]+on(ifexists)?[[:space:]]+secure|ttyv1	"/usr/libexec/getty Ly"		xterm	on  secure|' /etc/ttys
	grep -q 'getty Ly' /etc/ttys || warn "could not switch ttyv1 to ly in /etc/ttys - edit it by hand (see README)"
	sysrc sddm_enable=NO >/dev/null 2>&1 || true
	;;
sddm)
	pkg_install sddm
	sysrc sddm_enable=YES >/dev/null
	say "login manager: sddm"
	;;
none)
	say "no login manager: log in on the console and run 'hypr-session'"
	;;
*)	warn "unknown DISPLAY_MANAGER '$DISPLAY_MANAGER' - none configured" ;;
esac
