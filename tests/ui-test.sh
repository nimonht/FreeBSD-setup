#!/bin/sh
# tests/ui-test.sh - drive the bsddialog wrappers in lib/ui.sh with real key
# presses through a pseudo-terminal (script(1)). Run on FreeBSD:
#   sh tests/ui-test.sh
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
LIB="$HERE/../lib"
pass=0 fail=0

# t NAME KEYS EXPECTED SNIPPET  - run SNIPPET in dialog mode inside a pty, type
# KEYS (printf format) after a short pause, compare what it prints.
t() {
	_out=$( (sleep 2; printf "$2"; sleep 2) | script -q /dev/null /bin/sh -c "
		LOG=/dev/null; . '$LIB/common.sh'; . '$LIB/ui.sh'; UI_MODE=dialog
		r=\$($4); echo \"RESULT=[\$r] RC=\$?\"" 2>/dev/null | tr -d '\r' | sed -n 's/.*\(RESULT=\[.*\] RC=[0-9]*\).*/\1/p' | tail -1)
	if [ "$_out" = "$3" ]; then pass=$((pass + 1)); echo "ok   $1"
	else fail=$((fail + 1)); echo "FAIL $1: got '$_out', want '$3'"; fi
}

# Keys as a terminal sends them in curses keypad mode: arrows are ESC O x.
t "menu: Enter keeps the default" '\r' 'RESULT=[b] RC=0' \
	"ui_menu Title Text b a 'Item A' b 'Item B' c 'Item C'"
t "menu: Down arrow moves to the next item" '\033OB\r' 'RESULT=[c] RC=0' \
	"ui_menu Title Text b a 'Item A' b 'Item B' c 'Item C'"
t "menu: first letter of a tag jumps to it" 'c\r' 'RESULT=[c] RC=0' \
	"ui_menu Title Text a a 'Item A' b 'Item B' c 'Item C'"
t "menu: Escape cancels (bsddialog status 5)" '\033' 'RESULT=[] RC=5' \
	"ui_menu Title Text a a 'Item A' b 'Item B'"
t "checklist: defaults" '\r' 'RESULT=[a c] RC=0' \
	"ui_check Title Text a 'Item A' on b 'Item B' off c 'Item C' on"
t "checklist: Space toggles the current item" '\033OB \r' 'RESULT=[a b] RC=0' \
	"ui_check Title Text a 'Item A' on b 'Item B' off c 'Item C' off"
t "input: typed text is appended" 'xy\r' 'RESULT=[defxy] RC=0' \
	"ui_input Title Text def"
t "password" 'se cret\r' 'RESULT=[se cret] RC=0' \
	"ui_password Title Text"
t "yes/no: Enter means yes" '\r' 'RESULT=[] RC=0' \
	"ui_yesno Title Text yes"
t "yes/no: default no" '\r' 'RESULT=[] RC=1' \
	"ui_yesno Title Text no"
t "menu with spaces and many items (time zone style)" '\r' 'RESULT=[Asia/Ho_Chi_Minh] RC=0' \
	"ui_menu Title Text Asia/Ho_Chi_Minh Asia/Bangkok 'Bangkok - Thailand' Asia/Ho_Chi_Minh 'Ho Chi Minh - Vietnam' Asia/Tokyo 'Tokyo'"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
