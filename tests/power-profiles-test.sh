#!/bin/sh
# tests/power-profiles-test.sh - the power-profiles D-Bus service
# (files/power-profiles/fbs-power-profiles) on a private D-Bus, with the fake
# backend: what KDE and Quickshell read, switching, holds, restart.
#
#   sh tests/power-profiles-test.sh
#
# Needs python3 with PyGObject (gi), dbus-run-session and gdbus; skips
# otherwise. Runs on Linux and FreeBSD. Polkit is not part of this test.
set -u
here=$(cd "$(dirname "$0")" && pwd)
DAEMON="$here/../files/power-profiles/fbs-power-profiles"
if [ -z "${FBS_PP_IN_BUS:-}" ]; then
	for c in python3 dbus-run-session gdbus; do
		command -v "$c" >/dev/null || { echo "SKIP: $c not installed"; exit 0; }
	done
	python3 -c 'import gi; gi.require_version("Gio", "2.0")' 2>/dev/null ||
		{ echo "SKIP: python3 PyGObject (gi) not installed"; exit 0; }
	FBS_PP_IN_BUS=1 exec dbus-run-session -- sh "$0" "$@"
fi

T=$(mktemp -d); trap 'kill $PID 2>/dev/null; rm -rf "$T"' EXIT
export FBS_PP_BUS=session FBS_PP_NO_POLKIT=1 FBS_PP_STATE="$T/state" FBS_PP_FAKE="$T/hw"
pass=0 fail=0
check() { # check NAME EXPECTED ACTUAL
	if [ "$2" = "$3" ]; then pass=$((pass + 1)); echo "ok   $1"
	else fail=$((fail + 1)); printf 'FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; fi
}
O="--session --dest org.freedesktop.UPower.PowerProfiles --object-path /org/freedesktop/UPower/PowerProfiles"
I=org.freedesktop.UPower.PowerProfiles
get() { gdbus call $O --method org.freedesktop.DBus.Properties.Get $I "$1" 2>&1; }
set_profile() { gdbus call $O --method org.freedesktop.DBus.Properties.Set $I ActiveProfile "<'$1'>" 2>&1; }
start() {
	python3 "$DAEMON" 2>>"$T/log" & PID=$!
	i=0; while [ $i -lt 50 ]; do get Version >/dev/null 2>&1 && grep -q running "$T/log" && return; sleep 0.1; i=$((i + 1)); done
	echo "daemon did not start:"; cat "$T/log"; exit 1
}
stop() { kill $PID; wait $PID 2>/dev/null; }

start
check "starts balanced"            "(<'balanced'>,)" "$(get ActiveProfile)"
check "backend applied at start"   "balanced" "$(cat "$T/hw")"
check "profiles: 3, exact names, Driver never placeholder" \
	"(<[{'Profile': <'power-saver'>, 'Driver': <'fake'>, 'CpuDriver': <'fake'>}, {'Profile': <'balanced'>, 'Driver': <'fake'>, 'CpuDriver': <'fake'>}, {'Profile': <'performance'>, 'Driver': <'fake'>, 'CpuDriver': <'fake'>}]>,)" \
	"$(get Profiles)"
check "PerformanceDegraded empty"  "(<''>,)" "$(get PerformanceDegraded)"
check "PerformanceInhibited empty" "(<''>,)" "$(get PerformanceInhibited)"
check "no holds"                   "(<@aa{sv} []>,)" "$(get ActiveProfileHolds)"
all=$(gdbus call $O --method org.freedesktop.DBus.Properties.GetAll $I)
n=0; for p in ActiveProfile PerformanceInhibited PerformanceDegraded Profiles Actions ActionsInfo ActiveProfileHolds Version BatteryAware; do
	case "$all" in *"'$p': <"*) n=$((n + 1)) ;; esac
done
check "GetAll has all 9 properties" "9" "$n"
check "introspection lists the interface" "1" "$(gdbus introspect $O | grep -c "interface $I ")"
check "legacy name answers"        "(<'balanced'>,)" "$(gdbus call --session --dest net.hadess.PowerProfiles --object-path /net/hadess/PowerProfiles --method org.freedesktop.DBus.Properties.Get net.hadess.PowerProfiles ActiveProfile 2>&1)"

# Switching, and the PropertiesChanged signal that KDE and Quickshell wait for.
gdbus monitor --session --dest org.freedesktop.UPower.PowerProfiles > "$T/mon" 2>&1 & MON=$!
sleep 0.3
check "set performance"            "()" "$(set_profile performance)"
check "now performance"            "(<'performance'>,)" "$(get ActiveProfile)"
check "backend got performance"    "performance" "$(cat "$T/hw")"
sleep 0.3; kill $MON 2>/dev/null
check "PropertiesChanged sent"     "1" "$(grep -c "PropertiesChanged ('org.freedesktop.UPower.PowerProfiles', {'ActiveProfile': <'performance'>}" "$T/mon")"
case "$(set_profile turbo)" in *InvalidArgs*) r=rejected ;; *) r=accepted ;; esac
check "unknown profile rejected"   "rejected" "$r"
case "$(gdbus call $O --method org.freedesktop.DBus.Properties.Set $I Version "<'x'>" 2>&1)" in *"not writable"*) r=rejected ;; *) r=accepted ;; esac
check "read-only property rejected" "rejected" "$r"

# Holds: a program holds power-saver, then releases it; a holder that exits
# loses its hold.
cat > "$T/holder.py" <<'PY'
import sys, gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib
bus = Gio.bus_get_sync(Gio.BusType.SESSION)
def call(m, args, t):
    return bus.call_sync("org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles",
                         "org.freedesktop.UPower.PowerProfiles", m, args, t, 0, 5000, None).unpack()
cookie = call("HoldProfile", GLib.Variant("(sss)", ("power-saver", "testing", "test.app")), GLib.VariantType("(u)"))[0]
print("held", flush=True)
sys.stdin.readline()
if sys.argv[1] == "release":
    call("ReleaseProfile", GLib.Variant("(u)", (cookie,)), None)
    print("released", flush=True)
    sys.stdin.readline()
PY
mkfifo "$T/in"
python3 "$T/holder.py" release < "$T/in" > "$T/out" & HP=$!
exec 3>"$T/in"
i=0; while ! grep -q held "$T/out" && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
check "hold switches to power-saver" "(<'power-saver'>,)" "$(get ActiveProfile)"
check "hold is listed" "(<[{'ApplicationId': <'test.app'>, 'Profile': <'power-saver'>, 'Reason': <'testing'>}]>,)" "$(get ActiveProfileHolds)"
echo >&3
i=0; while ! grep -q released "$T/out" && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
check "release returns to the chosen profile" "(<'performance'>,)" "$(get ActiveProfile)"
echo >&3; exec 3>&-; wait $HP 2>/dev/null

python3 "$T/holder.py" exit < "$T/in" > "$T/out" & HP=$!
exec 3>"$T/in"
i=0; while ! grep -q held "$T/out" && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
check "second hold active" "(<'power-saver'>,)" "$(get ActiveProfile)"
echo >&3; exec 3>&-; wait $HP 2>/dev/null; sleep 0.3
check "holder exited: hold dropped"  "(<@aa{sv} []>,)" "$(get ActiveProfileHolds)"
check "holder exited: profile back"  "(<'performance'>,)" "$(get ActiveProfile)"
case "$(gdbus call $O --method $I.HoldProfile balanced r a 2>&1)" in *InvalidArgs*) r=rejected ;; *) r=accepted ;; esac
check "balanced cannot be held"    "rejected" "$r"

# The chosen profile survives a restart; a second copy does not take over.
python3 "$DAEMON" 2>"$T/log2"; grep -q 'could not own' "$T/log2" && r=exited || r=stayed; check "second copy exits" "exited" "$r"
stop
start
check "profile kept after restart" "(<'performance'>,)" "$(get ActiveProfile)"
stop

# No backend: the service must not start (the desktops then hide the switch).
r=$(env -u FBS_PP_FAKE PATH=/nonexistent "$(command -v python3)" "$DAEMON" --check 2>&1)
check "no backend: --check says none" "none" "$r"

echo; echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
