#!/bin/sh
#
# bootstrap.sh - the one-line start for FreeBSD-setup:
#
#   fetch -qo- https://raw.githubusercontent.com/nimonht/FreeBSD-setup/main/bootstrap.sh | sh
#
# On the FreeBSD 15 USB stick's "Live System" it starts the guided installer;
# on an installed FreeBSD it starts the desktop setup wizard. Any arguments
# are passed on:   ... | sh -s -- --dry-run
#
# Environment: FBS_REPO=owner/name, FBS_REF=branch/tag/commit (defaults:
# nimonht/FreeBSD-setup, main). For a reproducible install, pin what runs:
#   FBS_REF=<tag or full commit id>     that exact version instead of "main"
#   FBS_SHA256=<sha256 of the archive>  refuse to run anything else
set -eu

REPO="${FBS_REPO:-nimonht/FreeBSD-setup}"
REF="${FBS_REF:-main}"
URL="https://github.com/$REPO/archive/$REF.tar.gz"
DIR="/tmp/freebsd-setup"

[ "$(uname -s)" = FreeBSD ] || { echo "This is for FreeBSD." >&2; exit 1; }

echo "==> Downloading FreeBSD-setup ($REPO $REF)"
if ! fetch -q -o /tmp/freebsd-setup.tar.gz "$URL"; then
	echo "Download failed. Is the network up? On the USB stick, connect first with:" >&2
	echo "    bsdinstall netconfig" >&2
	exit 1
fi
if [ -n "${FBS_SHA256:-}" ]; then
	got=$(sha256 -q /tmp/freebsd-setup.tar.gz)
	if [ "$got" != "$FBS_SHA256" ]; then
		rm -f /tmp/freebsd-setup.tar.gz
		echo "Checksum mismatch: expected $FBS_SHA256, got $got. Nothing was run." >&2
		exit 1
	fi
fi
rm -rf "$DIR" && mkdir -p "$DIR"
tar -xzf /tmp/freebsd-setup.tar.gz -C "$DIR" --strip-components 1
rm -f /tmp/freebsd-setup.tar.gz

# Running from the install media? Its root file system is read-only.
opts=$(mount -p | awk '$2 == "/" { print $3 " ," $4 ","; exit }')
case "$opts" in
cd9660*|*,ro,*) target="$DIR/install.sh" ;;
*)              target="$DIR/setup.sh" ;;
esac

# The script came through a pipe: give the wizard the keyboard back.
if [ "$(id -u)" -eq 0 ]; then
	exec /bin/sh "$target" "$@" < /dev/tty
elif command -v doas >/dev/null 2>&1; then
	exec doas /bin/sh "$target" "$@" < /dev/tty
elif command -v sudo >/dev/null 2>&1; then
	exec sudo /bin/sh "$target" "$@" < /dev/tty
else
	echo "==> Enter the root password:"
	exec su -m root -c "/bin/sh '$target' $*" < /dev/tty
fi
