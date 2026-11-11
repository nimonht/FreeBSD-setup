#!/bin/sh
#
# setup.sh - turn a fresh FreeBSD 15 install (ZFS root) into a daily-driver
# desktop: graphics, audio, Hyprland + Caelestia shell (or KDE), gaming,
# ZFS snapshots and boot environments.
#
#   su -m root -c './setup.sh'          run every stage
#   su -m root -c './setup.sh gpu zfs'  run only the named stages
#   ./setup.sh --list                   show the stages
#
# Safe to re-run: every stage is idempotent. Settings live in config.env.
# A ZFS boot environment is created first, so "bectl activate pre-setup-..."
# + reboot undoes everything this script did to the system.

set -eu

REPO_DIR=$(cd "$(dirname "$0")" && pwd)
STAGES="base system zfs gpu audio desktop caelestia kde gaming apps finish"
LOG=/var/log/freebsd-setup.log

if [ "${1:-}" = "--list" ] || [ "${1:-}" = "-l" ]; then
	cat <<EOF
Stages, in order:
  base       package branch, updates, core tools, doas, user groups, locale
  system     laptop tuning: loader.conf, sysctl, power, microcode, services
  zfs        boot environments, automatic snapshots, scrub, TRIM, ARC limit
  gpu        Intel i915 (+ NVIDIA $([ -f "$REPO_DIR/config.env" ] && . "$REPO_DIR/config.env" && echo "${NVIDIA_BRANCH:-580}") legacy driver in hybrid mode), nvrun
  audio      PipeWire + WirePlumber on OSS
  desktop    Hyprland, portals, fonts, themes, login manager, session wrapper
  caelestia  build Caelestia shell/CLI for FreeBSD, install the dotfiles
  kde        KDE Plasma 6 (only when DESKTOP is kde or both)
  gaming     Linux ABI layer, Steam, Wine/Proton, MangoHud, gamescope
  apps       browser, office, media, developer tools
  finish     summary and next steps
EOF
	exit 0
fi

[ "$(uname -s)" = FreeBSD ] || { echo "setup.sh must run on FreeBSD" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "setup.sh must run as root:  su -m root -c './setup.sh'" >&2; exit 1; }

. "$REPO_DIR/config.env"
. "$REPO_DIR/stages/lib.sh"

# Who are we setting the desktop up for?
if [ -z "${TARGET_USER:-}" ]; then
	TARGET_USER="${SUDO_USER:-${DOAS_USER:-$(logname 2>/dev/null || true)}}"
fi
[ -n "$TARGET_USER" ] && [ "$TARGET_USER" != root ] ||
	die "could not work out your user name; set TARGET_USER in config.env"
id "$TARGET_USER" >/dev/null 2>&1 || die "user '$TARGET_USER' does not exist"
TARGET_HOME=$(pw usershow "$TARGET_USER" | cut -d: -f9)
export REPO_DIR TARGET_USER TARGET_HOME

case "$DESKTOP" in hyprland|kde|both) ;; *) die "DESKTOP must be hyprland, kde or both" ;; esac
case "$GPU_MODE" in hybrid|intel) ;; *) die "GPU_MODE must be hybrid or intel" ;; esac

[ $# -gt 0 ] && RUN="$*" || RUN="$STAGES"
for s in $RUN; do
	[ -f "$REPO_DIR/stages/$s.sh" ] || die "unknown stage '$s' (see ./setup.sh --list)"
done

mkdir -p "$(dirname "$LOG")"
echo "=== setup.sh $(date) stages: $RUN ===" >> "$LOG"

for s in $RUN; do
	stage "$s"
	. "$REPO_DIR/stages/$s.sh"
done
