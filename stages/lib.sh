# Shared helpers for the setup stages (sourced by setup.sh).

say()   { printf '\033[1;36m  ->\033[0m %s\n' "$*"; echo "  -> $*" >> "$LOG"; }
warn()  { printf '\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; echo "WARNING: $*" >> "$LOG"; WARNINGS="${WARNINGS:-}
  - $*"; }
die()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
stage() { printf '\n\033[1;35m==== %s ====\033[0m\n' "$1"; echo "==== $1 ====" >> "$LOG"; }

# pkg_install name...   install packages; fails the script if one is missing
pkg_install() {
	say "pkg install $*"
	env ASSUME_ALWAYS_YES=yes pkg install -y "$@" >> "$LOG" 2>&1 ||
		die "pkg install failed for: $*  (details: $LOG)"
}

# pkg_try name...   install each package if the repository has it; a missing
# or temporarily broken package only produces a warning
pkg_try() {
	for _p in "$@"; do
		if pkg info -e "$_p"; then continue; fi
		if env ASSUME_ALWAYS_YES=yes pkg install -y "$_p" >> "$LOG" 2>&1; then
			say "installed $_p"
		else
			warn "package '$_p' is not available right now - skipped"
		fi
	done
}

# set_kv file key value   set key="value" in a loader.conf/sysctl.conf style
# file, replacing an existing assignment or appending
set_kv() {
	_f=$1; _k=$2; _v=$3
	touch "$_f"
	if grep -q "^${_k}=" "$_f"; then
		sed -i '' "s|^${_k}=.*|${_k}=${_v}|" "$_f"
	else
		echo "${_k}=${_v}" >> "$_f"
	fi
}
loader_set() { set_kv /boot/loader.conf "$1" "\"$2\""; }
sysctl_set() { set_kv /etc/sysctl.conf "$1" "$2"; sysctl "$1=$2" >/dev/null 2>&1 || true; }

# add_line file line   append the line unless it is already there
add_line() { touch "$1"; grep -qxF "$2" "$1" || echo "$2" >> "$1"; }

# kld_add module...   append to kld_list in rc.conf, keeping order, no dupes
kld_add() {
	_cur=$(sysrc -n kld_list 2>/dev/null || true)
	for _m in "$@"; do
		case " $_cur " in *" $_m "*) ;; *) _cur="$_cur $_m" ;; esac
	done
	sysrc kld_list="$(echo $_cur)" >/dev/null
}

# as_user cmd...   run a command as the desktop user, in their home
as_user() { su -l "$TARGET_USER" -c "$*"; }

# install_user_file src dest_rel [mode]   copy a file into the user's home
# without overwriting one they already have (existing file wins)
install_user_file() {
	_dst="$TARGET_HOME/$2"
	mkdir -p "$(dirname "$_dst")"
	if [ -e "$_dst" ]; then
		cmp -s "$1" "$_dst" || say "kept your existing ~/$2"
	else
		cp "$1" "$_dst"
		[ -n "${3:-}" ] && chmod "$3" "$_dst"
	fi
	chown -R "$TARGET_USER" "$(dirname "$_dst")"
}

has_nvidia() { pciconf -lv 2>/dev/null | grep -A2 '^vgapci' | grep -qi 'nvidia'; }
is_vm()      { [ "$(sysctl -n kern.vm_guest 2>/dev/null || echo none)" != none ]; }
root_pool()  { zfs list -H -o name / 2>/dev/null | cut -d/ -f1; }
