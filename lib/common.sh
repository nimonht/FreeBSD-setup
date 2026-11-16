# lib/common.sh - shared helpers for setup.sh, install.sh and the stages.
# POSIX sh (FreeBSD /bin/sh). Sourced, never executed.
#
# Two targets:
#   FBS_TARGET=live    the running system (default): services are started,
#                      kernel modules loaded, sysctls applied immediately
#   FBS_TARGET=chroot  a system being installed (install.sh runs setup.sh in
#                      a chroot): only files are written, nothing is started

: "${FBS_TARGET:=live}"
: "${LOG:=/var/log/freebsd-setup.log}"
: "${FBS_SHARE:=/usr/local/share/freebsd-setup}"
: "${FBS_CONF:=/usr/local/etc/freebsd-setup.conf}"
WARNINGS="${WARNINGS:-}"

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ] && [ "${TERM:-dumb}" != dumb ]; then
	_c_info='\033[1;36m' _c_ok='\033[1;32m' _c_warn='\033[1;33m'
	_c_err='\033[1;31m' _c_head='\033[1;35m' _c_off='\033[0m'
else
	_c_info='' _c_ok='' _c_warn='' _c_err='' _c_head='' _c_off=''
fi

_log() { [ -n "$LOG" ] && printf '%s\n' "$*" >> "$LOG" 2>/dev/null || true; }
say()  { printf "${_c_info}  ->${_c_off} %s\n" "$*"; _log "  -> $*"; }
ok()   { printf "${_c_ok}  ok${_c_off} %s\n" "$*"; _log "  ok $*"; }
warn() {
	printf "${_c_warn}WARNING:${_c_off} %s\n" "$*" >&2
	_log "WARNING: $*"
	WARNINGS="${WARNINGS}
  - $*"
}
die()  { printf "${_c_err}ERROR:${_c_off} %s\n" "$*" >&2; _log "ERROR: $*"; exit 1; }
step() { printf "\n${_c_head}==== %s ====${_c_off}\n" "$*"; _log "==== $* ===="; }

is_live()   { [ "$FBS_TARGET" = live ]; }
is_chroot() { [ "$FBS_TARGET" = chroot ]; }

# is_yes VAR -> true when the variable holds yes/YES/true/1/on
is_yes() { eval "_v=\${$1:-}"; case "$_v" in [Yy][Ee][Ss]|[Tt][Rr][Uu][Ee]|1|[Oo][Nn]) return 0 ;; esac; return 1; }

# in_list word list...  -> true when word is one of the following words
in_list() { local _w _x; _w=$1; shift; for _x in "$@"; do [ "$_x" = "$_w" ] && return 0; done; return 1; }

# ---------------------------------------------------------------- packages ---

# pkg_has name   -> true when the configured repositories offer the package
pkg_has() { pkg rquery -U '%n' "$1" >/dev/null 2>&1; }

# run_shown pattern command...   run a command, log all its output, show
# the lines matching the pattern (progress), return the command's status
run_shown() {
	local _pat _rcf _r
	_pat=$1; shift
	_rcf=$(mktemp)
	{ "$@"; echo $? > "$_rcf"; } 2>&1 | tee -a "$LOG" |
		grep --line-buffered -E "$_pat" | sed -u 's/^/       /' || true
	_r=$(cat "$_rcf" 2>/dev/null); rm -f "$_rcf"
	return "${_r:-1}"
}

# pkg_install name...   install packages, one progress line per package;
# fail the script if any is missing
pkg_install() {
	say "pkg install $*"
	run_shown '^\[[0-9]+/[0-9]+\] (Fetching|Installing|Upgrading)' \
		env ASSUME_ALWAYS_YES=yes pkg install -y "$@" ||
		die "could not install: $*  (details: $LOG)"
}

# pkg_try name...   install each package that is available; missing or
# broken packages only produce a warning
pkg_try() {
	local _p
	for _p in "$@"; do
		pkg info -e "$_p" 2>/dev/null && continue
		if env ASSUME_ALWAYS_YES=yes pkg install -y "$_p" >> "$LOG" 2>&1; then
			say "installed $_p"
		else
			warn "package '$_p' is not available right now - skipped"
		fi
	done
}

# pkg_flavor meta   -> the concrete flavour a meta package picks for this
# OS version, e.g. "drm-kmod" -> "drm-612-kmod"
pkg_flavor() {
	pkg rquery -U '%dn' "$1" 2>/dev/null | grep -E "^${2:-.*}" | head -1
}

# ------------------------------------------------------------ config files ---

# set_kv file key value   key=value line, replaced in place or appended
set_kv() {
	local _f _k _v _tmp
	_f=$1 _k=$2 _v=$3
	touch "$_f"
	if grep -q "^${_k}=" "$_f"; then
		_tmp=$(mktemp)
		awk -v k="$_k" -v v="$_v" 'BEGIN{FS=OFS="="} $1==k{print k "=" v; next} {print}' "$_f" > "$_tmp" &&
			cat "$_tmp" > "$_f"
		rm -f "$_tmp"
	else
		printf '%s=%s\n' "$_k" "$_v" >> "$_f"
	fi
}
loader_set() { set_kv /boot/loader.conf "$1" "\"$2\""; }
sysctl_set() {
	set_kv /etc/sysctl.conf "$1" "$2"
	is_live && { sysctl "$1=$2" >/dev/null 2>&1 || true; }
	return 0
}

# add_line file line   append the line unless it is already present
add_line() { touch "$1"; grep -qxF -- "$2" "$1" || printf '%s\n' "$2" >> "$1"; }

# kld_add module...   append to rc.conf kld_list (order kept, no duplicates)
kld_add() {
	local _cur _m
	_cur=$(sysrc -n kld_list 2>/dev/null || true)
	for _m in "$@"; do
		case " $_cur " in *" $_m "*) ;; *) _cur="$_cur $_m" ;; esac
	done
	sysrc kld_list="$(echo $_cur)" >/dev/null
}

# kld_now module   load a module right away on a live system
kld_now() { is_live && { kldload -n "$1" >> "$LOG" 2>&1 || return 1; }; return 0; }

# svc rcvar [script]   enable a service and (on a live system) start it;
# script defaults to rcvar (they differ for e.g. avahi_daemon/avahi-daemon)
svc() {
	local _s
	sysrc "${1}_enable=YES" >/dev/null
	if is_live; then
		_s=${2:-$1}
		service "$_s" status >/dev/null 2>&1 || service "$_s" start >> "$LOG" 2>&1 || true
	fi
}

# install_file src dst [mode]   copy a file from the repository
install_file() { install -m "${3:-644}" "$1" "$2"; }

# sys_file src dst [mode]   a system-wide config file of ours: written only
# where there is none yet, where the one there is ours (has the marker), or
# where it is still the package's untouched default (a copy of dst.sample).
# Someone else's file is kept, and the call returns 1.
sys_file() {
	if [ -e "$2" ] && ! grep -q 'Written by FreeBSD-setup' "$2" 2>/dev/null &&
		! { [ -f "$2.sample" ] && cmp -s "$2" "$2.sample"; }; then
		say "kept your own $2"
		return 1
	fi
	mkdir -p "$(dirname "$2")"
	install -m "${3:-644}" "$1" "$2"
}
# sys_file_rm dst   remove a file, only when it is ours (the package's
# default comes back when it has one)
sys_file_rm() {
	[ -f "$1" ] && grep -q 'Written by FreeBSD-setup' "$1" 2>/dev/null || return 0
	rm -f "$1"
	[ -f "$1.sample" ] && cp "$1.sample" "$1"
	return 0
}

# foot_set_shell FILE   start the terminal style's shell in this foot.ini,
# only when it is Caelestia's copy (marked .caelestia-managed, ours to
# change), never the user's own; with no style, Caelestia's choice (fish).
foot_set_shell() {
	local _s
	_s=$(terminal_shell)
	[ -n "$_s" ] && [ -x "$_s" ] || _s=/usr/local/bin/fish
	[ -e "$(dirname "$1")/.caelestia-managed" ] && [ -f "$1" ] && grep -q '^shell=' "$1" || return 0
	sed -i '' "s|^shell=.*|shell=$_s|" "$1"
}

# terminal_shell   the shell the chosen terminal style runs (empty for none;
# bash, which base installs, when the chosen shell could not be installed)
terminal_shell() {
	case "${TERMINAL_STYLE:-none}" in
	fish|zsh|bash)
		if [ -x "/usr/local/bin/$TERMINAL_STYLE" ]; then echo "/usr/local/bin/$TERMINAL_STYLE"
		else echo /usr/local/bin/bash; fi ;;
	esac
}

# --------------------------------------------------------------- the user ---

# as_user command   run a shell command as the desktop user, in their home.
# Not a login shell, and never attached to the terminal: a login shell runs
# ~/.profile, whose resizewin(1) touches the terminal from a background
# process group, and the kernel then stops (suspends) su for good.
as_user() {
	su "$TARGET_USER" -c "cd ~ && PATH=/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin && $*" < /dev/null
}

# user_file src dest-relative-to-home   copy into the user's home, never
# overwriting a file they already have
user_file() {
	local _dst
	_dst="$TARGET_HOME/$2"
	mkdir -p "$(dirname "$_dst")"
	if [ -e "$_dst" ]; then
		cmp -s "$1" "$_dst" || say "kept your existing ~/$2"
	else
		cp "$1" "$_dst"
		chown "$TARGET_USER" "$_dst"
	fi
	chown "$TARGET_USER" "$(dirname "$_dst")"
}

root_pool() { zfs list -H -o name / 2>/dev/null | cut -d/ -f1; }
