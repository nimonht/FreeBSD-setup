# Stage: audio - PipeWire + WirePlumber on top of FreeBSD's OSS sound system.
# (pipewire-spa-oss is the OSS backend; pipewire-pulse serves PulseAudio apps.)

[ "$DESKTOP" = none ] && { say "no desktop - PipeWire skipped (console programs use OSS directly)"; return 0; }

pkg_install pipewire wireplumber pipewire-spa-oss pavucontrol pamixer playerctl \
	gstreamer1-plugins-good gstreamer1-libav ffmpeg

# FreeBSD has no systemd user session, so the desktop session starts PipeWire.
install_file "$REPO_DIR/files/bin/start-pipewire" /usr/local/bin/start-pipewire 755
mkdir -p /usr/local/etc/xdg/autostart
cat > /usr/local/etc/xdg/autostart/start-pipewire.desktop <<'DESK'
[Desktop Entry]
Type=Application
Name=PipeWire audio
Exec=/usr/local/bin/start-pipewire
NoDisplay=true
X-KDE-autostart-phase=1
DESK

# Laptop speakers vs headphones: pick the analog device automatically.
sysctl_set hw.snd.default_auto 1
say "list sound devices with 'cat /dev/sndstat'; choose one with 'sysctl hw.snd.default_unit=N'"
