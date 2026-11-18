# Written by FreeBSD-setup: the ready-made bash setup (terminal style).
# bash reads this file for every interactive shell, before your ~/.bashrc.
# Turn it off for yourself:  terminal-style off

[[ $- == *i* ]] || return 0
[[ -e ${XDG_CONFIG_HOME:-$HOME/.config}/freebsd-setup/terminal-off ]] && return 0

# History: appended (not overwritten) by every window, no duplicates.
shopt -s histappend checkwinsize
HISTCONTROL=ignoreboth:erasedups
HISTSIZE=10000
HISTFILESIZE=20000

# Completion for commands, pkg, service, zfs and more.
[[ -r /usr/local/share/bash-completion/bash_completion.sh ]] &&
	. /usr/local/share/bash-completion/bash_completion.sh

# Up/Down search the history for lines starting with what you typed.
if [[ -o emacs || -o vi ]]; then
	bind '"\e[A": history-search-backward'
	bind '"\e[B": history-search-forward'
	bind 'set completion-ignore-case on'
	bind 'set show-all-if-ambiguous on'
fi

export CLICOLOR=1
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH=$HOME/.local/bin:$PATH ;; esac

# Caelestia's colours for the terminal, when it is installed.
[[ -r $HOME/.local/state/caelestia/sequences.txt ]] && cat "$HOME/.local/state/caelestia/sequences.txt"

# Prompt: starship, except on the text console, which cannot show its icons.
[[ -e ${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml ]] || export STARSHIP_CONFIG=/usr/local/etc/starship.toml
if [[ $(tty 2>/dev/null) != /dev/ttyv* ]] && command -v starship >/dev/null; then
	eval "$(starship init bash)"
else
	PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
fi

# z DIR jumps to a directory you used before; Ctrl+R searches history,
# Ctrl+T finds files, Alt+C changes into a folder.
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
command -v fzf >/dev/null && eval "$(fzf --bash)"

# Short commands. Nothing replaces a standard command (ls, cat, grep, cd):
# guides and scripts keep working as written.
_fbs_icons=auto
[[ $(tty 2>/dev/null) == /dev/ttyv* ]] && _fbs_icons=never    # text console
# shellcheck disable=SC2139  # (the icon choice is fixed when the alias is made)
if command -v eza >/dev/null; then
	alias ll="eza -l --group-directories-first --icons=$_fbs_icons --git"
	alias la="eza -la --group-directories-first --icons=$_fbs_icons --git"
	alias lt="eza --tree --level=2 --icons=$_fbs_icons"
else
	alias ll='ls -lh' la='ls -lah'
fi
alias ..='cd ..' ...='cd ../..' ....='cd ../../..'
command -v sysup >/dev/null && alias update=sysup
alias cleanup='doas pkg autoremove && doas pkg clean'
alias please=sudo
alias untar='tar -xvf' tarnow='tar -acf'
alias psmem='ps aux -m | head -20'
alias big="pkg query '%sb %n' | sort -n | tail -40"
alias rip="pkg query '%t %n-%v' | sort -n | tail -100"
alias jctl='doas dmesg -a | less'
backup() { cp -- "$1" "$1.bak"; }
apt() {
	echo "FreeBSD uses pkg, not apt:"
	echo "  pkg search NAME          find software"
	echo "  doas pkg install NAME    install it"
	echo "  sysup                    update everything"
}
apt-get() { apt; }
pacman() { apt; }
dnf() { apt; }

# The system summary when the shell starts (terminal-style greeting-off).
[[ -x /usr/local/libexec/fbs-terminal-greeting ]] && /usr/local/libexec/fbs-terminal-greeting
true
