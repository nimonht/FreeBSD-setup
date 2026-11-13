# Stage: gaming - Linux binary compatibility, Steam, Wine/Proton, overlays.

is_yes INSTALL_GAMING || { say "gaming not selected - skipped"; return 0; }
[ "$HW_ARCH" = amd64 ] || { warn "Steam and Wine need an amd64 machine - gaming skipped"; return 0; }

say "Linux compatibility layer with the Rocky Linux 9 userland"
kld_add linux linux64
kldload -n linux64 2>/dev/null || true   # the packages check the running kernel
svc linux
pkg_install linux-rl9 linux-rl9-dri linux-rl9-vulkan linux-rl9-libglvnd
add_line /etc/fstab "tmpfs	/compat/linux/dev/shm	tmpfs	rw,late,size=1g,mode=1777	0	0"

# Linux games on NVIDIA need the matching Linux build of the NVIDIA libraries.
_nv=$(pkg query -g %n 'nvidia-driver*' 2>/dev/null | head -1)
case "$_nv" in
nvidia-driver)   pkg_install linux-nvidia-libs ;;
nvidia-driver-*) pkg_try "linux-nvidia-libs-${_nv#nvidia-driver-}" ;;
esac

say "Steam (Linux client), Wine with Proton patches, tools"
pkg_install linux-steam-utils wine-proton winetricks
pkg_try mangohud gamescope mizuma prismlauncher
loader_set kern.maxproc 20000

install_file "$REPO_DIR/files/bin/steam-setup" /usr/local/bin/steam-setup 755
say "to finish Steam, run 'steam-setup' once as $TARGET_USER from a terminal in the desktop"

true   # (a stage must not end on a failed test: setup.sh runs under set -e)
