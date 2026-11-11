# Stage: gpu - Intel HD 630 (i915kms) drives the display; in hybrid mode the
# NVIDIA GTX 1050 (legacy 580 driver) is loaded as a secondary render GPU.

say "Intel graphics: drm-kmod (i915kms), VA-API video decoding, Mesa, Vulkan"
pkg_install drm-kmod mesa-dri mesa-libs libva-intel-media-driver libva-utils \
	vulkan-loader vulkan-tools mesa-demos xwayland
kld_add i915kms

if [ "$GPU_MODE" = hybrid ]; then
	N="-$NVIDIA_BRANCH"
	say "NVIDIA legacy driver branch $NVIDIA_BRANCH (kernel module, DRM module, userland)"
	pkg_install "nvidia-driver$N" "nvidia-drm-kmod$N"
	# All three must be the same driver version or the module refuses to work.
	dv=$(pkg query %v "nvidia-driver$N" | sed 's/[_,].*//')
	kv=$(pkg query %v "nvidia-kmod$N")
	case "$kv" in
	"$dv"*) ;;
	*) warn "nvidia-driver$N ($dv) and nvidia-kmod$N ($kv) are different versions. Run 'pkg upgrade' until they match before rebooting." ;;
	esac
	loader_set hw.nvidiadrm.modeset 1
	# Order matters: Intel first so it becomes /dev/dri/card0 (the display GPU).
	kld_add nvidia-modeset nvidia-drm
	install -m 755 "$REPO_DIR/files/bin/nvrun" /usr/local/bin/nvrun
	say "use 'nvrun <program>' to render on the GTX 1050"
else
	say "GPU_MODE=intel: NVIDIA driver not installed"
	_k=$(sysrc -n kld_list 2>/dev/null | tr ' ' '\n' | grep -v '^nvidia' | tr '\n' ' ')
	sysrc kld_list="$(echo $_k)" >/dev/null
fi

# Load now when the hardware is really there (not in a VM), so no reboot is
# needed before the first login.
if ! is_vm; then
	kldload -n i915kms >> "$LOG" 2>&1 || warn "i915kms did not load - check 'dmesg | tail'"
	if [ "$GPU_MODE" = hybrid ]; then
		if has_nvidia; then
			kldload -n nvidia-modeset >> "$LOG" 2>&1 || warn "nvidia-modeset did not load - check 'dmesg | tail'"
		else
			warn "no NVIDIA GPU found on the PCI bus; consider GPU_MODE=intel"
		fi
	fi
fi
