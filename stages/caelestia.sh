# Stage: caelestia - build the Caelestia shell + CLI for FreeBSD and install
# the Caelestia dotfiles for the desktop user.

if [ "$WANT_HYPR" != yes ] || ! yes INSTALL_CAELESTIA; then
	say "Caelestia not selected - skipped"
	return 0
fi

say "build dependencies"
pkg_install quickshell cmake ninja pkgconf git python313 \
	qt6-base qt6-declarative qt6-imageformats qt6-multimedia qt6-svg \
	qt6-wayland qt6-5compat qt6-shadertools \
	libqalculate aubio fftw3 pipewire libxml2 \
	jpeg-turbo png freetype2 lcms2 webp tiff openjpeg

# The plugin reads CPU/memory/network statistics through linprocfs.
svc linux

say "building (logs in /var/tmp/caelestia-build/*.log) - 10 to 30 minutes"
_rcf=$(mktemp)
{ env SHELL_REF="$CAELESTIA_SHELL_REF" CLI_REF="$CAELESTIA_CLI_REF" \
	sh "$REPO_DIR/caelestia/build.sh"; echo $? > "$_rcf"; } 2>&1 | tee -a "$LOG"
_rc=$(cat "$_rcf"); rm -f "$_rcf"
if [ "$_rc" != 0 ] || [ ! -x /usr/local/bin/caelestia ] || [ ! -d /usr/local/etc/xdg/quickshell/caelestia ]; then
	warn "the Caelestia build failed. Hyprland still works with its default look; see docs/TROUBLESHOOTING.md (Caelestia) and re-run: doas freebsd-setup caelestia"
	return 0
fi

# Material Symbols font (not in FreeBSD ports) - the shell's icons.
FONT_DIR=/usr/local/share/fonts/material-symbols
if [ ! -s "$FONT_DIR/MaterialSymbolsRounded.ttf" ]; then
	say "downloading the Material Symbols font"
	mkdir -p "$FONT_DIR"
	base="https://raw.githubusercontent.com/google/material-design-icons/master/variablefont"
	for f in Rounded Outlined Sharp; do
		fetch -qo "$FONT_DIR/MaterialSymbols$f.ttf" \
			"$base/MaterialSymbols$f%5BFILL%2CGRAD%2Copsz%2Cwght%5D.ttf" ||
			warn "could not download MaterialSymbols$f - shell icons will show as boxes until it is installed"
	done
	fc-cache -f >> "$LOG" 2>&1 || true
fi

# ---- dotfiles ---------------------------------------------------------------
DOTS=/var/tmp/caelestia-build/dots
say "installing the Caelestia dotfiles for $TARGET_USER"
if [ -d "$DOTS/.git" ]; then git -C "$DOTS" fetch -q origin; else rm -rf "$DOTS"; git clone -q https://github.com/caelestia-dots/caelestia.git "$DOTS"; fi
git -C "$DOTS" checkout -q -f "$CAELESTIA_DOTS_REF" 2>/dev/null || git -C "$DOTS" checkout -q -f "origin/$CAELESTIA_DOTS_REF"
git -C "$DOTS" reset -q --hard "origin/$CAELESTIA_DOTS_REF" 2>/dev/null || true

CFG="$TARGET_HOME/.config"
mkdir -p "$CFG/caelestia"
# name-in-repo : name-in-~/.config   (upstream manifest.toml, minus Linux-only bits)
for pair in hypr:hypr fish:fish foot:foot fastfetch:fastfetch btop:btop micro:micro thunar:Thunar; do
	src=${pair%%:*}; dst=${pair##*:}
	[ -d "$DOTS/$src" ] || continue
	if [ -d "$CFG/$dst" ] && [ ! -f "$CFG/$dst/.caelestia-managed" ]; then
		mv "$CFG/$dst" "$CFG/$dst.before-caelestia.$(date +%s)"
		say "your old ~/.config/$dst was kept as $dst.before-caelestia.*"
	fi
	mkdir -p "$CFG/$dst"
	cp -R "$DOTS/$src/." "$CFG/$dst/"
	touch "$CFG/$dst/.caelestia-managed"
done
[ -f "$DOTS/starship.toml" ] && [ ! -f "$CFG/starship.toml" ] && cp "$DOTS/starship.toml" "$CFG/starship.toml"

# FreeBSD-specific user config. These three files are never touched by
# upstream updates, and existing copies of yours are never overwritten.
for f in hypr-vars.lua hypr-user.lua shell.json; do
	[ -f "$CFG/caelestia/$f" ] || cp "$REPO_DIR/files/caelestia/$f" "$CFG/caelestia/$f"
done
touch "$CFG/caelestia/user-config.fish"
mkdir -p "$TARGET_HOME/Pictures/Wallpapers"
chown -R "$TARGET_USER" "$CFG" "$TARGET_HOME/Pictures"

# fish as the interactive shell inside foot only; the login shell stays sh so
# a broken fish config can never lock you out.
as_user 'caelestia scheme set -n caelestia' >> "$LOG" 2>&1 ||
	say "colour scheme will be initialised on first login"
