# Troubleshooting

Two escape hatches work for almost everything below:

- **A text console**: `Ctrl+Alt+F3`. The desktop started by the `ly` login
  manager lives on the second console: `Ctrl+Alt+F2` takes you back.
- **Boot environments**: in the FreeBSD boot menu press `8`, pick
  `pre-setup-…` or the last `pre-upgrade-…`, boot it, then make it permanent
  with `doas bectl activate <name>`.

The setup log is `/var/log/freebsd-setup.log`.

## FreeBSD does not appear in Limine / "file not found"

- Boot it once from the firmware menu (`Esc` at power-on → *FreeBSD*) to
  confirm the install itself is fine.
- In CachyOS check the loader is where the entry points:
  `sudo ls /boot/EFI/freebsd/` must list `loader.efi` and `loader.env`
  (adjust `/boot` to your ESP mount point).
- If `limine.conf` is not on the ESP, replace `boot():` with
  `guid(<ESP PARTUUID>):` — see `limine/freebsd.conf`.
- Indentation in `limine.conf` matters: entry line starts with `/`, options
  are indented.

## The loader starts but cannot find the root filesystem

At the `OK` loader prompt:

```
lszfs zroot/ROOT          # should list "default"
set currdev=zfs:zroot/ROOT/default:
boot
```

If that boots, the `loader.env` on the ESP is missing or names another pool.
Fix from FreeBSD:

```sh
doas mount /boot/efi
echo 'rootdev=zfs:zroot/ROOT/default:' | doas tee /boot/efi/EFI/freebsd/loader.env
```

## Windows or CachyOS no longer boots

The install script only adds files and partitions, so the usual cause is the
firmware boot order. `Esc` at power-on → choose the Limine/CachyOS entry,
then in CachyOS: `efibootmgr` and put Limine first with
`sudo efibootmgr -o <limine>,<others…>`.

## No network on first boot

Ethernet:

```sh
ifconfig                       # is there re0 (or em0/igb0/alc0)?
doas dhclient re0
```

Wi-Fi:

```sh
sysctl net.wlan.devices        # e.g. "iwlwifi0" or "iwm0"; empty = no driver
doas sysrc wlans_iwlwifi0="wlan0" ifconfig_wlan0="WPA SYNCDHCP" create_args_wlan0="country VN"
wpa_passphrase "YourSSID" "YourPassword" | doas tee -a /etc/wpa_supplicant.conf
doas service netif restart
```

Empty `net.wlan.devices`: find the chip with `pciconf -lv | grep -B3 -i network`.

- Intel: `doas kldload if_iwlwifi` (newer chips) or `if_iwm` (7265/8260/8265).
- Realtek RTL8821CE/8822BE/8822CE: `if_rtw88`; RTL8852: `if_rtw89`.
- Qualcomm/Atheros or anything unsupported: use Ethernet, USB tethering from
  a phone (`doas kldload if_urndis; doas dhclient ue0`), or `wifibox`
  (`pkg install wifibox`), which runs the Linux driver in a tiny VM.

## Hyprland does not start

Read the session log from a text console:

```sh
cat $XDG_RUNTIME_DIR/hypr-session.log | tail -50
kldstat | grep -E 'i915|nvidia|drm'      # i915kms must be loaded
ls -l /dev/dri/                          # card0, renderD128
id                                       # you must be in group "video"
service seatd status
```

- **No `/dev/dri/card0`**: `doas kldload i915kms`, then `dmesg | tail -30`.
- **"permission denied" on the seat / DRM device**: `doas pw groupmod video -m $USER`,
  log out and in.
- **Starts, then black screen or immediate crash in hybrid mode**: the NVIDIA
  DRM device is probably being picked as the primary. Force Intel only:

  ```sh
  echo 'export AQ_DRM_DEVICES=/dev/dri/card0' >> ~/.config/hypr-session.env
  ```

  If that does not help, take NVIDIA out of the picture: set
  `GPU_MODE="intel"` in `config.env`, `su -m root -c './setup.sh gpu'`, reboot.
- **Works from the console (`hypr-session`) but not from ly**: check
  `/etc/ttys` has `ttyv1 "/usr/libexec/getty Ly" xterm on secure` and
  `/etc/gettytab` has the `Ly:` entry, then `doas kill -HUP 1`.

## NVIDIA

```sh
kldstat | grep nvidia                    # nvidia.ko, nvidia-modeset.ko, nvidia-drm.ko
pkg info | grep -i nvidia                # everything must be the -580 flavour, same version
nvidia-smi                               # GPU, temperature, memory
nvrun glxinfo -B | grep -i renderer
nvrun vkcube
```

- **`nvidia-smi` says driver/library version mismatch**: a partial upgrade.
  `doas pkg upgrade`, reboot.
- **A `pkg upgrade` wants to replace `nvidia-driver-580` with `nvidia-driver`**:
  refuse. The GTX 1050 is not supported by newer branches. Lock them:
  `doas pkg lock nvidia-driver-580 nvidia-kmod-580`.
- **`nvrun` programs still render on Intel, or fail to start under Wayland**:
  render offload from a Wayland compositor that runs on Intel is the least
  proven part of this setup. Options: run the game inside gamescope
  (`nvrun gamescope -f -- <game>`), or use an X11 session for gaming.
- **Suspend/resume hangs**: resume with the NVIDIA driver loaded is hit and
  miss on FreeBSD. The lid action is left at "do nothing" by default for that
  reason. If `doas zzz` never resumes cleanly, shut down instead, or switch
  to `GPU_MODE="intel"` and test again.

## No sound

```sh
cat /dev/sndstat                         # pcm devices; "default" marks the active one
sysctl hw.snd.default_unit=1             # try another pcm number
pgrep -l pipewire wireplumber            # all three must run: pipewire, wireplumber, pipewire-pulse
start-pipewire
wpctl status
cat $XDG_RUNTIME_DIR/pipewire-session.log
```

Make the working unit permanent in `/etc/sysctl.conf`
(`hw.snd.default_unit=N`). Programs that only speak OSS work without PipeWire.

## Caelestia

- **The build failed during `setup.sh`**: logs are in
  `/var/tmp/caelestia-build/*.log`. The most common cause is an upstream
  change newer than the shims in `caelestia/build.sh`. Pin a known release in
  `config.env` (`CAELESTIA_SHELL_REF="v2.5.0"`) and re-run
  `su -m root -c './setup.sh caelestia'`.
- **Hyprland starts but there is no bar**: run the shell in a terminal
  (`Super+T`) to see why: `caelestia shell` (without `-d`). Missing QML
  module errors mean the build's install step did not complete; "Quickshell
  version" errors mean Caelestia wants a newer Quickshell than the FreeBSD
  package provides — `doas pkg upgrade quickshell`, or pin an older Caelestia
  tag as above.
- **Icons show as empty boxes**: the Material Symbols font is missing.
  `ls /usr/local/share/fonts/material-symbols/` then `fc-cache -f`; re-run the
  caelestia stage to download it again.
- **CPU/memory read 0 in the dashboard**: the Linux `/proc` emulation is not
  mounted. `doas service linux start`; `ls /compat/linux/proc/meminfo`.
- **No CPU temperature**: `doas kldload coretemp`; `sysctl dev.cpu.0.temperature`.
- **I just want plain Hyprland**: move `~/.config/hypr` away and log in
  again; Hyprland writes its default config. Set `INSTALL_CAELESTIA="no"`.

## Steam

- `steam-setup` must run as your user inside the desktop session.
- **Steam window never appears**: `doas service linux start`, check
  `mount | grep compat` shows linprocfs, linsysfs, devfs, fdescfs, tmpfs.
- **"glXChooseVisual failed" / black Steam window**: the Linux NVIDIA
  libraries are missing or mismatched: `pkg info linux-nvidia-libs-580` must
  be the same version as `nvidia-driver-580`.
- **A game does not launch**: try another Proton version in the game's
  properties, then search the title in the
  [linuxulator-steam-utils issues](https://github.com/shkhln/linuxulator-steam-utils/issues).

## Touchpad, keys, screen

- **Touchpad dead**: `dmesg | grep -iE 'iichid|hmt|hms|ig4|psm'` shows which
  driver, if any, attached. For an I2C touchpad, `ig4_load="YES"` and
  `iichid_load="YES"` must be in `/boot/loader.conf` (the `system` stage adds
  them); reboot after changing it. A USB mouse always works meanwhile.
- **Brightness keys do nothing**: `brightnessctl set 50%` from a terminal. If
  that works, bind the keys in `~/.config/caelestia/hypr-user.lua`. If
  `backlight` reports no device, the panel is not controlled through i915;
  try `doas kldload acpi_video` and `sysctl hw.acpi.video.lcd0.brightness`.
- **Wrong clock in Windows after using FreeBSD** (or the reverse): the two
  disagree about the hardware clock. Hardware clock in local time:
  `doas touch /etc/wall_cmos_clock`; in UTC: `doas rm /etc/wall_cmos_clock`.

## Disk space and snapshots

```sh
zfs list -o space                        # where the space went
zfs list -t snapshot -o name,used -s used | tail   # biggest snapshots
doas zfs destroy zroot/home@<snapshot>   # delete one
bectl list                               # old boot environments also hold space
doas bectl destroy -o pre-upgrade-…
```
