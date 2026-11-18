#!/bin/sh
# tests/pkg-retry-test.sh - pkg_get (lib/common.sh): a broken download is
# tried again (up to 3 times); a package that does not exist is not.
# Uses a stand-in "pkg" command. Runs anywhere with a POSIX sh.
#
#   sh tests/pkg-retry-test.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cat > "$T/pkg" <<'EOF'
#!/bin/sh
case "$1" in info) exit 1 ;; esac
n=$(cat "$CNT" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$CNT"
if [ "$n" -lt "$OK_AT" ]; then echo "[1/2] Fetching a: ...."; echo "pkg: $MSG" >&2; exit 3; fi
echo "[1/2] Fetching a: .... done"
EOF
chmod +x "$T/pkg"
PATH=$T:$PATH LOG=$T/log FBS_RETRY_DELAY=0
. "$HERE/../lib/common.sh"

pass=0 fail=0
t() { # t NAME EXPECTED-TRIES EXPECTED-RESULT(ok|fail) MSG OK_AT COMMAND...
	_name=$1 _tries=$2 _want=$3; MSG=$4 OK_AT=$5 CNT=$T/c.$pass.$fail; shift 5
	export MSG OK_AT CNT
	if "$@" >/dev/null 2>&1; then _r=ok; else _r=fail; fi
	_n=$(cat "$CNT" 2>/dev/null || echo 0)
	if [ "$_r" = "$_want" ] && [ "$_n" = "$_tries" ]; then pass=$((pass + 1)); echo "ok   $_name"
	else fail=$((fail + 1)); echo "FAIL $_name: $_r after $_n tries, want $_want after $_tries"; fi
}
F="An error occurred while fetching package"
t "broken download, fine on the 3rd try"   3 ok   "$F" 3 pkg_get foo
t "broken download every time: gives up"   3 fail "$F" 9 pkg_get foo
t "quiet mode retries too"                 2 ok   "$F" 2 pkg_get -q foo
t "pkg_try retries"                        2 ok   "$F" 2 pkg_try bar
t "missing package: no retry"              1 fail "No packages available to install matching 'foo'" 9 pkg_get foo

# fetch_retry: a broken download continues (fetch -r) up to 3 times.
cat > "$T/fetch" <<'EOF'
#!/bin/sh
n=$(cat "$CNT" 2>/dev/null || echo 0); n=$((n + 1)); echo "$n" > "$CNT"
case " $* " in *" -r "*) echo resumed >> "$CNT.how" ;; esac
[ "$n" -ge "$OK_AT" ]
EOF
chmod +x "$T/fetch"
t "download fine on the 2nd try"      2 ok   "" 2 fetch_retry "$T/f" http://x/f
t "download broken every time"        3 fail "" 9 fetch_retry "$T/f" http://x/f
if [ "$(cat "$T"/c.*.how 2>/dev/null | wc -l | tr -d ' ')" = 3 ]; then pass=$((pass + 1)); echo "ok   retries continue the partial file"
else fail=$((fail + 1)); echo "FAIL retries did not use fetch -r"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
