#!/bin/sh
# tests/run.sh - hardware-detection tests against recorded machine profiles.
# Runs anywhere with a POSIX sh and awk (FreeBSD, Linux, macOS):
#   sh tests/run.sh            all fixtures
#   sh tests/run.sh -v NAME    one fixture, printing its full report
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
FBS_LIB="$HERE/../lib"
export FBS_LIB
VERBOSE=no
[ "${1:-}" = "-v" ] && { VERBOSE=yes; shift; }

pass=0 fail=0
for dir in "$HERE"/fixtures/*/; do
	name=$(basename "$dir")
	[ $# -gt 0 ] && [ "$name" != "$1" ] && continue
	out=$(
		HW_FIXTURES="$dir"
		. "$FBS_LIB/hw.sh"
		hw_detect
		hw_env
		echo "----REPORT----"
		hw_report
	)
	[ "$VERBOSE" = yes ] && printf '%s\n' "$out"
	report=$(printf '%s\n' "$out" | sed -n '/^----REPORT----$/,$p')
	bad=""
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		case "$line" in
		report:*)
			want=${line#report:}
			printf '%s\n' "$report" | grep -qF -- "$want" || bad="$bad${bad:+; }report lacks '$want'" ;;
		*)
			key=${line%%=*}; want=${line#*=}
			got=$(printf '%s\n' "$out" | sed -n "s/^$key=\"\(.*\)\"\$/\1/p" | head -1)
			[ "$got" = "$want" ] || bad="$bad${bad:+; }$key='$got' (want '$want')" ;;
		esac
	done < "$dir/expect.txt"
	if [ -z "$bad" ]; then
		pass=$((pass + 1)); printf 'ok   %s\n' "$name"
	else
		fail=$((fail + 1)); printf 'FAIL %s: %s\n' "$name" "$bad"
	fi
done
printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
