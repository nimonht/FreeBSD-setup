# Stage: gaming - Linux binary compatibility, Steam, Wine/Proton, overlays.

[ "$INSTALL_GAMING" = yes ] || { say "INSTALL_GAMING=no - skipped"; return 0 2>/dev/null || true; }

say "Linux ABI layer (linuxulator) with the Rocky Linux 9 userland"
sysrc linux_enable=YES >/dev/null
kld_add linux linux64
pkg_install linux-rl9 linux-rl9-dri linux-rl9-vulkan linux-rl9-libglvnd
service linux status >/dev/null 2>&1 || service linux start >> "$LOG" 2>&1 || true
add_line /etc/fstab "tmpfs	/compat/linux/dev/shm	tmpfs	rw,late,size=1g,mode=1777	0	0"

if [ "$GPU_MODE" = hybrid ]; then
	say "NVIDIA libraries for Linux programs (Steam games)"
	pkg_install "linux-nvidia-libs-$NVIDIA_BRANCH"
fi

say "Steam (Linux client), Wine with Proton patches, tools"
pkg_install linux-steam-utils wine-proton winetricks gamescope
pkg_try mangohud mizuma prismlauncher

# Games want many open files and mapped memory regions.
sysctl_set kern.maxfiles 524288
sysctl_set kern.maxfilesperproc 262144
sysctl_set kern.ipc.shm_allow_removed 1
loader_set kern.maxproc 20000

install -m 755 "$REPO_DIR/files/bin/steam-setup" /usr/local/bin/steam-setup
say "to finish Steam, run 'steam-setup' once as $TARGET_USER after logging in to the desktop"
