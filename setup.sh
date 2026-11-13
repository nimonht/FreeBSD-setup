#!/bin/sh
#
# setup.sh - turn a FreeBSD 15 installation into a ready-to-use desktop.
#
#   doas ./setup.sh               ask a few questions, then set everything up
#   doas ./setup.sh --yes         no questions: use saved answers / defaults
#   ./setup.sh --report           hardware compatibility report (no changes)
#   doas ./setup.sh STAGE...      run only some stages (see --list)
#
# Options:
#   --config FILE   read answers from FILE (see lib/defaults.conf)
#   --user NAME     the desktop user (default: whoever ran doas/sudo/su)
#   --yes           unattended: never ask
#   --report        print the hardware report and exit
#   --env           print detected hardware as variables and exit
#   --list          list the stages and exit
#
# Every stage is safe to run again. On ZFS a boot environment named
# "pre-setup-<date>" is created first: picking it in the boot menu (or
# "bectl activate pre-setup-..." + reboot) undoes everything this did.

set -eu

# realpath: "freebsd-setup" in /usr/local/sbin is a symlink to this file
REPO_DIR=$(dirname "$(realpath "$0")")
FBS_LIB="$REPO_DIR/lib"
STAGES="base drivers system network zfs audio desktop kde hyprland caelestia input printing apps gaming security finish"

. "$FBS_LIB/common.sh"
. "$FBS_LIB/hw.sh"
. "$FBS_LIB/ui.sh"
. "$FBS_LIB/wizard.sh"

usage() { sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

list_stages() {
	cat <<'EOF'
Stages, in order (each one skips itself when it does not apply):
  base       package branch, updates, core tools, doas/sudo, groups, language
  drivers    CPU microcode, graphics (Intel/AMD/NVIDIA), firmware, touchpad, VM tools
  system     services, power management, laptop lid/backlight, kernel tuning
  network    Wi-Fi regulatory domain, network manager applet
  zfs        boot environments, automatic snapshots, scrub, sysup/snap tools
  audio      PipeWire + WirePlumber
  desktop    fonts, portals, removable drives, login screen, keyboard layout
  kde        KDE Plasma 6
  hyprland   Hyprland, its tools and session
  caelestia  Caelestia shell + dotfiles for Hyprland (built for FreeBSD)
  input      fcitx5 input methods (Vietnamese, Chinese, Japanese, Korean...)
  printing   CUPS printing, network printer discovery, scanners
  apps       browser, office, media, developer tools
  gaming     Linux compatibility, Steam, Wine/Proton, MangoHud
  security   firewall (pf) and safe kernel defaults
  finish     snapshot and summary
EOF
}

CONFIG_FILE="" ASSUME_YES="${ASSUME_YES:-no}" ACTION=run ARG_USER=""
RUN=""
while [ $# -gt 0 ]; do
	case "$1" in
	--config) CONFIG_FILE=${2:?--config needs a file}; shift ;;
	--user)   ARG_USER=${2:?--user needs a name}; shift ;;
	--yes|-y) ASSUME_YES=yes ;;
	--chroot) FBS_TARGET=chroot ;;
	--report) ACTION=report ;;
	--env)    ACTION="env" ;;
	--list|-l) list_stages; exit 0 ;;
	--help|-h) usage 0 ;;
	-*)       echo "unknown option $1" >&2; usage 2 >&2 ;;
	*)        RUN="$RUN $1" ;;
	esac
	shift
done

[ "$(uname -s)" = FreeBSD ] || { echo "setup.sh runs on FreeBSD (this is $(uname -s))." >&2; exit 1; }

hw_detect
case "$ACTION" in
report) hw_report; exit 0 ;;
env)    hw_env; exit 0 ;;
esac

[ "$(id -u)" -eq 0 ] || die "run it as root:  doas $0   (or: su -m root -c '$0')"
case "$HW_OSREL" in 1[5-9].*) ;; *) die "FreeBSD 15 or newer is required (this is $HW_OSREL)" ;; esac

# Answers: defaults < saved answers < --config file < command line
. "$FBS_LIB/defaults.conf"
[ -f "$FBS_CONF" ] && . "$FBS_CONF"
[ -n "$CONFIG_FILE" ] && . "$CONFIG_FILE"
[ -n "$ARG_USER" ] && TARGET_USER=$ARG_USER
: "${DESKTOP_LANGUAGE:=}"

if [ -z "${TARGET_USER:-}" ]; then
	TARGET_USER="${DOAS_USER:-${SUDO_USER:-$(logname 2>/dev/null || true)}}"
fi
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = root ]; then
	# Pick the only regular account, if there is exactly one.
	_users=$(awk -F: '$3 >= 1001 && $3 < 60000 && $7 !~ /nologin/ { print $1 }' /etc/passwd)
	[ "$(printf '%s\n' "$_users" | grep -c .)" -eq 1 ] && TARGET_USER=$_users
fi
[ -n "$TARGET_USER" ] && [ "$TARGET_USER" != root ] ||
	die "could not tell who the desktop is for; run with --user NAME"
id "$TARGET_USER" >/dev/null 2>&1 || die "user '$TARGET_USER' does not exist"
TARGET_HOME=$(pw usershow "$TARGET_USER" | cut -d: -f9)
export TARGET_USER TARGET_HOME REPO_DIR FBS_LIB FBS_TARGET

mkdir -p "$(dirname "$LOG")"
: >> "$LOG"

# ------------------------------------------------------------------ wizard ---
ui_init
if [ -z "$RUN" ] && [ "$UI_MODE" != auto ]; then
	_rep=$(mktemp)
	hw_report > "$_rep"
	ui_text "Your computer" "$_rep"
	rm -f "$_rep"
	wiz_desktop || exit 1
	if [ "$DESKTOP" != none ]; then
		[ -n "$KEYBOARD_LAYOUT" ] || wiz_keyboard || exit 1
		[ -n "$DESKTOP_LANGUAGE" ] || wiz_language || exit 1
		wiz_input_methods || exit 1
	fi
	wiz_extras || exit 1
	resolve_config
	ui_yesno "Ready" "$(wiz_summary_text)

Downloads several GB and takes 20-60 minutes. Start now?" yes || exit 1
fi

save_config "$FBS_CONF"
resolve_config
[ -n "$RUN" ] || RUN=$STAGES
for s in $RUN; do
	[ -f "$REPO_DIR/stages/$s.sh" ] || die "unknown stage '$s' (see: $0 --list)"
done

_log "=== setup.sh $(date) target=$FBS_TARGET user=$TARGET_USER stages:$RUN ==="
for s in $RUN; do
	step "$s"
	. "$REPO_DIR/stages/$s.sh"
done
