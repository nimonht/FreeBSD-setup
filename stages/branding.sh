# Stage: branding - the LumenBSD look on an installed system: the name and
# sunrise in the boot menu, the wallpaper (for desktops still on Plasma's
# default), the login screen background, KDE's "About this System", and an
# os-release that says LumenBSD (FreeBSD's version stays in it, ID_LIKE=freebsd).
# lib/branding.sh does the work; the ISO build uses the same code.

. "$FBS_LIB/branding.sh"
say "$DISTRO_NAME look: boot menu, wallpaper, login screen, About page"
branding_apply ""
sysrc lumenbsd_osrelease_enable=YES >/dev/null
is_live && { service lumenbsd_osrelease start >> "$LOG" 2>&1 || true; }

true   # (a stage must not end on a failed test: setup.sh runs under set -e)
