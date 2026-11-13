# FreeBSD-setup

**Install FreeBSD as a ready-to-use desktop: one command, a few questions, done.**

FreeBSD-setup is a guided installer plus setup wizard for FreeBSD 15. It checks
your computer, tells you honestly what will and won't work, installs FreeBSD on
ZFS (whole disk, or next to Windows/Linux), and sets up a complete desktop with
the right drivers for your hardware:

- **KDE Plasma** (recommended, familiar if you come from Windows) or **Hyprland
  with the Caelestia shell** (modern tiling desktop, for the adventurous), or both
- **Drivers picked automatically**: Intel, AMD and NVIDIA graphics (each NVIDIA
  card gets the driver branch NVIDIA lists for it), firmware for GPUs and Wi-Fi,
  CPU microcode, laptop touchpads, hotkeys and power saving
- **ZFS with automatic snapshots and boot environments**: every file has hourly
  and daily versions to go back to, and every update can be undone with one
  reboot
- Sound (PipeWire), printers and scanners, USB drives and phones, input
  methods for Vietnamese, Chinese, Japanese and Korean, a firewall
- Optional: everyday apps (Firefox, LibreOffice, VLC, GIMP), gaming (Steam,
  Wine/Proton), developer tools

## Is FreeBSD right for you?

Read this before you install. FreeBSD is a solid, coherent operating system,
but it is **not a drop-in replacement for Linux, Windows or macOS** on a desktop
or laptop. Hardware support and software availability are narrower, and no setup
script can change that.

| | Linux (e.g. CachyOS) | Windows / macOS | FreeBSD with this setup |
|---|---|---|---|
| KDE Plasma / Hyprland desktop | Yes | – | **Yes**, needs a real GPU (below) |
| Intel / AMD graphics | Yes | Yes | **Yes** (Intel Lunar Lake/Battlemage: not yet) |
| NVIDIA graphics | Yes | Yes | **Yes** for GTX 750 / 900 series and newer; older cards: no Wayland desktop |
| Laptop hybrid graphics | Yes, GPU powers off | Yes | **Partly**: games on the fast GPU with `gpu-run`; it cannot power off, so battery life suffers |
| Wi-Fi | Yes | Yes | **Mostly**: Intel and Realtek work, newer MediaTek/Qualcomm chips are recent additions, Broadcom does not work. Often slower than on Linux |
| Bluetooth | Yes | Yes | **Barely**: keyboards/mice paired by hand; no Bluetooth headphones |
| Sleep (suspend) | Yes | Yes | **Sometimes**: works on many Intel laptops (S3); not on "modern standby" laptops; no hibernate |
| Sound | Yes | Yes | **Yes**, except laptops with Intel "Smart Sound"/SOF audio |
| Webcam, printers, scanners, USB drives | Yes | Yes | **Yes** (most webcams; driverless network printers) |
| Fingerprint / face login | Mostly | Yes | **No** |
| Running in VirtualBox / VMware | Yes | Yes | **Console only**: these desktops need a 3D graphics driver that VMs don't have on FreeBSD |
| Browsers | Chrome, Firefox | All | Firefox, Chromium (no official Chrome) |
| Office | LibreOffice, OnlyOffice | MS Office | LibreOffice |
| Netflix/Spotify/Discord/Zoom/Teams apps | Yes (Flatpak) | Yes | **Web versions only**; no Flatpak/Snap/AppImage |
| Steam games | Yes (Proton) | Yes | **Some**: the Linux Steam client through a compatibility layer; many games run, anti-cheat games don't, things break more often |
| Snapshots and undo | Yes (Btrfs) | System Restore / Time Machine | **Excellent**: ZFS snapshots and boot environments |
| Disk encryption | Yes | BitLocker / FileVault | **Yes, optional**: FreeBSD's whole partition (GELI, AES-256); the passphrase is typed at every start |

**Good fit:** you like FreeBSD's design and ZFS, your hardware is in the
supported range, and you mostly use open-source software and web apps.
**Poor fit:** you need specific commercial apps, competitive online games,
long battery life on a gaming laptop, or Bluetooth audio. Dual-boot keeps your
other system for those.

## What you need

- A 64-bit PC (amd64) with **8 GB RAM** (4 GB minimum) and **40 GB** of free disk
  space (30 GB minimum)
- A **real graphics card** for the desktop: Intel HD/UHD/Iris/Arc integrated
  graphics, an AMD Radeon, or an NVIDIA GeForce GTX 750 or newer
- UEFI firmware to install next to Windows/Linux (legacy BIOS: whole disk only)
- **Secure Boot switched off** in the firmware setup (FreeBSD's boot loader is
  not signed by Microsoft)
- An internet connection during installation (Ethernet is easiest; Wi-Fi works
  with supported cards)
- A USB stick of 2 GB or more

Not sure? The installer's first screen is a hardware report, and nothing is
written before the very last confirmation, so you can safely look and quit.

## Install

### 1. Back up

Back up everything you cannot lose. If you keep Windows: switch off **Fast
Startup** (Control Panel → Power Options → "Choose what the power buttons do")
and suspend **BitLocker**/device encryption, or at least save its recovery key.

### 2. Make room (only when keeping another system)

FreeBSD needs **unallocated** space on the disk; the installer creates its
partitions there and never touches existing ones.

- From Windows: *Disk Management* → right-click your largest partition →
  *Shrink Volume*. Leave the freed space "Unallocated".
- From Linux: boot a live USB and shrink a partition with GParted or KDE
  Partition Manager.

### 3. Write the USB stick

Download **`FreeBSD-15.1-RELEASE-amd64-memstick.img`** from
[download.freebsd.org](https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/15.1/)
and write it to the stick (this erases the stick):

- Windows: [Rufus](https://rufus.ie) (choose *DD image* mode) or [balenaEtcher](https://etcher.balena.io)
- macOS / Linux: balenaEtcher, or `sudo dd if=FreeBSD-15.1-RELEASE-amd64-memstick.img of=/dev/<stick> bs=1M status=progress`

### 4. Boot it and run the installer

1. Restart with the stick plugged in and open the boot menu (usually **F12**,
   **F8**, **F11** or **Esc** right after power-on; on Macs hold **Option**).
   Pick the USB stick (UEFI).
2. At the blue *Welcome* screen choose **Live System**, then log in as `root`
   (no password).
3. Connect to the internet:

   ```sh
   bsdinstall netconfig
   ```

   Pick your network card (Wi-Fi cards are named `iwlwifi0`, `iwm0`, `rtw880`...),
   answer *Yes* to DHCP, and pick your Wi-Fi network if you use one.
4. Start the installer:

   ```sh
   fetch -qo- https://raw.githubusercontent.com/nimonht/FreeBSD-setup/main/bootstrap.sh | sh
   ```

5. Answer the questions: disk, *install next to the existing systems* or
   *erase the disk*, your name and password, whether to encrypt the disk
   (recommended for laptops), language, keyboard, time zone, desktop and
   extras. The last screen shows the full plan; nothing is written
   before you confirm it.

The installation then runs on its own for 30-90 minutes, mostly downloading.
When it says *FreeBSD is installed*, remove the stick and restart.

### 5. First start

- **Whole disk:** FreeBSD starts directly.
- **Next to other systems:** FreeBSD is added to the **Limine** or
  **systemd-boot** menu when it finds one, **rEFInd** finds it by itself, and
  it always appears as *FreeBSD* in the firmware boot menu (F12/F8/Esc). If
  you chose "FreeBSD's menu" as the default, press **L** in that menu to start
  Windows (or whatever started the computer before). GRUB users: see
  [docs/DUAL-BOOT.md](docs/DUAL-BOOT.md).

At the login screen pick **Plasma (Wayland)** or **Hyprland** and log in.

## Already have FreeBSD 15?

Run the same one-liner on an installed FreeBSD. It starts the setup wizard
instead of the installer:

```sh
fetch -qo- https://raw.githubusercontent.com/nimonht/FreeBSD-setup/main/bootstrap.sh | sh
```

It asks for the root password through `doas`, `sudo` or `su`. On a fresh
FreeBSD, `su` only works for members of the `wheel` group; if it answers
*Sorry*, log in as `root` on a text console and run the same command there.
Or clone and run it: `git clone https://github.com/nimonht/FreeBSD-setup && doas FreeBSD-setup/setup.sh`.
Before changing anything it creates a ZFS boot environment `pre-setup-<date>`:
choosing it in the boot menu undoes everything the setup did.

## Everyday use

| Task | How |
|---|---|
| Update everything safely | `sysup` (creates a boot environment first) |
| Undo a bad update | Boot menu → **8** *Boot Environments* → pick the previous one; or `doas bectl activate <name>` and restart |
| Get an old version of a file | Every folder has `.zfs/snapshot/<time>/` with read-only copies; `snap` lists them |
| Install software | `doas pkg install <name>`; search with `pkg search <word>` or browse [FreshPorts](https://www.freshports.org) |
| Run a game on the fast GPU (laptops) | `gpu-run <program>`; Steam does it by itself |
| Steam | Run `steam-setup` once from a terminal, then start Steam from the menu |
| Wi-Fi networks | KDE: the network icon (NetworkMgr). Otherwise `doas bsdinstall wlanconfig` |
| Change your choices (desktop, extras...) | `doas freebsd-setup` |
| Hardware report | `freebsd-setup --report` |
| Sound output | `pavucontrol`, or `cat /dev/sndstat` and `sysctl hw.snd.default_unit=N` |
| Windows/Linux partitions | Dolphin shows them; NTFS, exFAT and ext4 can be opened |

### The desktops

**KDE Plasma** is a complete, Windows-like desktop with its own settings app,
file manager (Dolphin), terminal (Konsole) and screenshot tool. Most of it works
on FreeBSD as on Linux; settings pages that depend on Linux-only services
(NetworkManager, Bluetooth) don't. Use the NetworkMgr tray icon for networks.

**Hyprland + Caelestia** is a tiling Wayland desktop with an animated shell. It
is built from source on FreeBSD with small compatibility shims. Its Wi-Fi, VPN,
Bluetooth, GPU-usage, power-profile and fingerprint panels rely on Linux
services and do not work; the bar, launcher, dashboard, notifications, media
controls, lock screen, wallpapers and colour schemes do. `Super` opens the
launcher, `Super+T` a terminal, `Super+Q` closes a window
([all keys](https://github.com/caelestia-dots/caelestia#default-keybinds)). It
uses FreeBSD's newest ("latest") package branch, which updates faster and breaks
more often.

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
entry appended to Limine's `limine.conf` (backup saved next to it) or one file
added to systemd-boot's `loader/entries/`; a firmware boot entry *FreeBSD*.
Nothing else on the disk is modified.

**Setup:** packages, `/etc/rc.conf`, `/boot/loader.conf`, `/etc/sysctl.conf`,
`/etc/devfs.rules`, `/etc/pf.conf` (backup kept), login screen, and per-user
settings that you don't have yet (existing ones are never overwritten). The full
log is `/var/log/freebsd-setup.log`; your answers are saved in
`/usr/local/etc/freebsd-setup.conf`.

**Removing FreeBSD (dual boot):** delete the `fbsd-zfs` and `fbsd-swap`
partitions from the other system, remove `EFI/freebsd` from the EFI partition,
the FreeBSD block from `limine.conf` (or `loader/entries/freebsd.conf`), and the
firmware entry (`efibootmgr` on Linux).

## Advanced

```sh
./setup.sh --report              # hardware compatibility report
./setup.sh --list                # the setup stages
doas ./setup.sh drivers desktop  # run only some stages
doas ./setup.sh --yes --config my.conf   # unattended, answers from a file
./install.sh --dry-run           # the installer's questions and plan, no changes
```

All answers and their defaults are documented in
[`lib/defaults.conf`](lib/defaults.conf); unattended installer examples are in
[`tests/`](tests). Behind a company proxy that intercepts TLS, export
`SSL_CA_CERT_FILE=/path/to/ca.pem` before running the installer; it is
copied into the new system.

Problems? See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## License

BSD 2-Clause, see [LICENSE](LICENSE). Caelestia is © its authors under its own
license and is downloaded from its upstream repositories at install time.
