# Written by FreeBSD-setup: what fish shows when it starts (terminal style).
# Your own ~/.config/fish/functions/fish_greeting.fish replaces this one.
function fish_greeting
    # fish's own switch: "set -U fish_greeting" (empty) turns it off.
    if set -q fish_greeting
        test -n "$fish_greeting"; and echo $fish_greeting
        return
    end
    set -l cfg ~/.config
    set -q XDG_CONFIG_HOME; and set cfg $XDG_CONFIG_HOME
    test -e $cfg/freebsd-setup/terminal-off; and return
    test -x /usr/local/libexec/fbs-terminal-greeting; and /usr/local/libexec/fbs-terminal-greeting
end
