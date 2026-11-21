#!/bin/sh
# tests/live-test.sh - the LunaBSD live session's driver plan (lib/live.sh)
# for every recorded machine: which graphics driver the live USB tries, or
# why only the installer starts. Runs anywhere with a POSIX sh.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
FBS_LIB="$HERE/../lib"
export FBS_LIB
# fixture | text | basic | session | driver | words in the reason
CASES='amd-desktop|||plasma|amdgpu|
asus-gl553vd|||plasma|i915kms|
legion-amd-nvidia|||plasma|amdgpu|
lunar-lake|||installer|none|xe
macbook-broadcom|||plasma|i915kms|
meteor-lake|||plasma|i915kms|
nvidia-kepler|||installer|none|X11 driver
nvidia-rtx3060|||plasma|nvidia-drm|
radeon-rx9070|||plasma|amdgpu|
radeon-si|||plasma|/boot/modules/radeonkms.ko|
thinkpad-t480|||plasma|i915kms|
virtualbox|||installer|none|virtual machines
thinkpad-t480||1|installer|none|basic graphics
nvidia-rtx3060|1||text|none|'
pass=0 fail=0
while IFS='|' read -r fx text basic want_s want_d want_r; do
	[ -n "$fx" ] || continue
	got=$(
		HW_FIXTURES="$HERE/fixtures/$fx"
		. "$FBS_LIB/hw.sh"
		. "$FBS_LIB/live.sh"
		hw_detect
		live_plan "$text" "$basic"
		printf '%s|%s|%s' "$LIVE_SESSION" "$LIVE_DRIVER" "$LIVE_REASON"
	)
	s=${got%%|*}; rest=${got#*|}; d=${rest%%|*}; r=${rest#*|}
	if [ "$s" = "$want_s" ] && [ "$d" = "$want_d" ] && { [ -z "$want_r" ] || printf '%s' "$r" | grep -qF -- "$want_r"; }; then
		pass=$((pass + 1))
	else
		fail=$((fail + 1))
		echo "FAIL $fx (text=$text basic=$basic): got session=$s driver=$d reason='$r'; want $want_s $want_d '$want_r'"
	fi
done <<CASES
$CASES
CASES
echo "live-test: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
