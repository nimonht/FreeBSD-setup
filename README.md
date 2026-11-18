# FreeBSD-setup

Install FreeBSD 15 as a ready-to-use desktop with one command and a few
questions.

FreeBSD-setup is a guided installer plus setup wizard for FreeBSD 15. It checks
your computer, tells you what will and won't work on it, installs FreeBSD on
ZFS (whole disk, or next to Windows/Linux), and sets up a complete desktop with
the right drivers for your hardware:

- KDE Plasma (recommended, familiar if you come from Windows), Hyprland with
  the Caelestia shell (a modern tiling desktop, for the adventurous), or both
- Drivers picked automatically: Intel, AMD and NVIDIA graphics (each NVIDIA
  card gets the driver branch NVIDIA lists for it), firmware for GPUs and Wi-Fi,
  CPU microcode, laptop touchpads, hotkeys and power saving
- ZFS with automatic snapshots and boot environments: your files have hourly
  and daily versions to go back to, and every update can be undone with one
  reboot
- Sound (PipeWire), printers and scanners, USB drives and phones, input
  methods for Vietnamese, Chinese, Japanese and Korean, a firewall
- Optional: everyday apps (Firefox, LibreOffice, VLC, GIMP), gaming (Steam,
  Wine/Proton), developer tools

## Is FreeBSD right for you?

Read this before you install. FreeBSD is not a drop-in replacement for Linux,
Windows or macOS on a desktop or laptop: it supports less hardware and runs
less software, and no setup script can change that.

| | Linux (e.g. CachyOS) | Windows / macOS | FreeBSD with this setup |
|---|---|---|---|
| KDE Plasma / Hyprland desktop | Yes | No | Yes, needs a real GPU (below) |
| Intel / AMD graphics | Yes | Yes | Yes (not yet: Intel Lunar Lake/Battlemage; AMD Radeon RX 9000 may not work yet) |
| NVIDIA graphics | Yes | Yes | Yes for GTX 750 / 900 series and newer; older cards: no Wayland desktop |
| Laptop hybrid graphics | Yes, GPU powers off | Yes | Partly: games on the fast GPU with `gpu-run`; it cannot power off, so battery life suffers |
| Wi-Fi | Yes | Yes | Mostly: Intel and Realtek work, newer MediaTek/Qualcomm chips are recent additions, Broadcom does not work. Often slower than on Linux |
| Bluetooth | Yes | Yes | Barely: keyboards/mice paired by hand; no Bluetooth headphones |
| Sleep (suspend) | Yes | Yes | Sometimes: works on many Intel laptops (S3). Closing the lid does nothing on laptops with an NVIDIA driver and on "modern standby" laptops. No hibernate |
| Sound | Yes | Yes | Yes, except laptops with Intel "Smart Sound"/SOF audio |
| Webcam, printers, scanners, USB drives | Yes | Yes | Yes (most webcams; driverless network printers) |
| Fingerprint / face login | Mostly | Yes | No |
| Running in VirtualBox / VMware | Yes | Yes | Console only: these desktops need a 3D graphics driver that VMs don't have on FreeBSD |
| Browsers | Chrome, Firefox | All | Firefox, Chromium (no official Chrome) |
| Office | LibreOffice, OnlyOffice | MS Office | LibreOffice |
| Netflix/Spotify/Discord/Zoom/Teams apps | Yes (Flatpak) | Yes | Web versions only; no Flatpak/Snap/AppImage |
| Steam games | Yes (Proton) | Yes | Some: the Linux Steam client through a compatibility layer; many games run, anti-cheat games don't, things break more often |
| Snapshots and undo | Yes (Btrfs) | System Restore / Time Machine | Yes: ZFS snapshots and boot environments |
| Disk encryption | Yes | BitLocker / FileVault | Yes, optional: FreeBSD's whole partition (GELI, AES-256); the passphrase is typed at every start |

FreeBSD suits you if you like its design and ZFS, your hardware is in the
supported range, and you mostly use open-source software and web apps. It does
not suit you if you need specific commercial apps, competitive online games,
long battery life on a gaming laptop, or Bluetooth audio. Dual boot keeps your
other system for those.

## What you need

- A 64-bit PC (amd64) with 8 GB RAM (4 GB minimum) and 40 GB of free disk
  space (30 GB minimum)
- A real graphics card for the desktop: Intel HD/UHD/Iris/Arc integrated
  graphics, an AMD Radeon, or an NVIDIA GeForce GTX 750 or newer
- UEFI firmware to install next to Windows/Linux (legacy BIOS: whole disk only)
- Secure Boot switched off in the firmware setup (FreeBSD's boot loader is
  not signed by Microsoft)
- An internet connection during installation (Ethernet is easiest; Wi-Fi works
  with supported cards)
- A USB stick of 2 GB or more

Not sure? The installer's first screen is a hardware report, and nothing is
written before the very last confirmation, so you can safely look and quit.

## Install

### 1. Back up

Back up everything you cannot lose. If you keep Windows, switch off Fast
Startup (Control Panel → Power Options → "Choose what the power buttons do")
and save the BitLocker recovery key (<https://aka.ms/myrecoverykey>):
Windows asks for it once after Secure Boot is switched off. See
[docs/DUAL-BOOT.md](docs/DUAL-BOOT.md#windows) for how to avoid the prompt.

### 2. Make room (only when keeping another system)

FreeBSD needs unallocated space on the disk; the installer creates its
partitions there and never touches existing ones.

- From Windows: *Disk Management* → right-click your largest partition →
  *Shrink Volume*. Leave the freed space "Unallocated".
- From Linux: boot a live USB and shrink a partition with GParted or KDE
  Partition Manager.

### 3. Write the USB stick

Download `FreeBSD-15.1-RELEASE-amd64-memstick.img` from
[download.freebsd.org](https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/15.1/)
and write it to the stick (this erases the stick):

- Windows: [Rufus](https://rufus.ie) (choose *DD image* mode) or [balenaEtcher](https://etcher.balena.io)
- macOS / Linux: balenaEtcher, or `sudo dd if=FreeBSD-15.1-RELEASE-amd64-memstick.img of=/dev/<stick> bs=1M status=progress`

### 4. Boot it and run the installer

1. Restart with the stick plugged in and open the boot menu (usually F12,
   F8, F11 or Esc right after power-on; on Macs hold Option). Pick the USB
   stick (UEFI).
2. At the blue *Welcome* screen choose *Live System*, then log in as `root`
   (no password). Not a US keyboard? Run `kbdmap` and pick your layout first,
   so the keys type what is printed on them (the Wi-Fi password below, and
   the commands). The installer asks for the layout again and uses it for
   your passwords; only the disk-encryption passphrase is typed with the US
   layout, because that is the layout when the computer starts.
3. Connect to the internet:

   ```sh
   env BSDINSTALL_CONFIGCURRENT=yes bsdinstall netconfig
   ```

   Type it exactly like this: `BSDINSTALL_CONFIGCURRENT=yes` tells the tool
   to bring the network up right now in the Live System. Without it, Wi-Fi
   setup stops with *"Wireless cannot be configured without making changes
   to the local system!"* and a wired card is not actually connected.

   Pick your network card (Wi-Fi cards are named `iwlwifi0`, `iwm0`, `rtw880`...),
   answer *Yes* to DHCP, and pick your Wi-Fi network if you use one.
4. Start the installer:

   ```sh
   fetch -qo- https://raw.githubusercontent.com/nimonht/FreeBSD-setup/main/bootstrap.sh | sh
   ```

5. Answer the questions: language and keyboard, disk, *install next to the
   existing systems* or *erase the disk*, your name and password, whether to
   encrypt the disk (recommended for laptops), time zone, desktop, terminal
   style and extras, and which system starts first. The last screen shows the
   full plan; nothing is written before you confirm it.

The installation then runs on its own for 30-90 minutes, mostly downloading.
When it says *FreeBSD is installed*, remove the stick and restart.

### 5. First start

- Whole disk: FreeBSD starts directly. If another disk in the computer has
  Windows or Linux and you kept that system as the one that starts first,
  pick *FreeBSD* in the firmware boot menu (F12/F8/Esc).
- Next to other systems: FreeBSD is added to the Limine or systemd-boot menu
  when it finds one (a Limine that protects its menu with a checksum, as
  CachyOS's does, is left alone: the installer shows the one command to run
  in Linux), rEFInd finds it by itself, and it normally appears as *FreeBSD*
  in the firmware boot menu (F12/F8/Esc). If the installer's last screen says
  it could not add a firmware boot entry, FreeBSD starts only from the Limine,
  systemd-boot or rEFInd menu, if you have one; otherwise add an entry for
  `\EFI\freebsd\loader.efi` in the firmware setup's boot options. If you chose
  FreeBSD's menu as the default, press L in that menu to start Windows or
  Limine; with disk encryption the passphrase is asked before that menu
  appears, so use the firmware boot menu to skip it. GRUB users: see
  [docs/DUAL-BOOT.md](docs/DUAL-BOOT.md).

At the login screen pick *Plasma (Wayland)* or *Hyprland (Caelestia)* and log
in (not the plain "Hyprland" entry a package update may add: it lacks the
settings FreeBSD needs). With Hyprland only, the login screen is a simple text
screen: choose the session with the arrow keys, then type your name and
password.

## Already have FreeBSD 15?

Run the same one-liner on an installed FreeBSD. It starts the setup wizard
instead of the installer:

```sh
fetch -qo- https://raw.githubusercontent.com/nimonht/FreeBSD-setup/main/bootstrap.sh | sh
```

It asks for the root password through `doas`, `sudo` or `su`. On a fresh
FreeBSD, `su` only works for members of the `wheel` group; if it answers
*Sorry*, log in as `root` on a text console and run the same command there.
To use git instead, as root: `pkg install git`, then
`git clone https://github.com/nimonht/FreeBSD-setup && sh FreeBSD-setup/setup.sh`.
The first time it runs, it creates a ZFS boot environment `pre-setup-<date>`:
choosing it in the boot menu brings the system (not your home folder) back to
how it was before. Later runs do not make a new one; run `sysup` or
`doas bectl create <name>` first if you want one.

## Everyday use

| Task | How |
|---|---|
| Update packages and the base system safely | `sysup` (creates a boot environment first) |
| Update Caelestia (Hyprland) | `doas freebsd-setup caelestia` (see [below](#the-desktops)) |
| Get the newest FreeBSD-setup fixes | Run the install one-liner again (above): it refreshes the copy in `/usr/local/share/freebsd-setup`, which `freebsd-setup` uses |
| Undo a bad update | Boot menu → 8 *Boot Environments* → pick the previous one; or `doas bectl activate <name>` and restart |
| Get an old version of a file | `snap files <file or folder>` shows where its read-only old copies are (for your home folder: `/home/.zfs/snapshot/<time>/<your name>/...`); `snap` lists the snapshots |
| Install software | `doas pkg install <name>`; search with `pkg search <word>` or browse [FreshPorts](https://www.freshports.org) |
| Run a game on the fast GPU (laptops) | `gpu-run <program>`; Steam does it by itself |
| Steam | Run `steam-setup` once from a terminal, then start Steam from the menu |
| Wi-Fi networks | KDE: the NetworkMgr icon in the panel. Hyprland has no Wi-Fi window yet: see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#hardware) |
| Add to your choices (another desktop, extras...) | `doas freebsd-setup`. It installs what you add but does not remove what you untick: remove programs with `doas pkg delete <name>`, turn the firewall off with `doas sysrc pf_enable=NO` |
| Hardware report | `freebsd-setup --report` |
| Sound output | `pavucontrol`, or `cat /dev/sndstat` and `doas sysctl hw.snd.default_unit=N` |
| Windows/Linux partitions | Dolphin shows them; NTFS, exFAT and ext4 can be opened |
| Firewall: open a port | Add a rule to `/etc/pf.local.conf` (yours, never replaced), then `doas service pf reload` |
| Terminal: turn the ready-made setup off for you | `terminal-style off` (or `terminal-style greeting-off` for just the system summary); `terminal-style on` undoes it |

Snapshots cover your home folder too, so a deleted file keeps using disk space
until its last snapshot expires (up to about two months). See
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#disk-space-and-snapshots).

### The terminal

The installer asks for a terminal style: fish (the default), zsh, bash or
plain. The first three give the terminal (Konsole, foot) colours, completion,
history search on the Up arrow (fish and zsh also suggest as you type), a
prompt that shows the git branch ([starship](https://starship.rs)), the
JetBrainsMono Nerd Font and a system summary (fastfetch) in every new shell,
similar to CachyOS. Short extra commands: `ll`, `la`, `lt` (listings), `z DIR`
(jump to a folder you used before), `update` (`sysup`), `cleanup`, `psmem`.
Standard commands such as `ls`, `cat` and `cd` are left as they are, so guides
and scripts keep working.

Your login shell stays `sh`: the style only applies inside the terminal app,
so a broken shell setup can never stop you from logging in. To change the
style for everyone, set `TERMINAL_STYLE` to `fish`, `zsh`, `bash` or `none`
(plain) in `/usr/local/etc/freebsd-setup.conf` and run
`doas freebsd-setup terminal`. Your own `~/.config/fish/config.fish`,
`~/.zshrc` or `~/.bashrc` always run after ours. With Caelestia, fish uses
Caelestia's own setup.

### The desktops

KDE Plasma is a complete, Windows-like desktop with its own settings app, file
manager (Dolphin), terminal (Konsole) and screenshot tool. Most of it works on
FreeBSD as on Linux. The Wi-Fi and Bluetooth settings do not (they need
Linux-only services; use the NetworkMgr tray icon for networks), and neither
does System Monitor's Applications page. Date & Time and the battery applet's
power-profile switch are served by small services this setup adds; they are
new and have been tested in a virtual machine, not yet on real hardware. If
Date & Time cannot change the time zone, use `doas tzsetup`.

Hyprland + Caelestia is a tiling Wayland desktop with an animated shell. It is
built from source on FreeBSD with small compatibility shims. Its Wi-Fi, VPN,
Bluetooth, GPU-usage and fingerprint panels rely on Linux services and do not
work. The power-profile switch comes from the same new service as in KDE, on
computers whose CPU allows it (elsewhere it is hidden); it has not yet been
tried on real hardware. The bar, launcher,
dashboard, notifications, media controls, lock screen, wallpapers and colour
schemes work. `Super` opens the launcher, `Super+T` a terminal, `Super+Q`
closes a window
([all keys](https://github.com/caelestia-dots/caelestia#default-keybinds)).
Hyprland uses FreeBSD's newest ("latest") package branch for the whole
computer, KDE included, which updates faster and breaks more often. Once a
computer is on "latest" it stays there, even if you remove Hyprland later.

Caelestia is not a FreeBSD package, so `pkg upgrade` and `sysup` do not update
it. The installer builds the newest Caelestia release of that day; to move to
a newer one, run `doas freebsd-setup caelestia` (10 to 30 minutes). `sysup`
tells you when a package update needs this rebuild. Your own settings in
`~/.config/caelestia/` are kept; see
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#hyprland--caelestia) for what
is replaced.

## What exactly gets changed

**Installer, whole disk:** a new GPT table with an EFI partition, a BIOS boot
partition (so the disk boots in UEFI and legacy mode), swap, and a ZFS pool
`zroot` with the standard FreeBSD dataset layout.

**Encryption (optional, both modes):** the ZFS partition is encrypted with
GELI (AES-XTS, 256-bit key); FreeBSD's boot loader asks for the passphrase,
always with the US keyboard layout. Swap gets a new random key at every start.
A backup of the encryption metadata (useless without the passphrase) is kept
in `EFI/freebsd/fbsd-zfs.eli.backup` on the EFI partition.

**Installer, next to other systems:** two new partitions (ZFS and swap) in the
largest free space; `EFI/freebsd/` added to the existing EFI partition; one
entry appended to Limine's `limine.conf` (backup saved next to it; never when
Limine checks that file against an enrolled checksum) or one file added to
systemd-boot's `loader/entries/`; a firmware boot entry *FreeBSD* (added at
the end of the boot order unless you chose FreeBSD to start first). Nothing
else on the disk is modified. Do not install next to another FreeBSD on the
same disk: the new one takes over the shared `EFI/freebsd/` folder, and the
old one no longer starts from any menu.

**Setup:** packages; settings added to `/etc/rc.conf`, `/boot/loader.conf`
and `/etc/sysctl.conf`; `/etc/devfs.rules` and `/etc/pf.conf` replaced at
every run (your previous versions are saved once as `*.before-freebsd-setup`;
put your own firewall rules in `/etc/pf.local.conf`, which is never
replaced); the login screen; who may run admin commands
(`/usr/local/etc/doas.conf` when you have none,
`/usr/local/etc/sudoers.d/00-freebsd-setup`, and polkit rules so that you can
mount drives, shut down, set the time and switch power profiles without a
password); the login screen's PAM file `/usr/local/etc/pam.d/sddm`, while it
is still the package's own (so the wallet opens with your login password);
`/etc/fstab` (`/proc`, `/dev/fd`, and `/dev/shm` for Steam);
`/etc/nsswitch.conf` (network printers); `/etc/ttys` and `/etc/gettytab`
(the ly login screen); your groups (wheel, operator, video, webcamd, games, cups) and the
groups new accounts get (`/etc/adduser.conf`, when you have none); the
package branch; the terminal style (system-wide files in `/usr/local/etc` and
`/usr/local/share`, only where you have none of your own); KDE defaults in
`/usr/local/etc/xdg` (dark Breeze theme, file indexing off) and
`/etc/xdg/arkrc`; Firefox privacy defaults in
`/etc/firefox/policies/policies.json` (no telemetry, studies or sponsored
content); automatic snapshots and a monthly scrub. In your home folder it adds
settings you don't have yet, with two exceptions: `~/.login_conf` is
rewritten with the chosen language at every run, and Caelestia moves your
existing `~/.config/hypr`, `fish`, `foot`, `fastfetch`, `btop`, `micro` and
`Thunar` folders aside (renamed `*.before-caelestia.*`) and keeps those
folders up to date with Caelestia's own files. The full log is
`/var/log/freebsd-setup.log`; your answers are saved in
`/usr/local/etc/freebsd-setup.conf`.

**Removing FreeBSD (dual boot):** delete the `fbsd-zfs` and `fbsd-swap`
partitions (the names end in a number, e.g. `fbsd-zfs1`, when another disk in
the computer already used them) from the other system, remove `EFI/freebsd`
from the EFI partition, the FreeBSD block from `limine.conf` (or
`loader/entries/A-freebsd.conf`), and the firmware entry (`efibootmgr` on
Linux). Details: [docs/DUAL-BOOT.md](docs/DUAL-BOOT.md#removing-freebsd).

## Advanced

```sh
./setup.sh --report              # hardware compatibility report
./setup.sh --list                # the setup stages
doas ./setup.sh drivers desktop  # run only some stages
doas ./setup.sh --yes --config my.conf   # unattended, answers from a file
sh install.sh --dry-run          # in the USB stick's Live System, as root: the installer's questions and plan, no changes
```

The desktop setup's answers and their defaults are documented in
[`lib/defaults.conf`](lib/defaults.conf); the installer's answers (disk,
account, encryption, time zone...) are shown in the unattended examples in
[`tests/`](tests) (`install-*.conf`). Behind a company proxy that intercepts
TLS, export `SSL_CA_CERT_FILE=/path/to/ca.pem` before running the installer;
it is copied into the new system.

Problems? See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md). Which hardware
works, and why: [docs/HARDWARE.md](docs/HARDWARE.md).

## License

BSD 2-Clause, see [LICENSE](LICENSE). Caelestia is © its authors under its own
license and is downloaded from its upstream repositories at install time.
