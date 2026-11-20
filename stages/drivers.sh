# Stage: drivers - everything that depends on the detected hardware: CPU
# microcode and sensors, graphics, firmware, touchpads, laptop hotkeys,
# webcams and virtual-machine guest tools.

# ---- CPU --------------------------------------------------------------------
if [ "$HW_VM" = none ]; then
	case "$HW_CPU_VENDOR" in
	intel)	pkg_install cpu-microcode-intel
		loader_set cpu_microcode_load YES
		loader_set cpu_microcode_name /boot/firmware/intel-ucode.bin
		loader_set coretemp_load YES; kld_now coretemp || true ;;
	amd)	pkg_install cpu-microcode-amd
		loader_set cpu_microcode_load YES
		loader_set cpu_microcode_name /boot/firmware/amd-ucode.bin
		loader_set amdtemp_load YES; kld_now amdtemp || true ;;
	esac
fi

# ---- input devices ------------------------------------------------------------
# The modern USB HID stack gives touchpads, touchscreens and pens proper
# multitouch through evdev/libinput.
loader_set hw.usb.usbhid.enable 1
if [ "$HW_LAPTOP" = yes ]; then
	say "laptop: I2C and PS/2 touchpad drivers${HW_ACPI_KMOD:+, hotkeys ($HW_ACPI_KMOD)}"
	loader_set ig4_load YES                    # I2C controller (Intel and AMD)
	loader_set iichid_load YES                 # I2C HID touchpads
	loader_set hw.psm.synaptics_support 1      # PS/2 touchpads as real touchpads
	loader_set hw.psm.elantech_support 1
	loader_set hw.psm.trackpoint_support 1
	[ -n "$HW_ACPI_KMOD" ] && loader_set "${HW_ACPI_KMOD}_load" YES
fi

# ---- firmware -------------------------------------------------------------------
# fwget(8) matches PCI IDs to the firmware packages GPUs and Wi-Fi cards need.
if [ "$HW_VM" = none ]; then
	say "firmware for graphics and Wi-Fi (fwget)"
	fwget pci >> "$LOG" 2>&1 || warn "fwget could not install some firmware (details: $LOG)"
fi

# ---- graphics -------------------------------------------------------------------
_drm=""
gpu_drm() { # install the DRM driver package matching this FreeBSD version once
	[ -n "$_drm" ] && return 0
	_drm=$(pkg_flavor drm-kmod 'drm-[0-9]+-kmod')
	pkg_install "${_drm:-drm-kmod}" mesa-dri mesa-libs vulkan-loader libva libva-utils
	_drm="done"
}

if in_list intel $GPU_DRIVERS; then
	say "Intel graphics: i915kms + VA-API video decoding"
	gpu_drm
	pkg_install libva-intel-media-driver libva-intel-driver
	kld_add i915kms
	kld_now i915kms || warn "i915kms did not load - check: dmesg | tail -30"
fi

if in_list amd $GPU_DRIVERS; then
	say "AMD graphics: $HW_AMD_KMOD"
	gpu_drm
	if [ "$HW_AMD_KMOD" = radeonkms ]; then
		kld_add /boot/modules/radeonkms.ko
		kld_now /boot/modules/radeonkms.ko || warn "radeonkms did not load - check: dmesg | tail -30"
	else
		kld_add amdgpu
		kld_now amdgpu || warn "amdgpu did not load - check: dmesg | tail -30"
	fi
fi

NVIDIA_PKG=""
if in_list nvidia $GPU_DRIVERS && [ "$NVIDIA_BRANCH" != none ]; then
	case "$NVIDIA_BRANCH" in
	current) NVIDIA_PKG="nvidia-driver"; _drmpkg="nvidia-drm-kmod" ;;
	580)     NVIDIA_PKG="nvidia-driver-580"; _drmpkg="nvidia-drm-kmod-580" ;;
	470|390|340|304) NVIDIA_PKG="nvidia-driver-$NVIDIA_BRANCH"; _drmpkg="" ;;
	*)       NVIDIA_PKG="" ;;
	esac
	if [ -z "$NVIDIA_PKG" ]; then
		warn "this NVIDIA GPU needs driver branch $NVIDIA_BRANCH, which FreeBSD no longer ships - it stays unused"
	elif [ -z "$_drmpkg" ] && [ "$HW_GPU_PRIMARY" != nvidia ]; then
		say "NVIDIA $NVIDIA_BRANCH driver skipped: it cannot render for a Wayland desktop that runs on the other GPU"
		NVIDIA_PKG=""
	else
		say "NVIDIA driver ($NVIDIA_PKG)"
		if [ -n "$_drmpkg" ]; then
			# nvidia-drm-kmod (a meta package) can name another DRM version
			# than drm-kmod, which the Intel/AMD driver uses (seen: 5.15 and
			# 6.12); the two cannot be installed together, which breaks
			# hybrid laptops. Take NVIDIA's module built for drm-kmod's version.
			_dflav=$(pkg_flavor drm-kmod 'drm-[0-9]+-kmod'); _dflav=${_dflav#drm-}; _dflav=${_dflav%-kmod}
			_f="nvidia-drm-${_dflav}-kmod${_drmpkg#nvidia-drm-kmod}"
			[ -n "$_dflav" ] && pkg_has "$_f" && _drmpkg=$_f
			pkg_install "$_drmpkg" "$NVIDIA_PKG"
			# The kernel module, DRM module and userland must be one version.
			_dv=$(pkg query %v "$NVIDIA_PKG" 2>/dev/null | sed 's/[_,].*//')
			_kv=$(pkg query %v "nvidia-kmod${NVIDIA_PKG#nvidia-driver}" 2>/dev/null || true)
			case "$_kv" in "$_dv"*) ;; *) warn "$NVIDIA_PKG ($_dv) and its kernel module ($_kv) differ - run 'pkg upgrade' until they match" ;; esac
			loader_set hw.nvidiadrm.modeset 1
			kld_add nvidia-modeset nvidia-drm
		else
			pkg_install "$NVIDIA_PKG"
			kld_add nvidia
			warn "the NVIDIA $NVIDIA_BRANCH driver is X11 only: KDE Plasma 6 and Hyprland (Wayland) will not run on this GPU"
		fi
		if is_live && [ -n "$_drmpkg" ]; then
			kld_now nvidia-modeset || warn "nvidia-modeset did not load - check: dmesg | tail -30"
		fi
	fi
fi

# Which card X11 (the SDDM login screen) uses. Decided again at every start,
# so it follows a firmware graphics switch or a replaced graphics card.
install_file "$REPO_DIR/files/bin/gpu-xorg-config" /usr/local/bin/gpu-xorg-config 755
install_file "$REPO_DIR/files/rc.d/freebsd_setup_gpu" /usr/local/etc/rc.d/freebsd_setup_gpu 755
sysrc freebsd_setup_gpu_enable=YES >/dev/null
FBS_LIB="$FBS_LIB" /usr/local/bin/gpu-xorg-config >> "$LOG" 2>&1 || warn "could not write the X11 graphics configuration (details: $LOG)"

# Hybrid graphics: a helper to run a program on the second GPU.
if [ "$HW_GPU_HYBRID" = yes ]; then
	install_file "$REPO_DIR/files/bin/gpu-run" /usr/local/bin/gpu-run 755
	ln -sf gpu-run /usr/local/bin/nvrun
	say "hybrid graphics: run games on the extra GPU with 'gpu-run <program>'"
fi

# ---- virtual machines -------------------------------------------------------------
case "$HW_VM" in
virtualbox)
	pkg_try virtualbox-ose-additions-nox11
	sysrc vboxguest_enable=YES vboxservice_enable=YES >/dev/null ;;
vmware)
	pkg_try open-vm-tools-nox11
	sysrc vmware_guest_vmblock_enable=NO vmware_guestd_enable=YES >/dev/null 2>&1 || true ;;
esac

# ---- webcam -------------------------------------------------------------------------
# On every desktop, not only when a camera is plugged in now: a USB camera
# plugged in later is then started by webcamd's devd rules.
if [ -n "$HW_WEBCAM" ] || [ "$DESKTOP" != none ]; then
	say "webcams: webcamd${HW_WEBCAM:+ ($HW_WEBCAM)}"
	pkg_try webcamd
	if pkg info -e webcamd 2>/dev/null; then
		loader_set cuse_load YES
		svc webcamd
		pw groupmod webcamd -m "$TARGET_USER" 2>/dev/null || true
	fi
fi

true   # (a stage must not end on a failed test: setup.sh runs under set -e)
