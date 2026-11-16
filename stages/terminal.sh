# Stage: terminal - an optional ready-made terminal (TERMINAL_STYLE): fish or
# zsh with suggestions as you type, or bash; colours, completion, a git-aware
# prompt (starship), short commands and a system summary (fastfetch), in
# Konsole and foot.
#
# The login shell is never changed: the style applies inside the terminal
# app, so a broken shell setup can never stop anyone from logging in.
# Everything system-wide carries the marker and is only replaced or removed
# when it is ours; the only file in the home folder is a short ~/.zshrc (zsh
# style, only when there is none), which stops zsh's first-run questions.

_sh=$REPO_DIR/files/shell
_fish_conf=/usr/local/share/fish/vendor_conf.d/freebsd-setup.fish
_fish_greet=/usr/local/share/fish/vendor_functions.d/fish_greeting.fish
_greet=/usr/local/libexec/fbs-terminal-greeting
_zshrc=/usr/local/etc/zshrc
_bashrc=/usr/local/etc/bash.bashrc
_star=/usr/local/etc/starship.toml
_ff=/usr/local/etc/xdg/fastfetch/config.jsonc
_kprof=/usr/local/share/konsole/FreeBSD.profile
_krc=/usr/local/etc/xdg/konsolerc
_foot=/usr/local/etc/xdg/foot/foot.ini
_skel_zshrc=/usr/share/skel/dot.zshrc

if [ "$TERMINAL_STYLE" = none ]; then
	say "terminal style: plain (as FreeBSD ships it)"
	for _f in "$_fish_conf" "$_fish_greet" "$_greet" "$_zshrc" "$_bashrc" "$_star" "$_ff" \
		"$_kprof" "$_krc" "$_foot" "$_skel_zshrc"; do
		sys_file_rm "$_f"
	done
	foot_set_shell "$TARGET_HOME/.config/foot/foot.ini"
	return 0
fi

say "terminal style: $TERMINAL_STYLE"
# Nice to have, not essential: a missing package must not stop the setup.
pkg_try starship fzf zoxide eza bat bash-completion nerd-fonts-jetbrainsmono tealdeer
case "$TERMINAL_STYLE" in
fish) pkg_try fish ;;
zsh)  pkg_try zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions ;;
esac
_shell=$(terminal_shell)
[ "$_shell" = "/usr/local/bin/$TERMINAL_STYLE" ] ||
	warn "$TERMINAL_STYLE could not be installed, so the terminal starts bash for now; run 'doas freebsd-setup terminal' later to try again"

install_file "$REPO_DIR/files/bin/terminal-style" /usr/local/bin/terminal-style 755
sys_file "$_sh/starship.toml" "$_star" || true
sys_file "$_sh/fastfetch.jsonc" "$_ff" || true
if is_yes TERMINAL_GREETING; then
	sys_file "$_sh/fbs-terminal-greeting" "$_greet" 755 || true
else
	sys_file_rm "$_greet"
fi

# A setup for every shell that is installed, whatever the style: a user who
# types "zsh" or "bash" in a fish terminal gets a good shell as well.
if [ -x /usr/local/bin/fish ]; then
	sys_file "$_sh/freebsd-setup.fish" "$_fish_conf" || true
	sys_file "$_sh/fish_greeting.fish" "$_fish_greet" || true
fi
sys_file "$_sh/bash.bashrc" "$_bashrc" ||
	[ "$TERMINAL_STYLE" != bash ] || warn "your own $_bashrc was kept, so the bash terminal style is not active"
if [ -x /usr/local/bin/zsh ]; then
	sys_file "$_sh/zshrc" "$_zshrc" ||
		[ "$TERMINAL_STYLE" != zsh ] || warn "your own $_zshrc was kept, so the zsh terminal style is not active"
	sys_file "$_sh/dot.zshrc" "$_skel_zshrc" || true
	if [ "$TERMINAL_STYLE" = zsh ]; then user_file "$_sh/dot.zshrc" .zshrc; fi
fi

# Konsole (KDE): a FreeBSD profile that starts the chosen shell, as default.
if [ "$WANT_KDE" = yes ]; then
	_tmp=$(mktemp)
	sed "s|@SHELL@|$_shell|" "$_sh/FreeBSD.profile" > "$_tmp"
	sys_file "$_tmp" "$_kprof" || true
	rm -f "$_tmp"
	sys_file "$_sh/konsolerc" "$_krc" || true
fi

# foot (Hyprland). With Caelestia, its own foot setup is used and only the
# shell is set (stages/caelestia.sh); without it, a system-wide one.
if [ "$WANT_HYPR" = yes ]; then
	if [ -e "$TARGET_HOME/.config/foot/.caelestia-managed" ]; then
		sys_file_rm "$_foot"
		foot_set_shell "$TARGET_HOME/.config/foot/foot.ini"
	else
		_tmp=$(mktemp)
		sed "s|@SHELL@|$_shell|" "$_sh/foot.ini" > "$_tmp"
		sys_file "$_tmp" "$_foot" || true
		rm -f "$_tmp"
	fi
fi

say "terminal ready: open a new terminal window. Turn it off for yourself with: terminal-style off"
true   # (a stage must not end on a failed test: setup.sh runs under set -e)
