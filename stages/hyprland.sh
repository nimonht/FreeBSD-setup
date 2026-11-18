# Stage: hyprland - Hyprland, the tools its desktop relies on, and a session
# launcher that sets up the environment FreeBSD needs.

[ "$WANT_HYPR" = yes ] || { say "Hyprland not selected - skipped"; return 0; }

say "Hyprland and companions"
pkg_install seatd hyprland hyprlock hypridle hyprpaper hyprpicker hyprpolkitagent \
	xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
	qt6-wayland qt5-wayland qt6ct \
	foot fuzzel wl-clipboard cliphist grim slurp swappy wf-recorder libnotify \
	thunar gvfs polkit-gnome gnome-keyring gammastep wlr-randr ydotool \
	unix-selfauth-helper
svc seatd

say "fonts, icons and cursors used by the Hyprland setup"
pkg_install nerd-fonts-jetbrainsmono nerd-fonts-caskaydiacove material-icons-ttf \
	papirus-icon-theme bibata-cursor-theme nwg-look
pkg_try rubik

say "shell tools"
pkg_install fish starship eza zoxide direnv btop micro bat ripgrep lazygit py312-trash-cli

install_file "$REPO_DIR/files/bin/hypr-session" /usr/local/bin/hypr-session 755
mkdir -p /usr/local/share/wayland-sessions
cat > /usr/local/share/wayland-sessions/hypr-session.desktop <<'DESK'
[Desktop Entry]
Name=Hyprland
Comment=Hyprland with the environment FreeBSD needs (FreeBSD-setup)
Exec=/usr/local/bin/hypr-session
Type=Application
DesktopNames=Hyprland
DESK
# The plain entry from the Hyprland package misses that environment: hide it.
_hd=/usr/local/share/wayland-sessions/hyprland.desktop
[ -f "$_hd" ] && ! grep -q '^NoDisplay=true' "$_hd" && echo 'NoDisplay=true' >> "$_hd"
true
