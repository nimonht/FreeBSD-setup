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

# PulseAudio must not start its own server: pipewire-pulse is the server, and
# a PulseAudio started first (KDE's autostart, an app at login) wins the race
# and the volume applet then talks to the wrong one. A drop-in, so the
# package's client.conf stays untouched.
mkdir -p /usr/local/etc/pulse/client.conf.d
printf '# Written by FreeBSD-setup: pipewire-pulse is the sound server.\nautospawn = no\n' \
	> /usr/local/etc/pulse/client.conf.d/50-freebsd-setup.conf

# Laptop speakers vs headphones: pick the analog device automatically.
sysctl_set hw.snd.default_auto 1
say "list sound devices with 'cat /dev/sndstat'; choose one with 'sysctl hw.snd.default_unit=N'"

true   # (a stage must not end on a failed test: setup.sh runs under set -e)
