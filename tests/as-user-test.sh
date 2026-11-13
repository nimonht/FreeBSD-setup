#!/bin/sh
# tests/as-user-test.sh - regression test for as_user (lib/common.sh), run as
# root on FreeBSD from a terminal:   sh tests/as-user-test.sh USER
# as_user once used "su -l": the login profile's resizewin(1) touched the
# terminal from a background process group and the kernel suspended su, so
# the setup hung forever when started from a console.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
LOG=/tmp/as-user-test.log; : > "$LOG"
TARGET_USER=${1:?usage: as-user-test.sh USER}
. "$HERE/../lib/common.sh"
[ -t 0 ] || echo "note: stdin is not a terminal; the original bug needs one"

timeout 20 su -l "$TARGET_USER" -c "echo old-ok" >> "$LOG" 2>&1
echo "old su -l version: exit $? (124 = hung, the bug)"

out=$(timeout 20 sh -c ". '$HERE/../lib/common.sh'; TARGET_USER=$TARGET_USER; as_user 'echo \"user=\$(id -un) home=\$HOME pwd=\$(pwd)\"'" 2>&1)
rc=$?
echo "as_user: exit $rc, output: $out"
case "$rc:$out" in
0:user=$TARGET_USER\ home=*\ pwd=/*) echo "PASS"; exit 0 ;;
*) echo "FAIL"; exit 1 ;;
esac
