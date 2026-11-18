# Written by FreeBSD-setup: the ready-made fish setup (terminal style).
# Turn it off for yourself:  terminal-style off
# Your own settings go in ~/.config/fish/config.fish (it runs after this file).
# Inspired by the CachyOS, Garuda and Bluefin setups; written for FreeBSD.

status is-interactive; or return
set -l cfg ~/.config
set -q XDG_CONFIG_HOME; and set cfg $XDG_CONFIG_HOME
test -e $cfg/freebsd-setup/terminal-off; and return
# Caelestia (Hyprland) sets fish up itself.
test -e $cfg/fish/.caelestia-managed; and return

set -gx CLICOLOR 1
fish_add_path -g ~/.local/bin

# Prompt: starship, except on the text console, which cannot show its icons.
test -e $cfg/starship.toml; or set -gx STARSHIP_CONFIG /usr/local/etc/starship.toml
if not string match -q '/dev/ttyv*' (tty 2>/dev/null)
    command -q starship; and starship init fish | source
end

# z DIR jumps to a directory you used before; Ctrl+R searches history,
# Ctrl+T finds files, Alt+C changes into a folder.
command -q zoxide; and zoxide init fish | source
command -q fzf; and fzf --fish | source

# Short commands. Nothing replaces a standard command (ls, cat, grep, cd):
# guides and scripts keep working as written.
set -l icons auto
string match -q '/dev/ttyv*' (tty 2>/dev/null); and set icons never   # text console
if command -q eza
    abbr -a ll "eza -l --group-directories-first --icons=$icons --git"
    abbr -a la "eza -la --group-directories-first --icons=$icons --git"
    abbr -a lt "eza --tree --level=2 --icons=$icons"
else
    abbr -a ll 'ls -lh'
    abbr -a la 'ls -lah'
end
abbr -a .. 'cd ..'
abbr -a ... 'cd ../..'
abbr -a .... 'cd ../../..'
command -q sysup; and abbr -a update sysup
abbr -a cleanup 'doas pkg autoremove; and doas pkg clean'
abbr -a please sudo
abbr -a untar 'tar -xvf'
abbr -a tarnow 'tar -acf'
abbr -a psmem 'ps aux -m | head -20'
abbr -a big "pkg query '%sb %n' | sort -n | tail -40"
abbr -a rip "pkg query '%t %n-%v' | sort -n | tail -100"
abbr -a jctl 'doas dmesg -a | less'

function backup --description 'Copy a file to FILE.bak'
    cp -- $argv[1] $argv[1].bak
end

function apt --description 'FreeBSD uses pkg'
    echo "FreeBSD uses pkg, not apt:"
    echo "  pkg search NAME          find software"
    echo "  doas pkg install NAME    install it"
    echo "  sysup                    update everything"
end
function apt-get --wraps apt; apt $argv; end
function pacman --wraps apt; apt $argv; end
function dnf --wraps apt; apt $argv; end
