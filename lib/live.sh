# lib/live.sh - the LunaBSD live session's plan: which graphics driver to
# try, or why the installer starts alone. POSIX sh, sourced after hw.sh and
# hw_detect. Used by iso/live/luna_live; tested by tests/live-test.sh.
#
#   live_plan TEXT BASIC   TEXT/BASIC: non-empty when the boot menu's text
#                          installer / basic graphics was chosen. Sets
#   LIVE_SESSION   plasma (when LIVE_DRIVER gives a display), installer, text
#   LIVE_DRIVER    kernel module to load (none when nothing is tried)
#   LIVE_REASON    why there is no desktop (for the installer's first page)
live_plan() {
	LIVE_SESSION=installer LIVE_DRIVER=none LIVE_REASON=""
	if [ -n "${1:-}" ]; then LIVE_SESSION=text; return 0; fi
	if [ -n "${2:-}" ]; then LIVE_REASON="basic graphics was chosen in the boot menu"; return 0; fi
	if [ "$HW_DESKTOP" != yes ]; then LIVE_REASON=$HW_DESKTOP_WHY; return 0; fi
	case "$HW_GPU_PRIMARY" in
	intel)	LIVE_DRIVER=i915kms ;;
	amd)	LIVE_DRIVER=amdgpu
		[ "$HW_AMD_KMOD" = radeonkms ] && LIVE_DRIVER=/boot/modules/radeonkms.ko ;;
	nvidia)	if [ "$HW_NVIDIA_BRANCH" = current ]; then LIVE_DRIVER=nvidia-drm
		else LIVE_REASON="this NVIDIA card needs the $HW_NVIDIA_BRANCH driver, which the live system does not carry (the installed system gets it)"; fi ;;
	*)	LIVE_REASON="no supported graphics card found" ;;
	esac
	[ "$LIVE_DRIVER" != none ] && LIVE_SESSION=plasma
	return 0
}
