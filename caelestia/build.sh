#!/bin/sh
#
# caelestia/build.sh - build and install the Caelestia shell and CLI on FreeBSD.
#
# Caelestia (https://github.com/caelestia-dots) targets Arch Linux. Nothing in
# FreeBSD ports packages it, and its native plugin depends on a few Linux-only
# pieces. This script builds everything from source and bridges the gaps:
#
#   lm-sensors      -> libsensors-shim/ (same API, backed by FreeBSD sysctls)
#   libcava         -> cavacore.c from upstream cava, built as a static library
#   qt6-m3shapes    -> built from source
#   /proc/...       -> /compat/linux/proc/... (linprocfs, mounted by linux_enable)
#   sys/sysmacros.h -> sys/types.h
#   std::jthread    -> -fexperimental-library (still experimental in FreeBSD's libc++)
#
# Run as root (setup.sh does). Environment:
#   SHELL_REF / CLI_REF   git ref to build ("latest-tag", a tag, branch, commit)
#   WORK                  build directory (default /var/tmp/caelestia-build)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
WORK="${WORK:-/var/tmp/caelestia-build}"
SHELL_REF="${SHELL_REF:-latest-tag}"
CLI_REF="${CLI_REF:-latest-tag}"
PREFIX=/usr/local
CAVA_VERSION=0.10.6
JOBS=$(sysctl -n hw.ncpu)

say() { printf '\033[1;36m  ->\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# checkout URL DIR REF   clone/update a repository at the requested ref
checkout() {
	if [ -d "$2/.git" ]; then
		git -C "$2" fetch -q --tags origin
	else
		rm -rf "$2"
		git clone -q "$1" "$2"
	fi
	ref=$3
	if [ "$ref" = latest-tag ]; then
		ref=$(git -C "$2" tag --sort=-v:refname | grep -E '^v?[0-9]' | head -1)
		[ -n "$ref" ] || ref=origin/HEAD
	fi
	git -C "$2" checkout -q -f "$ref" 2>/dev/null || git -C "$2" checkout -q -f "origin/$ref"
	git -C "$2" clean -qfdx -e build
	say "$(basename "$2") at $(git -C "$2" describe --tags --always)"
}

mkdir -p "$WORK"
cd "$WORK"

# ---- 1. lm-sensors shim ------------------------------------------------------
say "building the lm-sensors shim"
mkdir -p "$WORK/shim/lib" "$WORK/shim/include/sensors"
cc -O2 -fPIC -I"$HERE/libsensors-shim" -c "$HERE/libsensors-shim/sensors.c" -o "$WORK/shim/sensors.o"
ar rcs "$WORK/shim/lib/libsensors.a" "$WORK/shim/sensors.o"
cp "$HERE/libsensors-shim/sensors/sensors.h" "$WORK/shim/include/sensors/"

# ---- 2. libcava (cavacore) ---------------------------------------------------
say "building libcava (cavacore $CAVA_VERSION)"
mkdir -p "$WORK/cava" "$WORK/shim/include/cava" "$WORK/shim/lib/pkgconfig"
for f in cavacore.c cavacore.h; do
	[ -s "$WORK/cava/$f" ] ||
		fetch -qo "$WORK/cava/$f" "https://raw.githubusercontent.com/karlstav/cava/$CAVA_VERSION/$f"
done
cc -O2 -fPIC -I"$PREFIX/include" -c "$WORK/cava/cavacore.c" -o "$WORK/cava/cavacore.o"
ar rcs "$WORK/shim/lib/libcava.a" "$WORK/cava/cavacore.o"
cp "$WORK/cava/cavacore.h" "$WORK/shim/include/cava/"
cat > "$WORK/shim/lib/pkgconfig/cava.pc" <<PC
prefix=$WORK/shim
libdir=\${prefix}/lib
includedir=\${prefix}/include

Name: cava
Description: cavacore audio visualisation core (static)
Version: $CAVA_VERSION
Libs: -L\${libdir} -lcava -L$PREFIX/lib -lfftw3 -lm
Cflags: -I\${includedir} -I$PREFIX/include
PC
export PKG_CONFIG_PATH="$WORK/shim/lib/pkgconfig:$PREFIX/libdata/pkgconfig:$PREFIX/lib/pkgconfig"

# ---- 3. M3Shapes QML module --------------------------------------------------
say "building M3Shapes"
checkout https://github.com/soramanew/m3shapes.git "$WORK/m3shapes" "${M3SHAPES_REF:-origin/HEAD}"
cmake -S "$WORK/m3shapes" -B "$WORK/m3shapes/build" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DINSTALL_QMLDIR=lib/qt6/qml > "$WORK/m3shapes.log" 2>&1 || die "M3Shapes configure failed: $WORK/m3shapes.log"
cmake --build "$WORK/m3shapes/build" -j "$JOBS" >> "$WORK/m3shapes.log" 2>&1 || die "M3Shapes build failed: $WORK/m3shapes.log"
cmake --install "$WORK/m3shapes/build" >> "$WORK/m3shapes.log" 2>&1

# ---- 4. Caelestia shell ------------------------------------------------------
say "building the Caelestia shell (this is the long one)"
checkout https://github.com/caelestia-dots/shell.git "$WORK/shell" "$SHELL_REF"
S="$WORK/shell"

# FreeBSD source adjustments (kept as sed so they survive upstream changes).
find "$S/plugin" "$S/extras" \( -name '*.cpp' -o -name '*.hpp' \) -print0 | xargs -0 \
	sed -i '' -e 's|#include <sys/sysmacros.h>|#include <sys/types.h>|' \
	          -e 's|u"/proc/|u"/compat/linux/proc/|g'
find "$S" -name '*.qml' -print0 | xargs -0 \
	sed -i '' -e 's|"/usr/share/X11/xkb/|"/usr/local/share/X11/xkb/|g' \
	          -e 's|"/usr/lib/caelestia"|"/usr/local/lib/caelestia"|g'
# Local patches, if any (caelestia/patches/*.patch), applied in name order.
for p in "$HERE"/patches/*.patch; do
	[ -f "$p" ] || continue
	say "applying $(basename "$p")"
	patch -d "$S" -p1 -s < "$p" || die "patch $(basename "$p") no longer applies to this Caelestia version"
done

VERSION=$(git -C "$S" describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
[ -n "$VERSION" ] || VERSION=0.0.0
cmake -S "$S" -B "$S/build" -G Ninja \
	-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" \
	-DVERSION="$VERSION" -DGIT_REVISION="$(git -C "$S" rev-parse HEAD)" \
	-DDISTRIBUTOR="FreeBSD-setup" \
	-DINSTALL_LIBDIR=lib/caelestia \
	-DINSTALL_QMLDIR=lib/qt6/qml \
	-DINSTALL_QSCONFDIR=etc/xdg/quickshell/caelestia \
	-DSENSORS_LIBRARY="$WORK/shim/lib/libsensors.a" \
	-DSENSORS_INCLUDE_DIR="$WORK/shim/include" \
	-DCMAKE_PREFIX_PATH="$PREFIX" \
	-DCMAKE_CXX_FLAGS="-I$PREFIX/include -fexperimental-library" \
	-DCMAKE_SHARED_LINKER_FLAGS="-L$PREFIX/lib -fexperimental-library" \
	-DCMAKE_MODULE_LINKER_FLAGS="-L$PREFIX/lib -fexperimental-library" \
	-DCMAKE_EXE_LINKER_FLAGS="-L$PREFIX/lib -fexperimental-library" > "$WORK/shell.log" 2>&1 || die "shell configure failed: $WORK/shell.log"
cmake --build "$S/build" -j "$JOBS" >> "$WORK/shell.log" 2>&1 || die "shell build failed: $WORK/shell.log"
cmake --install "$S/build" >> "$WORK/shell.log" 2>&1 || die "shell install failed: $WORK/shell.log"

# ---- 5. Caelestia CLI --------------------------------------------------------
say "installing the Caelestia CLI"
checkout https://github.com/caelestia-dots/cli.git "$WORK/cli" "$CLI_REF"
PY=$(command -v python3.13 || command -v python3.14 || true)
[ -n "$PY" ] || die "python 3.13+ is required for the Caelestia CLI (pkg install python313)"
VENV=$PREFIX/share/caelestia-cli
[ -x "$VENV/bin/python" ] || "$PY" -m venv "$VENV" > "$WORK/cli.log" 2>&1 || die "could not create a Python venv: $WORK/cli.log"
"$VENV/bin/python" -m pip install -q --upgrade pip >> "$WORK/cli.log" 2>&1 || true
# pillow / materialyoucolor compile native code against /usr/local.
env CFLAGS="-I$PREFIX/include" CXXFLAGS="-I$PREFIX/include" LDFLAGS="-L$PREFIX/lib" \
	"$VENV/bin/python" -m pip install -q "$WORK/cli" >> "$WORK/cli.log" 2>&1 || die "CLI install failed: $WORK/cli.log"
ln -sf "$VENV/bin/caelestia" "$PREFIX/bin/caelestia"
# Shell completions for fish.
if [ -f "$WORK/cli/completions/caelestia.fish" ]; then
	mkdir -p "$PREFIX/share/fish/vendor_completions.d"
	cp "$WORK/cli/completions/caelestia.fish" "$PREFIX/share/fish/vendor_completions.d/"
fi

say "Caelestia shell $VERSION and CLI installed under $PREFIX"
