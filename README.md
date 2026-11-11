# FreeBSD on the ASUS ROG GL553VD — triple boot with CachyOS and Windows 10

A complete, bare-metal guide plus scripts to install **FreeBSD 15.1** next to
CachyOS and Windows 10 on an ASUS GL553VD (i7-7700HQ, Intel HD 630 + GTX 1050
4 GB, 16 GB RAM), boot it from the **Limine** menu you already have, and turn
it into a daily driver: **ZFS root with snapshots and boot environments**,
**Hyprland + the Caelestia shell** (KDE Plasma optional), audio, gaming.

```
install/zfs-install.sh   installs FreeBSD on ZFS into free disk space (run from the installer USB)
limine/freebsd.conf      the menu entry to add to Limine
setup.sh + config.env    one command that sets the whole desktop up after the first boot
stages/                  what setup.sh does, one file per step
caelestia/               builds the Caelestia shell and CLI on FreeBSD
files/                   helper tools and FreeBSD-specific desktop config
docs/TROUBLESHOOTING.md  fixes, by symptom
```

The short version, once you have read the long one:

1. Back up. Free up 80 GB+ of unallocated disk space.
2. Boot the FreeBSD USB stick → **Live System** → `sh zfs-install.sh`.
3. Boot CachyOS, append `limine/freebsd.conf` to `limine.conf`.
4. Boot FreeBSD, `cd ~/FreeBSD-setup && su -m root -c './setup.sh'`, reboot.

---

## Read this first: what is tested and what is not

I could not run anything on your laptop, so here is exactly where this stands.

| Part | Status |
| --- | --- |
| `zfs-install.sh`: partitioning into free space, pool, datasets, base system, loader on a shared ESP | **Tested** in a FreeBSD 15.1 UEFI virtual machine on a disk that already had an ESP, a "Linux" and a "Windows" partition. Existing partitions and ESP files were verified untouched. |
| Limine → FreeBSD chainload entry | **Tested** in the same VM: Limine 10.8.5 → `FreeBSD` entry → FreeBSD loader → ZFS root → login prompt. |
| `setup.sh` stages `base system zfs gpu audio desktop caelestia gaming finish` | **Tested** in the VM: all complete without errors, packages install from the FreeBSD 15 `latest` repository, snapshots and boot environments work. `apps` and `kde` were not run (package names checked only; Plasma is currently missing from the `latest` branch and `setup.sh` reports that instead of failing). |
| Caelestia shell 2.5.0 + CLI 1.1.3 build on FreeBSD | **Tested**: compiles, installs, `caelestia scheme set` works, and Hyprland accepts the Caelestia Lua config. |
| Intel HD 630 as the display GPU | Untested here, but this is the standard, well-supported path (`drm-kmod`, `i915kms`). |
| GTX 1050 as secondary GPU (`nvrun`), Steam on NVIDIA | **Untested on hardware.** The driver packages exist and install; whether render offload works under Wayland on this exact machine has to be tried. `GPU_MODE="intel"` is the safe fallback. |
| Wi-Fi, touchpad, suspend/resume, keyboard backlight, webcam | **Untested on hardware.** Depends on the exact parts in your unit; see [Hardware notes](#hardware-notes). |
| Hyprland and Caelestia actually drawing on a screen | **Not verified.** The test VM has no GPU, so Hyprland stops at graphics initialisation there. Some panels cannot work on FreeBSD at all; see [What does not work](#what-does-not-work-on-freebsd). |

Caelestia is written for Arch Linux and has no FreeBSD port. This repo builds
it from source with small compatibility shims. Expect rough edges, and expect
an upstream update to occasionally break the build until the shims are
adjusted. Plain Hyprland from FreeBSD packages is the solid base underneath;
if Caelestia fails to build, `setup.sh` says so and leaves you with a working
Hyprland.

---

## Step 0 — Safety net (do not skip)

Triple-booting means editing a partition table that holds two working systems.

1. **Back up** everything you cannot lose from both Windows and CachyOS to an
   external drive.
2. Make a **CachyOS live USB** as well as the FreeBSD one. If the boot menu
   ever breaks, the CachyOS live USB is how you repair Limine.
3. In **Windows**: turn off Fast Startup (Control Panel → Power Options →
   "Choose what the power buttons do" → untick *Turn on fast startup*), and
   if BitLocker/device encryption is on, suspend it or save the recovery key.
   Fast Startup leaves NTFS half-mounted and causes corruption in multi-boot.
4. In the **firmware setup** (tap `F2` at power-on): Secure Boot **disabled**
   (FreeBSD's loader is not signed), boot mode UEFI (no CSM/Legacy).

## Step 1 — Collect facts from CachyOS

Boot CachyOS and save the output of these somewhere you can read later (phone
photo is fine):

```sh
lsblk -o NAME,SIZE,FSTYPE,PARTTYPENAME,PARTUUID,MOUNTPOINTS   # disks and partitions
sudo parted -l | grep -E 'Model|Disk /|Partition Table'      # must say "gpt"
sudo find /boot /efi -maxdepth 3 -name 'limine.conf' 2>/dev/null
efibootmgr                                                   # current boot entries
lspci -nn | grep -Ei 'vga|3d|network|ethernet'               # GPU, Wi-Fi, LAN chips
timedatectl | grep 'RTC in local TZ'                         # yes or no
```

What to note:

- **Which disk** has free room. The GL553VD ships with an M.2 SSD, a 2.5" HDD,
  or both. FreeBSD names them differently from Linux:
  `nvme0n1` → `nda0` (or `nvd0`), `sda` → `ada0`, `sdb` → `ada1`.
- **Where the EFI System Partition is** (FSTYPE `vfat`, type "EFI System") and
  where `limine.conf` is.
- The **Wi-Fi chip**. Intel 7265/8260/8265 are driven by `iwlwifi`/`iwm` and
  work. If yours is Realtek or Qualcomm, plan on Ethernet or a USB adapter for
  the first boot.
- **RTC in local TZ**: the installer asks. `no` = clock is UTC.

## Step 2 — Make free space

FreeBSD needs **unallocated** space (not a formatted partition). 80 GB is a
comfortable minimum for a desktop; 150 GB+ if you want games on it. The
installer script picks the **largest** unallocated region on the disk.

- **Taking it from Windows**: in Windows, *Disk Management* → right-click the
  `C:` (or data) volume → *Shrink Volume*. Leave the freed space as
  "Unallocated".
- **Taking it from CachyOS**: boot the CachyOS live USB and use *KDE Partition
  Manager* or *GParted* to shrink the CachyOS partition (Btrfs/ext4 shrink
  works offline). Do not shrink a mounted root filesystem.
- **A whole spare disk**: delete its partitions so the disk is one unallocated
  region with a GPT table.

Do not create any partition for FreeBSD yourself; the script does it.

## Step 3 — Make the FreeBSD USB stick

On CachyOS (replace `sdX` with the USB stick — check with `lsblk`, this erases it):

```sh
cd ~/Downloads
curl -LO https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/15.1/FreeBSD-15.1-RELEASE-amd64-memstick.img
curl -LO https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/15.1/CHECKSUM.SHA256-FreeBSD-15.1-RELEASE-amd64
sha256sum FreeBSD-15.1-RELEASE-amd64-memstick.img   # compare with the line in the CHECKSUM file
sudo dd if=FreeBSD-15.1-RELEASE-amd64-memstick.img of=/dev/sdX bs=1M conv=sync status=progress
```

Then put this repository where the FreeBSD live system can read it. The
simplest place is your EFI System Partition (it is FAT, FreeBSD reads it):

```sh
git clone https://github.com/nimonht/FreeBSD-setup.git
sudo cp -r FreeBSD-setup /boot/fbsd-setup     # /boot is the ESP on CachyOS; use your ESP mount point
```

## Step 4 — Boot the stick and install

1. Plug in Ethernet if you can (it makes the first boot easier).
2. Power on, tap `Esc` for the ASUS boot menu, choose the USB stick (UEFI).
3. At the FreeBSD installer's first screen choose **Live System** (not
   Install). Log in as `root`, no password.
4. Find your disk and ESP, copy the scripts off the ESP:

   ```sh
   gpart show -p                      # the disk with "- free -" space; the "efi" partition
   mount -t msdosfs /dev/nda0p1 /media     # <- your efi partition
   cp -R /media/fbsd-setup /tmp/
   umount /media
   cd /tmp/fbsd-setup
   ```

5. Run the installer script:

   ```sh
   sh install/zfs-install.sh
   ```

   It asks for the disk, your user name, time zone and whether the hardware
   clock is local time, then prints the current partition table and a plan.
   **Read the plan.** Nothing is written until you type `YES`.

   What it then does:
   - adds a ZFS partition and an 8 GB swap partition inside the largest free
     region (it never deletes, resizes or formats anything that exists);
   - creates the pool `zroot` (lz4 compression, autotrim) with the standard
     FreeBSD dataset layout, including `zroot/ROOT/default` so boot
     environments work;
   - installs the FreeBSD base system, kernel and 32-bit libraries (from the
     stick; downloaded if the stick lacks them);
   - writes `fstab`, `rc.conf`, `loader.conf`, time zone;
   - offers to set up Wi-Fi if it sees a wireless card;
   - asks for the root password and your user's password;
   - copies FreeBSD's `loader.efi` to `EFI/freebsd/` on the ESP (your other
     systems' files are not touched) and adds a firmware boot entry "FreeBSD"
     at the **end** of the boot order, so Limine stays the default;
   - copies this repository to `~/FreeBSD-setup` on the new system;
   - takes a `@fresh-install` snapshot.

   Useful variations:

   ```sh
   SWAP_SIZE=16g ZFS_SIZE=120g sh install/zfs-install.sh   # explicit sizes
   POOL=zfbsd sh install/zfs-install.sh                    # another pool name
   ESP_DEV=nda0p1 DISK=ada0 sh install/zfs-install.sh      # FreeBSD on the HDD, ESP on the SSD
   ```

6. `reboot` and pull the stick out.

## Step 5 — Add FreeBSD to Limine

Boot CachyOS. Back up and edit the Limine config you found in step 1:

```sh
sudo cp /boot/limine.conf /boot/limine.conf.bak
sudo tee -a /boot/limine.conf < ~/FreeBSD-setup/limine/freebsd.conf   # or paste the block by hand
```

The block is:

```
/FreeBSD
    comment: FreeBSD 15 on ZFS
    protocol: efi
    path: boot():/EFI/freebsd/loader.efi
```

Limine chainloads FreeBSD's own loader, which then boots the ZFS pool. If
your `limine.conf` is not on the ESP, use the `guid(...)` form explained in
[`limine/freebsd.conf`](limine/freebsd.conf). CachyOS's Limine tooling
regenerates only its own entries; a block appended at the end stays. If it
ever disappears after a CachyOS kernel update, append it again.

Reboot and pick **FreeBSD**. (Independent of Limine, `Esc` at power-on →
"FreeBSD" also boots it.) You should land at a text `login:` prompt.

## Step 6 — First boot: run the setup script

Log in as your user. Check the network: `ping -c 3 pkg.freebsd.org`.
(No network? See [Wi-Fi](docs/TROUBLESHOOTING.md#no-network-on-first-boot).)

Look through the settings, then run the script:

```sh
cd ~/FreeBSD-setup
ee config.env                    # optional: desktop, GPU mode, login manager, apps...
su -m root -c './setup.sh'       # asks for the root password
```

It takes 30–60 minutes, mostly downloading packages and compiling Caelestia.
It is safe to re-run, and single stages can be repeated
(`su -m root -c './setup.sh gpu caelestia'`, list with `./setup.sh --list`):

| Stage | What it does |
| --- | --- |
| `base` | Creates a `pre-setup-…` boot environment (your undo button), switches packages to the `latest` branch, updates, installs core tools, `doas`/`sudo`, puts you in `wheel`, `operator`, `video`. |
| `system` | Laptop tuning: CPU microcode, temperature sensors, ASUS hotkeys, touchpad drivers, power management, D-Bus, seatd, a `brightnessctl` command. |
| `zfs` | ARC memory cap, monthly scrub, **automatic rolling snapshots**, the `sysup` and `snap` commands. |
| `gpu` | Intel `i915kms` for the display; in `hybrid` mode also the NVIDIA **580 legacy** driver (the last branch that supports the GTX 1050) and `nvrun`. |
| `audio` | PipeWire + WirePlumber on FreeBSD's OSS, PulseAudio compatibility. |
| `desktop` | Hyprland, portals, screenshot/clipboard tools, fonts, themes, the `ly` login screen, the `hypr-session` launcher. |
| `caelestia` | Builds the Caelestia shell and CLI for FreeBSD, installs the Caelestia dotfiles and FreeBSD-specific overrides. |
| `kde` | KDE Plasma 6, only if `DESKTOP` is `kde` or `both`. |
| `gaming` | Linux compatibility layer, Steam, Wine-Proton, gamescope, MangoHud. |
| `apps` | Firefox, media, office, developer tools, NTFS/ext4/exFAT support. |
| `finish` | `@post-setup` snapshot and a summary of anything that needs attention. |

Reboot when it finishes: `shutdown -r now`.

## Step 7 — First login to the desktop

At the login screen choose your user and the session **Hyprland (Caelestia)**.

| Keys | Action |
| --- | --- |
| `Super` (tap) | Launcher |
| `Super + T` / `W` / `E` | Terminal / browser / file manager |
| `Super + Q` | Close window |
| `Super + 1…0` | Workspaces |
| `Super + L` | Lock |
| `Ctrl + Alt + Delete` | Session menu (logout, reboot, power off) |
| `Ctrl + Super + Alt + R` | Restart the shell |

The full list is in the [Caelestia README](https://github.com/caelestia-dots/caelestia#default-keybinds).

First things to do:

```sh
caelestia wallpaper -f ~/Pictures/Wallpapers/some.jpg   # set a wallpaper (colours follow it)
hyprctl monitors                                        # output names for monitor config
glxinfo -B | grep -i renderer                           # should say Intel (Mesa)
nvrun glxinfo -B | grep -i renderer                     # should say GeForce GTX 1050
```

Your own settings go in three files that updates never overwrite:

- `~/.config/caelestia/hypr-vars.lua` — default apps, gaps, keybinds
- `~/.config/caelestia/hypr-user.lua` — any extra Hyprland config (monitors!)
- `~/.config/caelestia/shell.json` — the shell (bar, launcher, idle, session)

Do not edit `~/.config/hypr/`; it belongs to the Caelestia dotfiles.

If the screen stays black or you are thrown back to the login screen, switch
to a text console with `Ctrl+Alt+F3`, log in, and read
`cat $XDG_RUNTIME_DIR/hypr-session.log`. Then see
[TROUBLESHOOTING](docs/TROUBLESHOOTING.md#hyprland-does-not-start).

## Step 8 — Gaming

```sh
steam-setup            # once: downloads the Linux Steam client for your user
~/.local/bin/steam     # start Steam (runs on the GTX 1050 in hybrid mode)
```

- Steam is the **Linux** client running through FreeBSD's Linux binary
  compatibility layer (`games/linux-steam-utils`). Native Linux games and
  many Proton titles run. In Steam enable *Settings → Compatibility → Steam
  Play for all other titles*.
- Windows games outside Steam: `wine-proton` + `winetricks`, or the `mizuma`
  launcher helper.
- `nvrun <program>` runs anything on the NVIDIA GPU; without it programs use
  the Intel GPU. `mangohud <program>` shows an FPS overlay.
- **Will not work**: games with kernel-level anti-cheat (EasyAntiCheat/
  BattlEye in most multiplayer titles, Vanguard), and anything that needs a
  Linux kernel feature the compatibility layer lacks. Keep those on Windows
  or CachyOS. Expect a smaller working library than on CachyOS; check a title
  on the [FreeBSD gaming wiki](https://wiki.freebsd.org/Gaming) or
  [linux-steam-utils issues](https://github.com/shkhln/linuxulator-steam-utils/issues).

## ZFS: snapshots and boot environments

This is the part of FreeBSD you will miss on other systems.

**Automatic snapshots** (set up by the `zfs` stage, via `zfstools`): every 15
minutes (4 kept), hourly (24), daily (7), weekly (4), monthly (6) for the
system and `/home`. Temporary data (`/tmp`, `/var/tmp`, ports, obj) is excluded.

```sh
snap                         # list recent snapshots
snap take before-experiment  # manual, whole pool
snap files ~/Documents       # where old versions of a folder live
ls ~/.zfs/snapshot/          # every snapshot of /home is a read-only folder
cp ~/.zfs/snapshot/zfs-auto-snap_hourly-2026-11-11-09h00/notes.txt ~/   # restore one file
doas zfs rollback zroot/home@zfs-auto-snap_daily-…   # roll all of /home back (drops newer changes)
```

**Boot environments** are bootable snapshots of the operating system itself.
`sysup` makes one before every upgrade:

```sh
sysup                      # new boot environment, then pkg upgrade + freebsd-update
bectl list                 # see them
doas bectl activate pre-upgrade-20261111-0900 && doas shutdown -r now   # go back
```

If an upgrade leaves the system unbootable: in the FreeBSD boot menu (the one
after Limine) press `8` — *Boot Environments* — and pick the previous one.
`pre-setup-…` is the system exactly as it was before `setup.sh` ran.

**Backups.** Snapshots protect against mistakes, not against a dead disk.
Send them to an external drive now and then:

```sh
doas zpool create backup /dev/da0                       # once; erases that USB disk
doas zfs snapshot -r zroot@backup-1
doas zfs send -R zroot/home@backup-1 | doas zfs receive -Fu backup/home
```

## Daily driving

| Task | Command |
| --- | --- |
| Update everything safely | `sysup` |
| Install / search software | `doas pkg install <name>` / `pkg search <word>` |
| Volume / audio devices | `pavucontrol`, `wpctl status` |
| Brightness | keyboard keys, or `brightnessctl set 60%` |
| Suspend | `doas zzz` (test it once before relying on it) |
| Wi-Fi networks | edit `/etc/wpa_supplicant.conf`, `doas service netif restart wlan0` — or `doas pkg install networkmgr` for a tray GUI |
| Mount the Windows partition | `doas ntfs-3g /dev/nda0p3 /mnt` |
| Mount the CachyOS partition | ext4: `doas fuse-ext2 /dev/nda0p5 /mnt` (read-mostly). Btrfs cannot be read from FreeBSD. |
| Switch to Intel-only graphics | set `GPU_MODE="intel"` in `config.env`, `su -m root -c './setup.sh gpu'`, reboot |
| Add KDE Plasma later | set `DESKTOP="both"`, `su -m root -c './setup.sh kde'` |
| Rebuild Caelestia after an upstream update | `su -m root -c './setup.sh caelestia'` |

### What does not work on FreeBSD

Being straight about the gaps compared with CachyOS:

- **Caelestia panels tied to Linux services**: the network/Wi-Fi and VPN
  panels (they talk to NetworkManager), Bluetooth, GPU usage, power profiles,
  fingerprint unlock, and hibernate. The bar, launcher, dashboard, media,
  notifications, lock screen, wallpaper and colour schemes do not depend on
  those. Screen recording via `caelestia record` needs `gpu-screen-recorder`,
  which is not ported; use `wf-recorder`.
- **Bluetooth** audio is awkward on FreeBSD; assume wired or USB audio.
- **Hibernate** (suspend to disk) does not exist. Suspend to RAM may or may
  not resume cleanly with the NVIDIA driver loaded — test it.
- **Battery life** is worse than Linux: the GTX 1050 cannot be powered down
  completely when idle.
- **Anti-cheat games**, some DRM video (Widevine needs the `foreign-cdm`
  workaround), Discord's native client (use the web app).
- **HDMI output**: on most GL553VD units the HDMI port is wired to the NVIDIA
  GPU. Driving an external monitor through it from an Intel-primary Wayland
  session may not work; this needs testing on your unit.

### Hardware notes

| Device | Driver | Notes |
| --- | --- | --- |
| Intel HD 630 | `i915kms` (drm-kmod) | Drives the laptop panel. |
| GTX 1050 | `nvidia-driver-580` + `nvidia-drm-kmod-580` | Pascal cards were dropped after the 580 branch; do not install plain `nvidia-driver`. |
| Ethernet (Realtek) | `re` | If the link is flaky: `doas pkg install realtek-re-kmod` and follow its message. |
| Wi-Fi (Intel) | `iwlwifi` / `iwm` | Other vendors: see troubleshooting. |
| Touchpad (I2C HID) | `ig4` + `iichid` + `hms`/`hmt` | Enabled by the `system` stage. |
| Audio (Realtek HDA) | `snd_hda` | Speakers/headphone switch: `sysctl hw.snd.default_unit`. |
| Webcam | `webcamd` | Enabled by the `apps` stage. |
| Keyboard backlight / Fn keys | `acpi_asus_wmi` | Partial; brightness keys depend on the firmware. |

## Removing FreeBSD

From CachyOS: delete the `/FreeBSD` block from `limine.conf`, remove
`EFI/freebsd` from the ESP, delete the firmware entry
(`sudo efibootmgr -b <number> -B`), then delete the two partitions labelled
`fbsd-zfs` and `fbsd-swap` with your partition tool and grow a neighbour into
the space.

## Test results

Everything was run on FreeBSD 15.1-RELEASE (amd64, UEFI) in an emulated
machine without a GPU, in November 2026.

- **Installer**: target disk prepared with an ESP (containing stand-in
  Windows and Limine files), a "Linux" partition, a "Windows" partition and
  three separate free regions. `zfs-install.sh` placed ZFS + swap in the
  largest region, left the other partitions and the ESP files byte-identical,
  and appended the firmware entry after the existing boot order. It also
  refuses to run when the free space is too small, when the pool name is
  taken, or when it was started a second time.
- **Boot**: that disk, with a real Limine 10.8.5 as `BOOTX64.EFI` and
  `limine/freebsd.conf` appended to `limine.conf`, boots to the FreeBSD login
  prompt on the ZFS root.
- **setup.sh**: stages listed in the table above finish with exit status 0.
  Checked afterwards: `loader.conf`, `rc.conf` (`kld_list` =
  `fusefs i915kms nvidia-modeset nvidia-drm`), sysctls valid, groups, the
  `pre-setup` boot environment, automatic snapshots firing, `snap`,
  `brightnessctl`, the `ly` entry in `/etc/ttys`, seatd running,
  matching `nvidia-driver-580`/`nvidia-kmod-580` versions.
- **Caelestia**: the first build failed on `std::jthread` (experimental in
  FreeBSD's C++ library); fixed with `-fexperimental-library`, the same flag
  the FreeBSD Hyprland port uses. The lm-sensors shim, the static cavacore
  library and M3Shapes build cleanly.
- **Not possible in that VM**: loading `i915kms`/`nvidia` on real hardware,
  rendering, audio output, Wi-Fi, suspend, Steam.

If something on the real laptop behaves differently from this guide, the
first places to look are `/var/log/freebsd-setup.log`,
`$XDG_RUNTIME_DIR/hypr-session.log` and [TROUBLESHOOTING](docs/TROUBLESHOOTING.md).

## Sources

- [FreeBSD 15.1-RELEASE announcement and release notes](https://www.freebsd.org/releases/15.1R/relnotes/)
- [FreeBSD Handbook](https://docs.freebsd.org/en/books/handbook/) — bsdinstall, ZFS, Wayland, Linux binary compatibility
- [Limine CONFIG.md](https://github.com/limine-bootloader/limine/blob/trunk/CONFIG.md) — `efi` chainload protocol and path syntax
- [FreeBSD forums: dual-booting FreeBSD 15.1 on a shared UEFI disk](https://forums.freebsd.org/threads/dual-booting-freebsd-15-1-alongside-gentoo-on-a-shared-uefi-disk.104037/)
- [FreeBSD forums: nvidia 580 drivers and packages](https://forums.freebsd.org/threads/nvidia-580-drivers-and-packages-nvidia-settings-for-580-drivers-not-found.102833/) and the ports `UPDATING` entry on the 580 legacy branch
- [FreshPorts: graphics/nvidia-drm-kmod](https://www.freshports.org/graphics/nvidia-drm-kmod/), [x11-wm/hyprland](https://www.freshports.org/x11-wm/hyprland/), [x11/quickshell](https://www.freshports.org/x11/quickshell/)
- [Caelestia dotfiles](https://github.com/caelestia-dots/caelestia), [shell](https://github.com/caelestia-dots/shell), [CLI](https://github.com/caelestia-dots/cli)
- [linuxulator-steam-utils](https://github.com/shkhln/linuxulator-steam-utils), [pw-oss (PipeWire OSS backend)](https://github.com/shkhln/pw-oss)
