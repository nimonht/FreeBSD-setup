# A preconfigured terminal for FreeBSD-setup: research and design

Date: 2026-11-16. Research only: no repo file was changed, and **nothing here was run on FreeBSD**.

**Where the claims come from.** Everything comes from upstream source at pinned commits, FreeBSD port Makefiles and plists, the FreeBSD 15 package catalogues (latest and quarterly), and the repo itself. Statements tagged UNVERIFIED or UNTESTED must be checked in the dev VM or on the laptop before anyone says they work.

**Scratch root.** Clones and catalogues are in `/tmp/claude-1000/-home-thanh-Projects-FreeBSD-setup/68b379d5-b3ae-4ed9-9164-af24277607d6/scratchpad/research/term/`, called `$T` below.

---

## 1. What CachyOS ships (exact)

### Sources

| Repo | Commit | Note |
|---|---|---|
| cachyos-fish-config | cc78c7f7a8a7 | Tag v16, the version that is packaged |
| cachyos-zsh-config | 27c5494d687f | Packaged tag v1.0.3 (79c20770) differs in one way only: `cleanup` became a function |
| CachyOS-PKGBUILDS | a7b305845d9f | |
| cachyos-kde-settings | 717481de49f3 | |
| cachyos-alacritty-config | 99de043e8086 | |
| cachyos-welcome | efd467041a9a | |
| cachyos-calamares | 1f939ebed330 | Branch `cachyos` |
| CachyOS-Live-ISO | b0ebcae291b1 | |
| cachyos-hypr-noctalia | 467067b5ad6f | |

### 1.1 fish (the default): package `cachyos-fish-config` v16

**Installed files:**

| File | Installed to | Size |
|---|---|---|
| `config.fish` | `/etc/skel/.config/fish/config.fish` | 7 lines |
| `cachyos-config.fish` | `/usr/share/cachyos-fish-config/` | 123 lines |
| `conf.d/done.fish` | `/usr/share/cachyos-fish-config/conf.d/done.fish` | 340 lines |

- `config.fish` only sources `cachyos-config.fish`, then has a commented-out `fish_greeting` override that tells the user how to turn off fastfetch.

**Dependencies:** bat, expac, eza, fastfetch, fish, fish-autopair, fish-pure-prompt, fisher, fzf, pkgfile, tealdeer, ttf-fantasque-nerd.

- **The prompt is Pure** (pure-fish/pure, MIT). It comes from the AUR package's vendor_conf.d and vendor_functions.d files. `cachyos-config.fish` never mentions it.
- **fzf and tealdeer are installed but never configured.** There is no `fzf --fish | source`.

**What `cachyos-config.fish` does:**
- `fish_greeting` runs plain `fastfetch` (L6-8). This is the whole fastfetch integration.
- `MANPAGER "sh -c 'col -bx | bat -l man -p'"` and `MANROFFOPT -c` (L11-12).
- `done.fish` settings use `set -U` universal variables (L15-16).
- Sources `~/.fish_profile` if present.
- `fish_add_path ~/.local/bin ~/.cargo/bin ~/Applications/depot_tools`.
- `!!` and `!$` emulation through key bindings, with a vi-mode variant (L29-54).
- `history` with timestamps.
- `backup` function.
- `copy` function, **broken upstream**: it calls `trim-right`, which nothing defines (L69).
- Aliases (L79-123): eza for `ls`, `la`, `ll`, `lt` and `l.` with `--icons=always`, plus pacman, journalctl and expac helpers. The full list, mapped to FreeBSD, is in section 4.8.

**`done.fish`:**
- It is a vendored copy of franciscolourenco/done v1.19.1, under MIT (the header is in the file).
- To find the focused window it tries, in order: macOS, sway, `hyprctl`, GNOME gdbus, `xprop` and WSL.
- It notifies through `notify-send`, among other methods.

**History settings:** none. Fish's defaults apply.

### 1.2 zsh: package `cachyos-zsh-config` v1.0.3

**Installed files:**
- `/etc/skel/.zshrc`, which is one line: `source /usr/share/cachyos-zsh-config/cachyos-config.zsh`.
- `cachyos-config.zsh`, 105 lines.

**Dependencies:** fzf, oh-my-zsh-git, pkgfile, powerline-fonts, zsh, zsh-autosuggestions, zsh-completions, zsh-history-substring-search, zsh-syntax-highlighting, zsh-theme-powerlevel10k.

**What `cachyos-config.zsh` does:**
- Powerlevel10k instant prompt (L4-6).
- oh-my-zsh from `/usr/share/oh-my-zsh` with `plugins=(git fzf extract)` (L10-28).
- `ENABLE_CORRECTION` (L16).
- `HISTCONTROL` and `PROMPT_COMMAND` (L36, L56). **These are bash-only and do nothing in zsh.**
- `HISTORY_IGNORE` (L42).
- Green-bold man pages through `LESS_TERMCAP_*` and `tput` (L48-49).
- Aliases (L64-88).
- p10k theme, then syntax-highlighting, autosuggestions and history-substring-search (L90-97).
- pkgfile command-not-found (L100).
- Sources `~/.p10k.zsh` if present (L103).

**No `.p10k.zsh` is shipped.** The first start therefore probably opens the p10k wizard (UNVERIFIED; this is p10k's documented behaviour).

**CachyOS's zsh package adds `zprofile`:** `emulate sh -c 'source /etc/profile'`.

### 1.3 bash

CachyOS has no themed bash configuration. It ships Arch's stock files:
- `dot.bashrc`: `ls --color=auto`, `grep --color=auto`, `PS1='[\u@\h \W]\$ '`.
- `system.bashrc`: sets the window title and loads bash-completion.

The live ISO's skel adds `la`, `ll`, `l.`, `df -h` and `free -m` aliases, for the live session only.

### 1.4 fastfetch

**CachyOS ships no fastfetch config.** fish's greeting runs stock `fastfetch`, with the default layout and logo. Its changelog for 24.02 says: "Add option to disable fastfetch when starting the terminal".

### 1.5 How the shell is chosen

1. The installer's netinstall group "CachyOS shell configuration" is selected by default and contains both config packages (`netinstall.yaml` L30-36).
2. The user is created with `/bin/bash` (`users.conf` L90-91).
3. Late in the install, skel is copied into the new home and `shell-setup` runs:
   `for shell in fish zsh; do [ -e /bin/$shell ] && chsh -s /bin/$shell "$user" && break; done`

So **fish wins if it is installed**, then zsh, otherwise bash stays. "Choosing" a shell means unticking packages.

The changelog for 25.07 mentions a shell choice at install time. A dedicated chooser page is UNVERIFIED: none was found at 1f939eb. CachyOS Hello has no shell option.

### 1.6 Terminal look

- **Konsole:** no profile and no monospace font set. Only `ColorScheme=BreezeDark` in kdeglobals.
  - A Nord Konsole scheme exists in CachyOS-Nord-KDE but is never installed.
  - Konsole therefore runs with Plasma defaults. That the default is Hack 10 is UNVERIFIED.
- **Alacritty:**
  - font `monospace` at 12, opacity 0.8, Nord colours (#2E3440 / #D8DEE9)
  - underline cursor, 10000 lines of scrollback
- **Kitty (Hyprland):** `background_opacity 0.6`, `cursor_trail 1`, padding 25, and a theme generated by Noctalia.
- **Default fonts:** noto, noto-emoji and noto-cjk, ttf-dejavu, ttf-liberation, **ttf-meslo-nerd**, awesome-terminal-fonts (`netinstall.yaml` L113-126). The fish config pulls in ttf-fantasque-nerd, but no file references it.

---

## 2. What the other distros ship

**Sources:** clones in `$T/other/`.

| Distro | Login shell | Interactive layer | Prompt | Fetch on start | Terminal / font | Source |
|---|---|---|---|---|---|---|
| **Garuda** | bash (`profile.conf:30,39`) | fish only inside Konsole via the profile's `Command=/usr/bin/fish` | starship, two lines | `__garuda_fastfetch`, called from the user stub ("comment out the line below") | Konsole, Sweet colours, `FiraCode Nerd Font Mono,10`; mokka edition: JetBrainsMono NF 12 | garuda-pkgbuilds 3d68043b, garuda-dr460nized 1280f41 |
| **Manjaro** | zsh (`profile.conf:54,69`) | zsh with autosuggestions, syntax-highlighting, history-substring-search and completions; installs `/root/.zshrc` | p10k, ASCII fallback on the console | none | Konsole + yakuake | manjaro-zsh-config 1f9d0da |
| **EndeavourOS** | bash | bash: `ls --color`, `ll`, history search on the arrows, bash-completion | plain PS1 | none | Konsole, own profile | EndeavourOS-ISO 0bbb128 (live-user skel only; installed defaults UNVERIFIED) |
| **Bluefin** | bash | starship on by default (profile.d + fish vendor_conf.d). "bling" (eza, bat, zoxide, direnv, ugrep) is **opt-in** through `ublue-bling`, as a marker-delimited block appended to the rc file | starship | MOTD with root and nested-shell guards and a per-user off switch; no fastfetch | Ghostty, Catppuccin Mocha, JetBrains Mono | bluefin 12ee46d, bluefin-common d336728 |
| **Bazzite** | bash | `ujust bazzite-cli` installs a Brewfile and the bling block. Offered in the welcome app with `default: false` | starship | none; fastfetch is aliased to a branded preset | — | bazzite e13f4fd |
| **Omarchy** | bash | layered rc: skel sources a system rc. HISTSIZE 32768, `ls`→eza, **`cd`→zoxide**, fzf key bindings only ("completion.bash adds ~25ms"), rich inputrc | starship, one line | only in an About window | **foot** default; JetBrainsMono Nerd Font 9 | omarchy c5f98c652aac |
| **Fedora** | bash | skel sources /etc/bashrc and ~/.bashrc.d; bash-color-prompt | colour PS1 | none | default terminal UNVERIFIED | rpms/bash rawhide |
| **Ubuntu** | bash | skel: ignoreboth, colour PS1 on 256 colours, `ll`/`la`/`l`, bash-completion | colour PS1 | none | UNVERIFIED | launchpad bash debian/skel.bashrc |
| **GhostBSD** | **zsh**, chosen from an installer dropdown | system-wide `/usr/local/etc/zshrc` with packaged autosuggestions and fast-syntax-highlighting, shared history, prefix history search | short-path prompt with git branch | none | Konsole | gbi 4c9c99b, ghostbsd-zsh-settings 12a8a69 |
| **NomadBSD** | chosen at first boot (fish, zsh, bash, csh, sh), applied with `pw usermod -s` | skel rc for every shell; MANPAGER through bat when present | colour PS1 | fish greeting is `fortune freebsd-tips` | sakura | NomadBSD d04a3a8 |
| **helloSystem** | zsh | near-stock rc | default | none | QTerminal | ISO 87c79bf |
| **Caelestia dots** (already used on Hyprland) | unchanged | foot `shell=fish`; config.fish: starship, direnv, `zoxide --cmd cd`, `ls`→eza, git abbrs, OSC 133 | starship | **ASCII logo + fastfetch on every fish start** | foot, `JetBrains Mono Nerd Font:size=12` | caelestia-dots 01d2df3 |

### What the good setups have in common
1. A modern interactive shell: fish, or zsh with the packaged autosuggestions and highlighting.
2. A git-aware starship prompt.
3. A JetBrainsMono or FiraCode Nerd Font with a dark colour scheme.
4. Prefix history search on Up and Down, and case-insensitive menu completion.
5. eza for listings under new names, zoxide, fzf on Ctrl-R and Ctrl-T, bat, and tldr.
6. Defaults kept in system files, with a thin user stub or drop-in.

### What is controversial (evidence)
- **fastfetch on every shell.** This is the most-asked "how do I turn it off" question. Threads (read only as search-result summaries):
  - discuss.cachyos.org/t/…/4604
  - forum.garudalinux.org/t/…/45692
  - forum.garudalinux.org/t/…/41135
  - Garuda's own stub tells users to comment it out.
- **Changing the login shell to fish** confuses newcomers who paste POSIX snippets (CachyOS thread …/28658, summary only). On this project it also breaks code; see 3.2.
- **Aliasing core commands** (`ls`, `cat`, `grep`, `cd`). It changes output that tutorials and scripts expect. On FreeBSD it also hides BSD flags.
- **oh-my-zsh + p10k:** heavy, and unpackaged or stale on FreeBSD (3.1).
- Universal variables (`set -U`) and command-intercepting hooks: not reversible, and surprising.

---

## 3. FreeBSD feasibility

### 3.1 Packages

**Catalogues:**
- `research/pkgsite/packagesite.yaml` is the **latest** branch, FreeBSD:15:amd64 (`FreeBSD_version 1501000`). It is byte-identical to `pkg.freebsd.org/FreeBSD:15:amd64/latest/packagesite.pkg`, fetched 2026-11-16.
- Quarterly was fetched to `$T/pkgsite-both/quarterly/`.
- **Every package below exists in both branches**, which matters because KDE-only installs use quarterly.

| Package | latest / quarterly | Installed size | Key paths |
|---|---|---|---|
| fish | 4.9.1_2 / 4.9.1_1 | 17.3M | `/usr/local/bin/fish`; system `/usr/local/etc/fish/{conf.d,functions,completions}`; vendor `/usr/local/share/fish/vendor_{conf,functions,completions}.d/`. Completions are embedded in the binary, including `pkg`, `service`, `doas`, `zfs`, `zpool` and `kldload`. |
| zsh | 5.9.2 | 19.9M | `/usr/local/bin/zsh`. System rc files are in **`/usr/local/etc`** (`zshenv`, `zprofile`, `zshrc`, `zlogin`; `--enable-etcdir=${PREFIX}/etc`), and none is shipped. `site-functions` is on the default fpath. |
| zsh-autosuggestions | 0.7.1 | 0.01M | `/usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh` |
| zsh-syntax-highlighting | 0.8.0,1 | 0.04M | `/usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh` (source it last) |
| zsh-fast-syntax-highlighting | 1.56_1 | 0.07M | `/usr/local/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh` |
| zsh-completions | 0.36.0 | 1.6M | `/usr/local/share/zsh/site-functions/_*` |
| bash | 5.3.20 | 9.9M | Already installed by `stages/base.sh:46`. Reads `/usr/local/etc/profile` (login) and **`/usr/local/etc/bash.bashrc`** (interactive, through the default SYSBASHRC option, Makefile:38,104). Needs fdescfs, which `stages/system.sh:78` already mounts. |
| bash-completion | 2.18.0,2 | 0.24M | `/usr/local/share/bash-completion/bash_completion.sh`; pulls in bash-completion-freebsd (pkg, service, make, mandoc) and -zfs |
| starship | 1.27.0 / 1.26.0_2 | 10.4M | binary only |
| fastfetch | 2.71.0 / 2.69.0 | 1.75M | Already installed (`stages/base.sh:47`) |
| fzf | 0.75.0_1 / 0.74.4_3 | ~1.9M | Binary only. Hooks: `fzf --fish \| source`, `eval "$(fzf --zsh)"`, `eval "$(fzf --bash)"` (pkg-message) |
| zoxide, eza, bat, tealdeer | yes | small | Already installed for Hyprland (`stages/hyprland.sh:20`), except tealdeer |
| ohmyzsh | 20241128 in both | 6.5M | `/usr/local/share/ohmyzsh`. **Stale.** The port deletes `tools/upgrade.sh`, so `omz update` fails; `ZSH_CUSTOM` defaults to a read-only dir. |
| konsole | 26.08.3 | 10.4M | Ships no `/usr/local/share/konsole`; built-in colour schemes are in Qt resources |
| foot | 1.28.0 | 0.8M | `/usr/local/etc/xdg/foot/foot.ini.sample`, `/usr/local/share/foot/themes/*`; terminfo in `site-terminfo`, which base ncurses searches (`ncurses_cfg.h:74`) |
| nerd-fonts-jetbrainsmono | 3.5.1 | **232M** (96 TTFs) | `/usr/local/share/fonts/nerd-fonts/JetBrainsMono/`. Already installed for Hyprland (`stages/hyprland.sh:15`). |
| nerd-fonts-symbols | 3.5.1 | 4.9M | icons only, through fontconfig fallback |
| `nerd-fonts` meta | 3.5.1 | several GB | **avoid** |

**Not packaged in either branch:** powerlevel10k, zsh-history-substring-search (standalone), fzf-tab, fisher, fish-pure-prompt, fish-autopair, oh-my-posh, zinit, antidote, ble.sh, powerline-fonts, and any command-not-found handler.
- History-substring-search exists only as the bundled ohmyzsh plugin.
- zsh's own `up-line-or-beginning-search` widget gives the same prefix search with no plugin. It is part of zsh's standard function library; that it is present in the FreeBSD package is UNVERIFIED (check `ls /usr/local/share/zsh/*/functions/*beginning-search*`).
- **Starship is the realistic replacement for p10k and Pure.**

### 3.2 Setting the login shell, and why we should not change it

**How the shells register:**
- zsh, fish and bash register themselves in `/etc/shells` (`@shell` in pkg-plist). Inside the installer's chroot (`install.sh:868`), that updates the target's file.
- Deinstalling a shell removes its line again.

**Changing it:**
- `pw usermod USER -s /usr/local/bin/zsh` works in a chroot. Always use the full path: pw's `shelldir` default is `/bin` (`pw_conf.c:93`).
- A full path skips every check (`pw_user.c:440-443`), so the caller must check `[ -x ]` and `/etc/shells` itself.
- `chsh` as a normal user refuses shells not in `/etc/shells` (`chpass/field.c:218-227`).

**Pitfalls:**
1. **fish as the login shell breaks the repo's `as_user`. Verified on Linux fish 4.9.3, not on FreeBSD.**
   - `lib/common.sh:150` runs `su "$TARGET_USER" -c "cd ~ && PATH=... && $*"`, and `su` uses the user's login shell.
   - fish rejects `PATH=...` with: `fish: Unsupported use of '='`.
   - Two callers would break: `stages/desktop.sh:16` (xdg-user-dirs-update) and `stages/caelestia.sh:78`.
   - **Conclusion: never offer fish (or csh) as a login shell.**
2. **zsh as the login shell drops `~/.profile` from desktop sessions.**
   - SDDM's `wayland-session` and `Xsession` run `exec $SHELL --login` for zsh (sddm c2b97dd), and zsh never reads `~/.profile`.
   - That loses `EDITOR`, `PAGER` and `ENV` from the skel, and the PATH line `files/bin/steam-setup:36` appends.
   - Fix: a marked `~/.zprofile` with `emulate sh -c '. ~/.profile'`. **UNTESTED.**
3. A broken fish config, or a removed fish package, can also break graphical login, because SDDM runs the session through the login shell. Whether FreeBSD's sddm uses the upstream script unchanged is UNVERIFIED; the risk stands either way.
4. **zsh-newuser-install appears** whenever `~/.zshenv`, `~/.zprofile`, `~/.zshrc` and `~/.zlogin` are all missing (zsh-5.9 `newuser.c`). **A system `/usr/local/etc/zshrc` does not suppress it.** A per-user `~/.zshrc` is required.

**Recommended path (it already exists in the repo):**
- `stages/caelestia.sh:76-77` keeps the login shell as `sh` and runs fish only inside foot.
- Konsole does the same through a profile's `Command=`.
- If that binary is missing, Konsole falls back to the login shell, then `$SHELL`, then `/bin/sh` (`Session.cpp:510-535`).
- Users are created with `-s /bin/sh` (`install.sh:751-752`), and root's shell is `/bin/sh`.

### 3.3 fastfetch on FreeBSD

**OS row: "Could not detect OS".** From source, and seen in fastfetch issues #1260, #1670 and #2105.
- On FreeBSD, fastfetch builds `os_linux.c`. The port sets `-DTARGET_DIR_ETC=/usr/local/etc`, so it looks for `/usr/local/etc/os-release`.
- FreeBSD only has `/etc/os-release`, which points to `/var/run/os-release` and is written by `rc.d/os-release`.
- With the default `showErrors=false`, the row is silently missing.
- Proposed shim: `ln -s /etc/os-release /usr/local/etc/os-release`. **UNTESTED.** Also worth reporting to the port maintainer.

**Modules (all from source, none run):**
- **Logo:** works. A FreeBSD logo exists, and detection falls back to uname.
- **GPU:** expected to work as a normal user. `/dev/pci` is 0644, and `PCIOCGETCONF` needs no write access.
- **Battery:** expected to work (sysctl plus `/dev/acpi`, mode 0664).
- **Packages:** expected to work (counted from `local.sqlite`).
- **Power adapter and Bluetooth:** not supported on FreeBSD. **Leave them out.**

**System default config:**
- fastfetch searches `~/.config/fastfetch/config.jsonc`, then `$XDG_CONFIG_DIRS`, then `/usr/local/etc/xdg/fastfetch/config.jsonc`, then `/usr/local/etc/` (`FFPlatform_unix.c:245-262`).
- A system default therefore goes in `/usr/local/etc/xdg/fastfetch/config.jsonc`, and the user's copy wins.

**Bug already shipping:**
- `stages/caelestia.sh:54` copies Caelestia's Linux fastfetch config into `~/.config/fastfetch`.
- That config calls `uptime -p` (FreeBSD's `uptime` takes no options, `w.c:596`), `free -m` (does not exist) and `hostnamectl` (systemd), and uses the broken `os` module.
- About 4 of its 7 rows are expected to go missing. This is from source and UNVERIFIED on hardware.

### 3.4 Konsole system presets (verified from Konsole v26.08.3 source)

- **Profiles:** read from `locateAll(GenericDataLocation, "konsole")`, which includes **`/usr/local/share/konsole/*.profile`** (`ProfileReader.cpp:34-46`).
- **Colour schemes:** read from the same dirs, with the built-in ones as fallback.
- **Default profile:** `[Desktop Entry] DefaultProfile=<file>` in `konsolerc`, read through the KConfig cascade (`ProfileManager.cpp:65-74`).
  - A system **`/usr/local/etc/xdg/konsolerc`** works because FreeBSD's plasma-workspace patch makes `XDG_CONFIG_DIRS` default to `/usr/local/etc/xdg:/etc/xdg`, and `files/bin/hypr-session:10` sets the same.
  - The user's own `konsolerc` wins once they change the default.
- **Profile keys** (`Profile.cpp:65-99`): `[General] Name, Command, Icon, Environment, Parent`; `[Appearance] ColorScheme, Font`.
- **Font family name:** checked with `fc-scan` on the FreeBSD package's TTFs. It is **`JetBrainsMono Nerd Font`**; there are also `JetBrainsMono Nerd Font Mono` and `JetBrainsMono NFM`.
- KConfig accepts `#` comments, so the marker can go in these files.

### 3.5 fish config loading order (fish 4.9.1, `share/config.fish:22-48,153-165`)

- **Snippets:** `~/.config/fish/conf.d/*.fish`, then `/usr/local/etc/fish/conf.d/`, then `/usr/local/share/fish/vendor_conf.d/`.
  - Files are de-duplicated by basename, and **the user's file wins**.
  - A user can mask ours with a same-named empty file.
  - conf.d runs before `config.fish`.
- **Function autoloading:** the user's `functions/` comes before the vendor `functions.d`. So a `fish_greeting.fish` in `vendor_functions.d` loses to Caelestia's own `~/.config/fish/functions/fish_greeting.fish`.
  - This order is from the fish docs and source layout, not run on FreeBSD.
- **vendor_conf.d also runs inside Caelestia's fish.** The drop-in must step aside when `~/.config/fish/.caelestia-managed` exists.

### 3.6 Other FreeBSD facts that affect the configs

- **`dmesg` fails for normal users.** `stages/security.sh:37` sets `security.bsd.unprivileged_read_msgbuf 0`. A `jctl`-style alias must use `doas dmesg -a`.
- **`ls`:** base `ls` supports `--color=when` (ls.1 L214), and `-G` and `CLICOLOR` also work. House style: `export CLICOLOR=1` rather than an `ls` alias.
- **`nproc`:** in base since 13.2 (nproc.1 HISTORY).
- **`tput`:** base tput is ncurses, so `tput setaf 2` should work (not run).
- **bsdtar** supports `-a` (auto-compress by suffix) and detects compression when extracting (not run).
- **`ps`:** BSD `ps` has no forest view. `ps aux -m` sorts by memory (ps.1 `-m`).
- **Updates:** the repo's `files/bin/sysup` does `bectl create`, then `pkg upgrade`, then `freebsd-update`. `install.sh:677` and `stages/base.sh:38` already use freebsd-update. **The "update" alias is `sysup`.**
- **Privilege tools:** both `doas` and `sudo` are installed with wheel rules (`stages/base.sh:46-64`).
- **profile.d:** `/usr/local/etc/profile.d/` is already used by `stages/input.sh:27`.
- **Plasma version:** quarterly carries plasma6 **6.7.5**, not 6.8 as CLAUDE.md says (see section 7).

---

## 4. Recommended design for FreeBSD-setup

**Principles:**
- Optional; **the login shell is never changed**.
- The fancy shell runs only inside the terminal app.
- Only packaged software.
- System-level files carry the marker, plus the minimum needed in `~`.
- One per-user off switch that never edits the user's rc files.
- **No core command is redefined** (`ls`, `cat`, `grep`, `cd`): only new names.
- Nothing below has been run.

### 4.1 Wizard

A new question after `wiz_extras`. It needs its own `ui_menu`, because `wiz_extras` is a checklist (`lib/wizard.sh:89-108`) and this is a choice of one:

```
Terminal style
  fish  "Friendly: suggestions as you type, colours, git-aware prompt (recommended)"
  zsh   "Zsh: suggestions and colours, and works with most copy-paste guides"
  bash  "Bash with colours, history search and completion"
  none  "Plain terminal, as FreeBSD ships it"
```

- **Variable:** `TERMINAL_STYLE=none|fish|zsh|bash`. The default is an owner decision (section 7). Suggested: `fish` when a desktop is chosen, `none` for `DESKTOP=none`.
- **Ask it only when `DESKTOP != none`.** With no desktop there is no terminal app, so the choice would have no effect without a login-shell change, which we do not make.
- **Second variable:** `TERMINAL_GREETING=yes|no`, default `yes`. It shows a compact fastfetch at most once per terminal window. It could also be a checkbox in `wiz_extras` instead of a separate question.
- **Places to touch:**
  - `lib/wizard.sh`: the new `wiz_terminal`, the save list (`:193`) and the summary (`:213`).
  - `lib/defaults.conf`: defaults and help text.
  - `setup.sh:27` `STAGES`: add `terminal` **after `caelestia` and before `finish`**.
  - `tests/config-test.sh`: one case per style, plus `DESKTOP=none`, which must give `TERMINAL_STYLE=none`.
- **Later and optional:** a separate `LOGIN_SHELL=sh|zsh|bash`, never fish. It would need:
  - the `~/.zprofile` fix (3.2);
  - an `as_user` that does not depend on the login shell, e.g. `su -m` with `SHELL=/bin/sh`, or `env /bin/sh -c` (UNTESTED).
  - Recommend not doing this now.

### 4.2 New stage `stages/terminal.sh`

- Chroot-safe: package installs and file writes only. Safe to run again. Ends with `true`.
- **`TERMINAL_STYLE=none`:** remove only our marked files (konsolerc default, profile, drop-ins) and return. This makes switching back clean.
- **Packages:**
  - Every style: `starship fzf zoxide eza bat tealdeer` and the font (4.6). `fastfetch` is already in base.
  - `fish`: `fish`
  - `zsh`: `zsh zsh-autosuggestions zsh-syntax-highlighting zsh-completions`
  - `bash`: `bash-completion` (bash is already in base)
- **Rc files for every shell that is installed, whatever the style.** They are inert unless that shell runs, so a user who later types `zsh` or `bash` also gets a good experience.
- **Write-guard for system files:** write `/usr/local/etc/zshrc`, `/usr/local/etc/bash.bashrc`, `/usr/local/etc/xdg/konsolerc` and `/usr/local/etc/xdg/foot/foot.ini` **only if the file is absent or already carries `Written by FreeBSD-setup`**. Otherwise warn in plain words: "Your own /usr/local/etc/zshrc was kept; the terminal style for zsh is not active."
- Suggested helper in `lib/common.sh`: `sys_file src dst`, mirroring the existing `user_file` (`lib/common.sh:155-166`).
- **Collision rule:** the stage must **never** write `~/.config/fish`, `~/.config/foot` or `~/.config/starship.toml`. `stages/caelestia.sh:54-65` moves any unmarked copy aside.

### 4.3 Files to add under `files/shell/`, and where they go

| Repo file | Installed to | Guard | Purpose |
|---|---|---|---|
| `files/shell/freebsd-setup.fish` | `/usr/local/share/fish/vendor_conf.d/freebsd-setup.fish` | ours alone (unique name) | fish defaults |
| `files/shell/fish_greeting.fish` | `/usr/local/share/fish/vendor_functions.d/fish_greeting.fish` | ours alone; user and Caelestia functions win | greeting |
| `files/shell/zshrc` | `/usr/local/etc/zshrc` | absent or marked | zsh defaults (read for every interactive zsh, before `~/.zshrc`) |
| `files/shell/dot.zshrc` | `~/.zshrc` via `user_file` (only if absent), and `/usr/share/skel/dot.zshrc` (absent or marked) for future users | as stated | marked stub that stops zsh-newuser-install; "add your own settings below" |
| `files/shell/bash.bashrc` | `/usr/local/etc/bash.bashrc` | absent or marked | bash defaults (SYSBASHRC, interactive shells) |
| `files/shell/starship.toml` | `/usr/local/etc/starship.toml` | ours alone | prompt; used through `STARSHIP_CONFIG` only when `~/.config/starship.toml` is absent |
| `files/shell/fastfetch.jsonc` | `/usr/local/etc/xdg/fastfetch/config.jsonc` | absent or marked | FreeBSD-correct system default |
| (symlink, created by the stage) | `/usr/local/etc/os-release` → `/etc/os-release` | only if absent | fastfetch OS row (UNTESTED) |
| `files/shell/FreeBSD.profile` | `/usr/local/share/konsole/FreeBSD.profile` | ours alone | Konsole profile; the stage substitutes `Command=` from `TERMINAL_STYLE` |
| `files/shell/konsolerc` | `/usr/local/etc/xdg/konsolerc` | absent or marked | `DefaultProfile=FreeBSD.profile` |
| `files/shell/foot.ini` | `/usr/local/etc/xdg/foot/foot.ini` | absent or marked | for Hyprland without Caelestia (`INSTALL_CAELESTIA=no`); Caelestia's `~/.config/foot/foot.ini` overrides it |
| `files/bin/terminal-style` | `/usr/local/bin/terminal-style` | — | per-user switch: `terminal-style off|on|greeting-off|greeting-on|status`; only creates or removes files in `~/.config/freebsd-setup/` |

- **Nothing in `~` other than the optional `~/.zshrc` stub.** This is stronger than Garuda (writes `~/.local/share/konsole`) and Bluefin (appends to rc files).
- **Per-user switches**, checked by every drop-in:
  - `~/.config/freebsd-setup/terminal-off`: no styling at all; plain shell, still launched by Konsole.
  - `~/.config/freebsd-setup/greeting-off`: no fastfetch.

**Guards shared by all drop-ins** (order matters):
1. Interactive shell only.
2. Return if the `terminal-off` marker exists.
3. fish only: return if `~/.config/fish/.caelestia-managed` exists, because Caelestia already sets up starship, zoxide and eza.
4. Fancy prompt only when not on the text console: `case $(tty) in /dev/ttyv*) plain;; esac`. FreeBSD vt consoles are `/dev/ttyv*`, and Nerd-font glyphs show as boxes there.

**Sketch of `/usr/local/share/fish/vendor_conf.d/freebsd-setup.fish`** (not run):

```fish
# Written by FreeBSD-setup. Turn off: terminal-style off
status is-interactive; or return
test -e ~/.config/freebsd-setup/terminal-off; and return
test -e ~/.config/fish/.caelestia-managed; and return   # Caelestia has its own

set -gx CLICOLOR 1
fish_add_path -g ~/.local/bin
test -e ~/.config/starship.toml; or set -gx STARSHIP_CONFIG /usr/local/etc/starship.toml
if not string match -q '/dev/ttyv*' (tty)
    command -q starship; and starship init fish | source
end
command -q zoxide; and zoxide init fish | source          # gives z / zi, not cd
command -q fzf; and fzf --fish | source                    # Ctrl-R, Ctrl-T, Alt-C
if command -q eza
    abbr -a ll 'eza -l --group-directories-first --icons=auto --git'
    abbr -a la 'eza -la --group-directories-first --icons=auto --git'
    abbr -a lt 'eza --tree --level=2 --icons=auto'
end
# no set -U anywhere: everything here disappears when the file is removed
```

- `fish_greeting.fish`: show fastfetch only when all of these hold:
  - `fish_is_root_user` is false;
  - stdout is a tty;
  - `$FBS_GREETED` is unset (then `set -gx FBS_GREETED 1`, so nested shells and splits that inherit the env stay quiet);
  - no `greeting-off` marker.
  - Otherwise print nothing; this replaces fish's "Welcome to fish" text.

**`/usr/local/etc/zshrc`** (same guards in sh syntax):
- **History:** `HISTFILE=~/.zsh_history`, `HISTSIZE=SAVEHIST=10000`, `setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE`, and CachyOS's `HISTORY_IGNORE` idea.
- **Completion:** `autoload -Uz compinit && compinit`; case-insensitive menu completion: `zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'` and `menu select`.
- **Prefix history search on Up and Down:** `up-line-or-beginning-search` / `down-line-or-beginning-search` (zsh's own widgets; presence in the FreeBSD package UNVERIFIED). Bind both `^[[A` and `$terminfo[kcuu1]`.
- **Tools:** starship, zoxide and fzf init as in fish; `CLICOLOR=1`; `ll`/`la`/`lt` aliases.
- **Plugins, in this order:** `zsh-autosuggestions.zsh`, then **`zsh-syntax-highlighting.zsh` last**. Each is wrapped in `[ -r ]`.
- **Not used by default:** oh-my-zsh, p10k, `setopt correct`.
- **Caveat:** this file runs before `~/.zshrc`, so widgets the user defines later are not wrapped by syntax-highlighting. Acceptable; document it.

**`/usr/local/etc/bash.bashrc`:**
- Return unless `[[ $- == *i* ]]`.
- Source `/usr/local/share/bash-completion/bash_completion.sh`.
- `bind '"\e[A": history-search-backward'` and the matching `"\e[B"` binding.
- `shopt -s histappend checkwinsize`; `HISTCONTROL=ignoreboth`, `HISTSIZE=10000`.
- starship (not on `ttyv*`), zoxide, `eval "$(fzf --bash)"`, the same `ll`/`la`/`lt`, `CLICOLOR=1`.
- **Limit:** a login bash reads `/usr/local/etc/profile`, not bash.bashrc. That is fine, because Konsole and foot start non-login shells by default.

### 4.4 Starship prompt (`/usr/local/etc/starship.toml`)

Written from scratch; nothing copied.
- One line: `directory` (truncated to 3), `git_branch`, `git_status`, `cmd_duration` (≥ 2 s), `character` (❯, red on error).
- `add_newline = false`.
- Glyphs need only the Nerd symbols range, so `nerd-fonts-symbols` fallback could be enough (UNVERIFIED, 4.6).
- Leave out the `os`, `battery` and `time` modules: less noise and no platform risk.
- `STARSHIP_CONFIG` is set only when `~/.config/starship.toml` is absent. Caelestia's copy (installed only if missing, `stages/caelestia.sh:65`) and any user copy win.

### 4.5 fastfetch (`/usr/local/etc/xdg/fastfetch/config.jsonc`)

Only modules that are verified from source, or ordinary modules not known to be Linux-only. Never a `command` module.

```jsonc
// Written by FreeBSD-setup. Your own ~/.config/fastfetch/config.jsonc replaces this.
{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": { "source": "freebsd_small", "padding": { "right": 2 } },
  "display": { "separator": "  " },
  "modules": [
    "title", "separator",
    "os", "host", "kernel", "uptime", "packages", "shell",
    "de", "wm", "terminal",
    "cpu", "gpu", "memory", "disk", "battery",
    "break", "colors"
  ]
}
```

- **Leave out:** `poweradapter` and `bluetooth` (not supported on FreeBSD), `localip`/`publicip` (privacy and screenshots), and all `command` modules.
- **Only some modules have a source check:** `os` (needs the shim), `gpu`, `battery`, `packages` and the logo. `host`, `de`, `wm`, `terminal`, `cpu`, `memory` and `disk` are UNVERIFIED on FreeBSD.
- Before shipping, run `fastfetch --show-errors` on the laptop and in the VM, and drop any module that errors.
- The `freebsd_small` logo name comes from fastfetch's logo list (`f.inc:222-246`).
- **Fix the Caelestia copy as well:** after `stages/caelestia.sh:54` copies the dots, overwrite `~/.config/fastfetch/config.jsonc` with a FreeBSD version. The directory is already caelestia-managed, so this is project-owned. This is item 1 of section 6.

### 4.6 Konsole profile, foot and fonts

**`/usr/local/share/konsole/FreeBSD.profile`** (keys from `Profile.cpp`):

```ini
# Written by FreeBSD-setup
[General]
Name=FreeBSD
Parent=FALLBACK/
Command=/usr/local/bin/fish
Environment=TERM=xterm-256color,COLORTERM=truecolor

[Appearance]
ColorScheme=Breeze
Font=JetBrainsMono Nerd Font,11
```

- `Command=` is the full path chosen by `TERMINAL_STYLE`.
- **Do not use the wrapper** `/bin/sh -c 'exec fish 2>/dev/null || exec /bin/sh -l'` proposed in one report. In a non-interactive POSIX sh, a failed `exec` exits the shell, so the fallback never runs.
- Konsole already falls back to the login shell, then `$SHELL`, then `/bin/sh`, when the binary is missing (`Session.cpp:510-535`).
- If a wrapper is ever wanted: `command -v fish >/dev/null && exec fish; exec sh -l`.
- That the short `Font=Family,size` form is accepted (Konsole normally stores the full `QFont::toString`) is UNVERIFIED. Check it in the VM, and store the full string if not.
- `ColorScheme=Breeze` is built into Konsole. A dark scheme follows from the Plasma theme; a custom `.colorscheme` is optional and can go in `/usr/local/share/konsole/`.

**`/usr/local/etc/xdg/konsolerc`:**

```ini
# Written by FreeBSD-setup
[Desktop Entry]
DefaultProfile=FreeBSD.profile
```

**foot (Hyprland without Caelestia only):** `/usr/local/etc/xdg/foot/foot.ini`:
- `[main] shell=/usr/local/bin/fish` (or the chosen shell), `font=JetBrainsMono Nerd Font:size=11`, `pad=8x8`.
- Colours via `include=/usr/local/share/foot/themes/<theme>`; the `include=` directive in foot 1.28 is UNVERIFIED.
- Caveat: TERM=`foot` is unknown to remote hosts over ssh.
- With Caelestia, leave foot alone. Its foot.ini already has `shell=fish` and the font.

**Fonts:**
- The family name `JetBrainsMono Nerd Font` was verified with fc-scan on the FreeBSD TTFs.
- Caelestia's spaced `JetBrains Mono Nerd Font` resolved via `fc-match` on Linux only.
- **Choice for KDE:**

| Option | Installed size | Notes |
|---|---|---|
| (a) `nerd-fonts-jetbrainsmono` | **232M** | Already present when Hyprland is chosen |
| (b) `jetbrains-mono` + `nerd-fonts-symbols` | ~5M plus jetbrains-mono's size | Konsole's per-glyph fallback to the symbols font is UNVERIFIED |

- **Recommendation:** (a) when Hyprland is also installed (no extra cost), otherwise (b), if the VM shows icons rendering. Owner decision.

### 4.7 Greeting policy

- Default: fastfetch with the compact config above, **once per terminal window**, through the `FBS_GREETED` environment guard (like Bluefin's `UWELCOME_SHOWN`).
- Never for root.
- Only when stdout is a tty.
- Off for one user with `terminal-style greeting-off`; off for everyone with `TERMINAL_GREETING=no`.
- Caelestia's own greeting (fastfetch on every fish) is untouched by this. Whether to quiet it via `~/.config/caelestia/user-config.fish` is an open question.

### 4.8 Linux → FreeBSD substitutions for every CachyOS alias and setting

**Policy:** new names only. Each row is either kept (with the FreeBSD form) or dropped with a reason. "Not run" means it comes from man pages or source.

**fish (`cachyos-config.fish`):**

| CachyOS | FreeBSD-setup | Why |
|---|---|---|
| `fish_greeting` → `fastfetch` | once-per-window greeting (4.7) | every-shell fastfetch is the top complaint |
| `MANPAGER "sh -c 'col -bx \| bat -l man -p'"` | optional, only if bat exists: same pipeline (`col` is in base) | works in principle with mandoc; UNVERIFIED. Simpler default: `LESS_TERMCAP_*` colours |
| `MANROFFOPT "-c"` | drop | groff/man-db option; FreeBSD uses mandoc (probably no effect, UNVERIFIED) |
| done.fish + `set -U __done_*` | drop on KDE; maybe later on Hyprland | focus detection falls to `xprop` on Plasma Wayland and probably misfires (UNVERIFIED); `set -U` is not reversible |
| `~/.fish_profile` | drop | non-standard |
| `fish_add_path ~/.local/bin ~/.cargo/bin ~/Applications/depot_tools` | `fish_add_path -g ~/.local/bin` | others are developer-specific; `-g` avoids a universal variable |
| `!!` / `!$` bindings | rewrite as an abbr with `--position anywhere --function` (fish documented pattern) | own code, not copied; not run |
| `history --show-time='%F %T '` | keep | fish built-in |
| `backup FILE` → `cp FILE FILE.bak` | keep, rewritten: `cp -- $argv[1] $argv[1].bak` | portable |
| `copy` | drop | broken upstream (`trim-right`); `cp -R` does it |
| `ls` = `eza -al … --icons=always` | **do not alias ls**; `CLICOLOR=1` for base ls | keeps BSD `ls` flags and output for tutorials |
| `la`, `ll`, `lt`, `l.` (eza) | `ll`, `la`, `lt` as abbrs with `--icons=auto` | `always` puts icon bytes into pipes |
| `grubup` | drop | no GRUB; loader/EFI |
| `fixpacman` | drop | no pacman lock |
| `tarnow` = `tar -acf` | keep (bsdtar `-a`) | not run |
| `untar` = `tar -zxvf` | `untar` = `tar -xvf` | bsdtar detects compression; `-z` would fail on .xz and .zst |
| `wget -c` | drop (wget not installed); FreeBSD `fetch -r` resumes | not run |
| `psmem` / `psmem10` = `ps auxf \| sort -nr -k 4` | `psmem` = `ps aux -m \| head -20`, `psmem10` = `ps aux -m \| head -11` | BSD ps has no forest view; `-m` sorts by memory (ps.1) |
| `..` … `......` | keep (`..`, `...`, `....`) | harmless |
| `dir`, `vdir` | drop | GNU coreutils only |
| `grep`/`fgrep`/`egrep --color=auto` | drop | do not redefine core commands |
| `hw` = `hwinfo --short` | `hw` = `freebsd-setup --report` (setup.sh `--report`) or `pciconf -lv` | no hwinfo; whether `--report` needs root is UNVERIFIED |
| `big` (expac sizes) | `big` = `pkg query '%sb %n' \| sort -n \| tail -40` | `%sb` = flat size in bytes (pkg-query(8)) |
| `gitpkg` | drop | no -git packages |
| `update` = `cachyos-rate-mirrors && pacman -Syu` | `update` = `sysup` | repo tool: boot environment + pkg + freebsd-update |
| `mirror` | drop | pkg.FreeBSD.org is a CDN |
| `apt`, `apt-get` → `man pacman` | a small function that prints "FreeBSD uses pkg: pkg search NAME, doas pkg install NAME" | friendlier than opening a man page |
| `tb` = `nc termbin.com 9999` | **drop** | pastes to a public service; privacy risk for non-experts |
| `cleanup` = `pacman -Rns $(pacman -Qtdq)` | `cleanup` = `doas pkg autoremove && doas pkg clean` | |
| `jctl` = `journalctl -p 3 -xb` | `jctl` = `doas dmesg -a \| less` | **plain `dmesg` fails for users** (`security.sh:37` `unprivileged_read_msgbuf 0`); `/var/log/messages` readability for users UNVERIFIED |
| `rip` (expac install dates) | `rip` = `pkg query '%t %n-%v' \| sort -n \| tail -200` | `%t` = install timestamp (epoch) |

**zsh-only items (`cachyos-config.zsh`):**

| CachyOS | FreeBSD-setup | Why |
|---|---|---|
| p10k instant prompt + theme + `~/.p10k.zsh` | starship | p10k not packaged; needs its own font and wizard |
| oh-my-zsh from `/usr/share/oh-my-zsh` | not used by default | port is stale (20241128), `omz update` broken, read-only `ZSH_CUSTOM` |
| `DISABLE_MAGIC_FUNCTIONS`, `COMPLETION_WAITING_DOTS` | drop | oh-my-zsh settings |
| `ENABLE_CORRECTION` | drop | correction prompts confuse newcomers (Manjaro's `setopt correct` as well) |
| `plugins=(git fzf extract)` | fzf: `eval "$(fzf --zsh)"`; extract: `extract` = `tar -xf` (libarchive reads zip, 7z, rar; not run); git: drop | omz git plugin adds ~200 aliases |
| `HISTCONTROL`, `PROMPT_COMMAND` | drop; zsh `setopt` equivalents in 4.3 | bash-only, no effect in zsh upstream either |
| `HISTORY_IGNORE` | keep, rewritten | zsh feature |
| `LESS_TERMCAP_md/me` via `tput` | keep (ncurses tput) | not run |
| `make` / `ninja` `-j$(nproc)` | drop | redefining `make` changes ports and buildworld behaviour; ninja is already parallel |
| `n` = ninja, `c` = clear | drop | clutter; Ctrl-L clears |
| `rmpkg` = `pacman -Rsn` | `rmpkg` = `doas pkg delete` | |
| `cleanch` = `pacman -Scc` | `doas pkg clean -a` (folded into `cleanup`) | |
| `please` = sudo | keep: `please` = `sudo` | sudo installed with a wheel rule |
| zsh-syntax-highlighting, autosuggestions | packaged paths in 3.1 | |
| zsh-history-substring-search | zsh `up-line-or-beginning-search` | not packaged standalone |
| pkgfile command-not-found | none by default | no FreeBSD handler. `pkg-provides` uses a third-party database ("not part of the FreeBSD project"); possible opt-in later |
| `FZF_BASE=/usr/share/fzf` | drop | fzf 0.75 embeds its shell integration |

**bash (Arch/CachyOS stock + live skel):**

| Item | FreeBSD-setup |
|---|---|
| `ls --color=auto` | `CLICOLOR=1` |
| `grep --color=auto` | drop |
| `PS1='[\u@\h \W]\$ '` | starship; colour PS1 fallback on `ttyv*` |
| bash-completion | `/usr/local/share/bash-completion/bash_completion.sh` |
| `df -h` | drop (no core-command redefinition) |
| `free -m` | drop: no `free` command; `top` or fastfetch `memory` covers it |

---

## 5. Licensing and attribution

FreeBSD-setup is **BSD-2-Clause** (`LICENSE`).

**CachyOS licences:**
- **cachyos-fish-config:** "MIT" only in the PKGBUILD; **no LICENSE file in the repo**.
- **cachyos-zsh-config, cachyos-kde-settings, cachyos-alacritty-config:** GPL-1.0-only, again from the PKGBUILD only.
- **CachyOS-Nord-KDE, CachyOS-Emerald-KDE:** GPL-3.0-or-later.
- **cachyos-hypr-noctalia:** no licence at all.
- **CachyOS-Settings, cachyos-welcome, CachyOS-Live-ISO:** GPL-3.

**Decision: copy nothing from CachyOS, Garuda (GPL-3) or Bluefin.**
- The useful content is ideas: an alias list, a plugin set, Nord colours.
- Write it fresh, and credit "inspired by CachyOS, Garuda, Bluefin, GhostBSD" in a comment or the docs.
- This is a judgement, not legal advice.

**Upstream projects** (only if ever vendored, keeping their notices):
- MIT: done.fish (header in the file), pure-fish/pure, autopair.fish, fisher, ohmyzsh, zsh-autosuggestions.
- BSD-3: zsh-syntax-highlighting.
- **The recommended design vendors none of them:** it uses packages only, and starship instead of Pure.

**Fonts:**
- Nerd Fonts JetBrainsMono is OFL-1.1 and is installed from packages, not redistributed by us.
- Nerd-font glyph sets carry their own upstream licences; these are handled by the package.

**Konsole colour scheme:** Breeze is built into Konsole. Any custom `.colorscheme` we write is ours.

---

## 6. Out-of-box polish beyond the terminal (prioritised: value ÷ risk)

The HANDOFF already tracks networking, Bluetooth, power profiles, sensors, suspend, updates and first login (§4.1-4.6, §7); they are not repeated here.

1. **Fix Caelestia's fastfetch config, and add the os-release shim.** It ships today and breaks the rule that a control which cannot work must not be shown broken.
   - About 4 of its 7 rows call `uptime -p`, `free` and `hostnamectl`, or depend on the broken `os` module.
   - Fix: replace them with built-in modules and add `/usr/local/etc/os-release` → `/etc/os-release` (UNTESTED).
2. **Turn off Baloo file indexing.** Install `/usr/local/etc/xdg/baloofilerc` with `[Basic Settings] Indexing-Enabled=false`.
   - kf6-baloo uses libinotify, which emulates inotify with kqueue. Watching for close-write, modify and attribute changes opens every file in a watched dir, and its README warns you "can run out of file descriptors".
   - CachyOS ships the same setting.
   - Cost: slower Dolphin and KRunner file search.
   - That descriptors actually run out here is inferred. Check with `fstat -p $(pgrep baloo_file) | wc -l`.
3. **Firefox `policies.json`** in `/etc/firefox/policies/` (read on FreeBSD GTK builds; verified from Firefox source).
   - Turn off: telemetry, studies, Pocket, the default-browser check, sponsored tiles, user messaging.
   - **Do not** force DoH or remove search engines, as CachyOS does.
   - **Do not** force hardware video decoding until `about:support` shows it working on the laptop.
4. **A CJK fallback font for everyone:** `noto-sans-sc` (~207 MB), which covers SC, TC, JP and KR according to its pkg-descr. Glyph coverage for kana and Hangul is UNVERIFIED; check with `fc-list :lang=ja`.
   - Today `stages/desktop.sh:8-12` installs about 1.7 GB of sans+serif metapackages, and only when CJK is chosen.
5. **KDE system defaults in `/usr/local/etc/xdg`.** They work in a chroot, and the user's own settings always win.
   - `kdeglobals [KDE] LookAndFeelPackage=org.kde.breezedark.desktop`, and **not** ColorScheme directly.
   - `konsolerc` (from this design).
   - `arkrc openDestinationFolderAfterExtraction=true`.
   - `kcm-about-distrorc` to brand System Settings' About page (keys verified in kinfocenter 6.8.3).
   - The wallpaper and panel need a theme package or a Plasma update script instead.
6. **Printer drivers:** `hplip`, `brlaser`, `splix`, `epson-inkjet-printer-escpr` (all packaged, both branches). Whether `cups_browsed` is needed is UNVERIFIED.
7. **Earlier file versions from Dolphin:** a Places entry for `.zfs/snapshot`, plus a service menu using `httm`. That home is its own dataset is UNVERIFIED.
8. **Help viewer:** `khelpcenter` (9 MB), since the Help → Handbook menus have no viewer without it. `tealdeer` comes with the terminal extra.
9. **A KDE video player** when `INSTALL_APPS=no`: `haruna`.
10. **Small KDE apps (optional):** `filelight`, `kfind`, `kio-fuse`, `kwalletmanager`.
    - `kdeconnect-kde` also needs pf ports 1714-1764. Those ports are inferred, not read from source.
11. **Update notices:** PackageKit's FreeBSD backend implements get_updates. Discover may already notify (UNVERIFIED), but updates applied through it bypass `sysup`'s boot environment.
    - Idea: a pkg plugin hook (`PKG_PLUGIN_HOOK_PRE_UPGRADE`) that creates the boot environment.
12. **First-login welcome.** Plasma Welcome is not packaged, and CachyOS Hello is not portable.
    - A Garuda-style run-once autostart entry plus a tiny page of links is the portable pattern.
13. **Leave alone:**
    - fontconfig defaults: already sane. If bitmaps are ever turned off, use `70-no-bitmaps-except-emoji.conf`, because noto-emoji is a bitmap font here.
    - Kvantum: a second theme system.
    - Branded wallpaper packages exist but need the theme-package route.
14. **Not possible with packages on FreeBSD 15:** Flatpak and AppImage, fwupd in Discover, Plasma Welcome.

---

## 7. Open questions for the owner

1. **Default for the terminal style:** `fish` (CachyOS-like, recommended), `zsh` (works with copy-paste guides), or `none`/opt-in (Bluefin and Bazzite: `default: false`)?
2. **Fastfetch greeting:** on by default (once per window) or off with a one-line tip? And should Caelestia's own every-start fastfetch be quieted to match?
3. **Login shell:** offer `zsh`/`bash` as a real login shell at all (needs the `~/.zprofile` fix and a login-shell-independent `as_user`)? Fish as a login shell is ruled out (3.2).
4. **Font on KDE-only installs:** `nerd-fonts-jetbrainsmono` (232M) or `jetbrains-mono` + `nerd-fonts-symbols` (~5M plus the base font), if Konsole's glyph fallback works in the VM?
5. **Existing users:** apply the `~/.zshrc` stub only to `TARGET_USER`, or to every user in `wheel`? Future users get it through `/usr/share/skel/dot.zshrc`.
6. **Defaults when `DESKTOP=none`:** keep `TERMINAL_STYLE=none` and skip the question (proposed)?
7. **Colour scheme:** stock Breeze/Breeze Dark (zero maintenance), or a project-written dark scheme in `/usr/local/share/konsole/` for a distinct look?
8. **CLAUDE.md correction:** quarterly carries plasma6 **6.7.5**, not 6.8, so KDE-only installs get 6.7.5. Not edited here.
9. **Command-not-found:** worth an opt-in `pkg-provides`-based handler? Its database is third-party and needs downloading.

### Must be checked in the VM or on hardware before claiming any of this works

- `fastfetch --show-errors` for every module in 4.5.
- The os-release shim.
- Konsole picks up `/usr/local/share/konsole/FreeBSD.profile` and `/usr/local/etc/xdg/konsolerc` (verified from source only).
- The short `Font=` form.
- `fc-list | grep -i jetbrains` on FreeBSD.
- Glyph fallback with `nerd-fonts-symbols`.
- zsh `up-line-or-beginning-search` is present.
- fish vendor function order for `fish_greeting`.
- foot `include=` in 1.28.
- The bsdtar, `fetch -r`, `tput` and MANPAGER pipelines.
- `/var/log/messages` permissions.
- The `as_user` fish failure on FreeBSD fish 4.9.1 (only reproduced on Linux 4.9.3).
