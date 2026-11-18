#!/bin/sh
# tests/timedate-test.sh - the timedate1 D-Bus service (files/timedate/
# fbs-timedate), which KDE's Date & Time page uses, on a private D-Bus with
# its files redirected into a temporary folder (nothing on this computer is
# changed): time zone, automatic time, clock, hardware-clock mode.
#
#   sh tests/timedate-test.sh
#
# Needs python3 with PyGObject (gi), dbus-run-session and gdbus; skips
# otherwise. Polkit is not part of this test.
set -u
here=$(cd "$(dirname "$0")" && pwd)
DAEMON="$here/../files/timedate/fbs-timedate"
if [ -z "${FBS_TD_IN_BUS:-}" ]; then
	for c in python3 dbus-run-session gdbus; do
		command -v "$c" >/dev/null || { echo "SKIP: $c not installed"; exit 0; }
	done
	python3 -c 'import gi; gi.require_version("Gio", "2.0")' 2>/dev/null ||
		{ echo "SKIP: python3 PyGObject (gi) not installed"; exit 0; }
	[ -f /usr/share/zoneinfo/Europe/Berlin ] || { echo "SKIP: no /usr/share/zoneinfo"; exit 0; }
	FBS_TD_IN_BUS=1 exec dbus-run-session -- sh "$0" "$@"
fi

T=$(mktemp -d); trap 'kill $PID 2>/dev/null; rm -rf "$T"' EXIT
mkdir -p "$T/etc" "$T/var/db"; echo UTC > "$T/var/db/zoneinfo"; echo no > "$T/ntp"
export FBS_TD_BUS=session FBS_TD_NO_POLKIT=1 FBS_TD_ROOT="$T"
pass=0 fail=0
check() { if [ "$2" = "$3" ]; then pass=$((pass + 1)); echo "ok   $1"; else fail=$((fail + 1)); printf 'FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fi; }
O="--session --dest org.freedesktop.timedate1 --object-path /org/freedesktop/timedate1"
I=org.freedesktop.timedate1
get() { gdbus call $O --method org.freedesktop.DBus.Properties.Get $I "$1" 2>&1; }
calls() { m=$1; shift; gdbus call $O --method "$I.$m" "$@" 2>&1; }

python3 "$DAEMON" 2>"$T/log" & PID=$!
i=0; while [ $i -lt 50 ]; do get Timezone >/dev/null 2>&1 && grep -q running "$T/log" && break; sleep 0.1; i=$((i + 1)); done

check "time zone read from /var/db/zoneinfo" "(<'UTC'>,)" "$(get Timezone)"
check "automatic time can be switched" "(<true>,)" "$(get CanNTP)"
n=0; all=$(gdbus call $O --method org.freedesktop.DBus.Properties.GetAll $I)
for p in Timezone LocalRTC CanNTP NTP NTPSynchronized TimeUSec RTCTimeUSec; do case "$all" in *"'$p': <"*) n=$((n + 1)) ;; esac; done
check "GetAll has all 7 properties" 7 "$n"

check "set time zone" "()" "$(calls SetTimezone Asia/Ho_Chi_Minh false)"
check "zone name written" "Asia/Ho_Chi_Minh" "$(cat "$T/var/db/zoneinfo")"
cmp -s "$T/etc/localtime" /usr/share/zoneinfo/Asia/Ho_Chi_Minh && r=same || r=different
check "/etc/localtime is a copy of the zone file" same "$r"
check "new zone reported" "(<'Asia/Ho_Chi_Minh'>,)" "$(get Timezone)"
case "$(calls SetTimezone Mars/Olympus false)" in *InvalidArgs*) r=rejected ;; *) r=accepted ;; esac
check "unknown zone rejected" rejected "$r"
case "$(calls SetTimezone ../../../etc/passwd false)" in *InvalidArgs*) r=rejected ;; *) r=accepted ;; esac
check "path outside the zone folder rejected" rejected "$r"

check "turn automatic time on" "()" "$(calls SetNTP true false)"
check "ntpd enabled and started" 2 "$(grep -c -x -e 'sysrc ntpd_enable=YES' -e 'service ntpd onerestart' "$T/commands")"
case "$(calls SetTime 1000000 true false)" in *AutomaticTimeSyncEnabled*) r=refused ;; *) r=allowed ;; esac
check "setting the clock refused while automatic time is on" refused "$r"
check "turn automatic time off" "()" "$(calls SetNTP false false)"
check "set the clock" "()" "$(calls SetTime 1800000000000000 false false)"
check "clock set with date(1)" "date -u -f %s 1800000000" "$(grep '^date' "$T/commands" | tail -1)"
check "hardware clock in local time" "()" "$(calls SetLocalRTC true false false)"
[ -f "$T/etc/wall_cmos_clock" ] && r=yes || r=no
check "/etc/wall_cmos_clock created" yes "$r"
check "zone list offered" 1 "$(calls ListTimezones | grep -c "'Europe/Berlin'")"
case "$(gdbus call $O --method org.freedesktop.DBus.Properties.Set $I Timezone "<'UTC'>" 2>&1)" in *PropertyReadOnly*|*"not writable"*) r=rejected ;; *) r=accepted ;; esac
check "properties are read-only" rejected "$r"

echo; echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
