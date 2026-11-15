# Troubleshooting

Start here:

- **The log**: `/var/log/freebsd-setup.log` (setup) and
  `/var/log/freebsd-install.log` (installer).
- **The hardware report**: `freebsd-setup --report` says what was detected and
  what is known not to work.
- **A text console** is always available with `Ctrl+Alt+F3` (or F2, F4...).
  The SDDM login screen and desktop come back with `Ctrl+Alt+F9`; with the
  `ly` login screen it is `Ctrl+Alt+F2`.
- **Undo**: in FreeBSD's boot menu press **8** (*Boot Environments*) and pick
  `pre-setup-...` or the newest `pre-upgrade-...`, or run
  `doas bectl activate <name>` and restart. That rolls the whole system back;
  your files in `/home` are not affected.
- **Re-run** a part: `doas freebsd-setup <stage>` (`freebsd-setup --list`).

## Installer

**"No internet"**: run `bsdinstall netconfig` from the Live System shell, or
choose *Connect* in the installer. Wired networks need only DHCP. If the Wi-Fi
card is not listed, use Ethernet, a USB Ethernet adapter, or USB tethering from
a phone (`kldload if_urndis; dhclient ue0` for Android).

**The disk I want is not in the list**: the USB stick and disks that are in use
are hidden. NVMe drives are called `nda0`, SATA drives `ada0`, USB drives `da0`.
If an NVMe drive is missing on a laptop, switch the storage mode from
*Intel RST/RAID* to *AHCI* in the firmware setup (Windows must be prepared for
that change first: search "switch RST to AHCI Windows").

**"Cannot install next to the existing systems"**: the message says why.
Usually there is not enough *unallocated* space (shrink a partition first), the
disk uses MBR instead of GPT, or the USB stick was started in legacy BIOS mode:
start it again and pick the entry marked "UEFI" in the boot menu.

**Download failed / checksum mismatch**: the network dropped. Run the installer
again. When an install stops half-way the installer cleans up after itself:
it unmounts everything, releases the disk, and for side-by-side installs
removes the partitions it had just created, so the free space is whole again.
If a partition was left behind anyway (power cut), delete it with
`gpart delete -i N <disk>` (`gpart show -l <disk>` lists them: `fbsd-zfs`,
`fbsd-swap`).

**Company network with a TLS-inspecting proxy**:
`export SSL_CA_CERT_FILE=/path/to/proxy-ca.pem` before starting the installer.

## Starting the computer

**FreeBSD does not appear in Limine / systemd-boot**: check the EFI partition
from the other system: `EFI/freebsd/loader.efi` must exist, and the entry must
be in the configuration file the boot manager actually reads (Limine:
`limine.conf`; the installer backed up the previous one as
`limine.conf.before-freebsd`). You can always start FreeBSD from the firmware
boot menu (F12/F8/F11/Esc at power-on), entry "FreeBSD".

**Windows or Linux no longer starts by default**: the firmware boot order
changed (some Windows updates do this too). Pick the system once in the firmware
boot menu and fix the order there, or from FreeBSD:
`efibootmgr` lists the entries, `doas efibootmgr -o 0001,0000,...` sets the order.

**"Start ..." (key L) in FreeBSD's menu does nothing**: the loader looks for
the other system's boot file on disks 0-3. At the loader prompt (`3` in the
menu), `lsdev` lists the disks and `chain disk0p1:/EFI/Microsoft/Boot/bootmgfw.efi`
starts it by hand. The path is in `/boot/loader.conf` (`fbs_chain_path`).

**The loader stops at `OK` and cannot find the system**:

```
lszfs zroot/ROOT
set currdev=zfs:zroot/ROOT/default:
boot
```

If that works, `EFI/freebsd/loader.env` on the EFI partition is missing or
names another pool. Fix it from FreeBSD:
`echo 'rootdev=zfs:zroot/ROOT/default:' | doas tee /boot/efi/EFI/freebsd/loader.env`.

**Encrypted disk: the passphrase is not accepted**: the boot loader always
uses the US keyboard layout, whatever layout you chose (on a German keyboard,
`z` and `y` are swapped, for example). There is no way around a forgotten
passphrase: that is the point of encryption. If the passphrase is right but
the partition reports damaged metadata, restore it from the backup on the EFI
partition (from the USB stick's Live System):
`mount -t msdosfs /dev/<efi-partition> /mnt && geli restore /mnt/EFI/freebsd/fbsd-zfs.eli.backup /dev/gpt/fbsd-zfs`.
Change the passphrase from a running system with
`doas geli setkey -n 0 /dev/gpt/fbsd-zfs` (and keep it for the backup with
`doas geli backup /dev/gpt/fbsd-zfs /boot/efi/EFI/freebsd/fbsd-zfs.eli.backup`).

**Clock wrong in Windows after using FreeBSD (or the reverse)**: they disagree
about the hardware clock. Local time (what Windows uses):
`doas touch /etc/wall_cmos_clock`; UTC: `doas rm /etc/wall_cmos_clock`; then
restart.

## The desktop does not start

From a text console:

```sh
freebsd-setup --report          # is the graphics card supported?
kldstat | grep -E 'i915|amdgpu|radeon|nvidia'
ls -l /dev/dri                  # card0, renderD128... must exist
id                              # you must be in the "video" group
cat /var/log/Xorg.0.log | tail  # SDDM's login screen runs on X11
cat $XDG_RUNTIME_DIR/hypr-session.log   # Hyprland
```

- **No `/dev/dri`**: the graphics driver did not load. `dmesg | tail -40` shows
  why. Missing firmware: `doas fwget`. Then `doas freebsd-setup drivers`.
- **In a virtual machine**: expected. KDE Plasma 6.8 and Hyprland need a 3D
  graphics driver that FreeBSD does not have for VirtualBox, VMware or QEMU.
- **NVIDIA desktop, black screen**: check that `nvidia-driver*`,
  `nvidia-kmod*` and `nvidia-drm*` are the same version (`pkg info | grep nvidia`)
  and that `hw.nvidiadrm.modeset="1"` is in `/boot/loader.conf`.
- **Laptop with NVIDIA, black screen**: the desktop must run on the Intel/AMD
  GPU. For Hyprland, force it in `~/.config/hypr-session.env`:
  `export AQ_DRM_DEVICES=/dev/dri/card0`. To leave the NVIDIA card switched off
  entirely, set `GPU_DRIVERS="intel"` (or `amd`) in
  `/usr/local/etc/freebsd-setup.conf` and run `doas freebsd-setup drivers`.
- **Back at the login screen right after logging in**: the session crashed.
  KDE: `cat ~/.local/share/sddm/wayland-session.log`.
  Hyprland: `cat $XDG_RUNTIME_DIR/hypr-session.log`.
- **KDE could not be installed**: the setup says so when the package branch
  is being rebuilt by FreeBSD. Wait a few days and run `doas freebsd-setup kde`.

## Hardware

**Wi-Fi**: `sysctl net.wlan.devices` lists working cards. Empty? The report
says whether the card needs firmware (`doas fwget` installs it) or is not
supported. Unsupported cards (Broadcom, some new chips) can work through
[wifibox](https://github.com/pgj/freebsd-wifibox) (`pkg install wifibox`),
which runs the Linux driver in a tiny virtual machine. Connect with the
NetworkMgr tray icon (KDE) or `doas bsdinstall wlanconfig`.

**Ethernet (Realtek) drops or is missing**: `doas pkg install realtek-re-kmod`
and follow its message.

**No sound**: `cat /dev/sndstat` lists devices; the one marked `default` plays.
Try another: `doas sysctl hw.snd.default_unit=1`, make it permanent in
`/etc/sysctl.conf`. Check PipeWire runs: `pgrep -l pipewire wireplumber`;
start it with `start-pipewire`. Laptops with Intel "Smart Sound"/SOF audio have
no FreeBSD driver: use HDMI, USB or a USB headset.

**Touchpad does not work, or no tap/scroll**: `dmesg | grep -iE 'hmt|hms|psm|iichid'`.
I2C touchpads need `ig4_load="YES"` and `iichid_load="YES"` in
`/boot/loader.conf` (the setup adds them on laptops) and a restart.

**Brightness keys**: try `brightnessctl set 50%`. If `backlight` reports no
device, add `acpi_video_load="YES"` to `/boot/loader.conf` and restart.

**Suspend does not resume**: common with NVIDIA drivers and on laptops without
S3. The setup only makes the lid suspend where S3 exists and no NVIDIA driver is
loaded. Turn it off again: `doas sysctl hw.acpi.lid_switch_state=NONE` (and
remove it from `/etc/sysctl.conf`).

**Bluetooth mouse/keyboard**: `doas bluetooth-config scan` and follow it.
Bluetooth audio is not supported.

**Printer not found**: network printers are found through mDNS, so the router
must allow it and `avahi_daemon` must run (`service avahi-daemon status`). Add
printers at <http://localhost:631> (log in with your user) or in KDE's printer
settings. USB printers: unplug and plug in again after the setup.

**Webcam**: `webcamd` must run (`service webcamd status`) and you must be in
the `webcamd` group (log out and in after the setup).

## Hyprland + Caelestia

- **Updating Caelestia**: it is built from source here, so `pkg upgrade` and
  `sysup` do not update it. Run `doas freebsd-setup caelestia`: it fetches the
  newest release of the shell and CLI, rebuilds them and refreshes the
  dotfiles. Your own settings in `~/.config/caelestia/` (`hypr-user.lua`,
  `hypr-vars.lua`, `shell.json`) are kept; edits made directly inside the
  managed folders (`~/.config/hypr`, `fish`, `foot`...) are overwritten.
  Run it again after a big `pkg upgrade` too (a new Qt or Quickshell needs a
  rebuild).
- **The Caelestia build failed**: logs are in `/var/tmp/caelestia-build/*.log`.
  A new Caelestia release may need a newer Quickshell than FreeBSD has yet:
  pin the last release that worked in `/usr/local/etc/freebsd-setup.conf`
  (`CAELESTIA_SHELL_REF="v2.5.0"`) and run `doas freebsd-setup caelestia`.
- **No bar after login**: run `caelestia shell` in a terminal (`Super+T`) to
  see the error.
- **Icons are boxes**: the Material Symbols font is missing:
  `ls /usr/local/share/fonts/material-symbols/`, then `doas freebsd-setup caelestia`.
- **CPU/memory show 0**: `doas service linux start` (Caelestia reads Linux-style
  `/proc` files from `/compat/linux/proc`).
- **Network/Bluetooth panels empty**: expected; they need Linux services.

## Steam and games

- Run `steam-setup` as your user from a terminal inside the desktop, once.
- **Steam does not start**: `doas service linux start`; check
  `mount | grep compat` lists linprocfs, linsysfs, devfs, fdescfs and tmpfs.
- **NVIDIA: "glXChooseVisual failed" or black window**: `linux-nvidia-libs*`
  must be the same version as `nvidia-driver*`.
- **A game does not start**: try another Proton version in its properties; search
  the game in the [linuxulator-steam-utils issues](https://github.com/shkhln/linuxulator-steam-utils/issues).
  Games with kernel anti-cheat do not run.

## Disk space and snapshots

```sh
zfs list -o space                      # where the space went
zfs list -t snapshot -o name,used -s used | tail
doas zfs destroy zroot/home@<snapshot> # remove one snapshot
bectl list                             # old boot environments hold space too
doas bectl destroy -o pre-upgrade-...
```

## Reporting a problem

Open an issue with: what you did, what happened, `freebsd-setup --report`,
and the end of `/var/log/freebsd-setup.log`.
