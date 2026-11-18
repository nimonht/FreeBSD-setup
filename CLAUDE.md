# FreeBSD-setup

A guided installer (`install.sh`) and desktop setup wizard (`setup.sh`) that turn
the **official** FreeBSD 15 install image into a ready-to-use desktop: KDE Plasma
and/or Hyprland with the Caelestia shell. No custom ISO: everything is scripts,
packages and small compatibility shims on top of stock FreeBSD.

The goal is a friendly, preconfigured FreeBSD desktop that works out of the box
the way Ubuntu, Fedora or CachyOS do. What does not work, and why, is in the
README's comparison table and [docs/HARDWARE.md](docs/HARDWARE.md); keep both
true when behaviour changes. Many desktop-side pieces (power profiles, Date &
Time, lock before suspend, the Caelestia lock screen) have run in a VM over
D-Bus and SSH but not yet on a real screen.

## Layout

| Path | What it is |
|---|---|
| `bootstrap.sh` | The one-liner entry: downloads the repo, runs `install.sh` on the live USB or `setup.sh` on an installed system. `FBS_REF=<branch>` picks a branch. |
| `install.sh` | Guided installer (ZFS, whole disk or next to other systems, optional GELI). Ends by running `setup.sh --chroot` inside the new system. |
| `setup.sh` | Runs the stages in `stages/` in order. `setup.sh STAGE...` runs only some. |
| `stages/*.sh` | One concern each (drivers, desktop, kde, hyprland, caelestia, ...). Sourced, not executed. |
| `lib/hw.sh` | Hardware detection (the `HW_*` variables) and the hardware report. |
| `lib/common.sh` | Helpers: `pkg_install`, `pkg_try`, `svc`, `kld_add`, `loader_set`, `sysctl_set`, `say`, `warn`. |
| `lib/wizard.sh`, `lib/ui.sh` | Questions, and how answers resolve into `WANT_KDE`, `DISPLAY_MANAGER`, ... |
| `files/` | Files installed onto the system: helper commands in `files/bin`, rc scripts in `files/rc.d`, configs. |
| `caelestia/` | Builds the Caelestia shell from source for FreeBSD, with shims for Linux-only pieces. |
| `tests/` | Fixture-based tests (run anywhere), a QEMU end-to-end installer test and a development VM. |

## Rules that are easy to break

- **POSIX `sh` only** (FreeBSD `/bin/sh`), tabs for indentation. No bashisms;
  `local` is the one tolerated extension. CI runs ShellCheck with `-s sh`.
- **Two targets.** `FBS_TARGET=live` is a running system; `FBS_TARGET=chroot` is a
  system being installed, where nothing can be started or loaded. Use
  `is_live`/`is_chroot` and the helpers (`svc`, `kld_now`, `sysctl_set`) that
  already respect this. A stage that only works live is a bug: the normal path
  is the installer, which runs every stage in a chroot.
- **Every stage must be safe to run again**, and must end with `true` (the
  stages are sourced under `set -e`).
- **Never overwrite the user's own files.** Files this project writes carry the
  marker `Written by FreeBSD-setup`; only those are replaced or removed.
- **Decide from the hardware at run time, not at install time**, when the
  hardware can change (see `files/bin/gpu-xorg-config`, run at every boot).
- **Linux-only interfaces are bridged with shims, not patched out one caller at
  a time.** Existing examples: `files/bin/brightnessctl`,
  `caelestia/libsensors-shim/`. Prefer one shim at the interface the desktops
  already speak (a D-Bus name, a CLI) so KDE and Caelestia both work unmodified.
- **A control that cannot work must not be shown broken.** Make it work, replace
  it with the FreeBSD-native tool, or hide it.
- **User-facing text is for non-experts**: plain words, say what to do next.
- **Do not claim something works unless it ran.** Say what was tested and where
  (fixture, VM, real hardware). The project's worst bugs so far were code paths
  that had never run on real hardware.

## Testing

```sh
sh tests/run.sh                 # hardware detection against recorded machines
sh tests/config-test.sh         # wizard answers -> stages and login screen
sh tests/gpu-config-test.sh     # X11 graphics config per machine
sh tests/power-profiles-test.sh # power-profiles D-Bus service (needs python3-gobject, dbus)
sh tests/limine-test.sh         # never edit a checksum-protected limine.conf
sh tests/pkg-retry-test.sh      # broken package downloads are retried
sh tests/efiboot-test.sh        # reading efibootmgr -v (FreeBSD 15 and later layouts)
sh tests/timedate-test.sh       # timedate1 D-Bus service for KDE's Date & Time (needs python3-gobject, dbus)
shellcheck -s sh -S warning -e SC1090,SC1091,SC2034,SC2154,SC3043 \
  setup.sh install.sh bootstrap.sh lib/*.sh stages/*.sh files/bin/* \
  caelestia/build.sh files/rc.d/* tests/*.sh tests/vm/*.sh files/shell/fbs-terminal-greeting
shellcheck -s bash -S warning files/shell/bash.bashrc
sh tests/vm/run-iso-test.sh FreeBSD-15.1-RELEASE-amd64-disc1.iso tests/install-erase-kde.conf
```

Everything but the last line runs on Linux, as CI does. The last one installs
FreeBSD in QEMU through the serial console (slow: mostly package downloads); it
proves the installer and stages finish, not that the desktop works: a plain
QEMU guest has no KMS graphics. On an Arch-style host pass
`OVMF_CODE=/usr/share/edk2/x64/OVMF_CODE.4m.fd OVMF_VARS=/usr/share/edk2/x64/OVMF_VARS.4m.fd`.

On FreeBSD only: `sh tests/ui-test.sh` (installer dialogs, real key presses)
and `sh tests/as-user-test.sh USER` (as root, from a terminal).

For work on stages and services, `tests/vm/dev-vm.sh` keeps an installed image
as a read-only base and boots throwaway overlays with SSH on 127.0.0.1:2222
(`base`, `start`, `ssh`, `sync`, `stop`, `reset`; see its header). On real
hardware, `tests/desktop-probe.sh`, run inside a desktop session, records what
the desktop can see (power, sensors, sleep, D-Bus services, logs) with
addresses and serials removed.

New hardware logic gets a fixture: `sh tests/collect-fixture.sh NAME` on the
machine records it into `tests/fixtures/NAME/`.

To try a branch on an installed FreeBSD machine:

```sh
fetch -qo- https://raw.githubusercontent.com/nimonht/FreeBSD-setup/BRANCH/bootstrap.sh | FBS_REF=BRANCH sh -s -- STAGE...
```

## Facts worth knowing before changing things

- The installed copy of this repo lives in `/usr/local/share/freebsd-setup`;
  `freebsd-setup` is a symlink to its `setup.sh`. Saved answers:
  `/usr/local/etc/freebsd-setup.conf`. Log: `/var/log/freebsd-setup.log`.
- **Never change another system's boot files unless it is known to be safe.**
  Limine can enroll a checksum of `limine.conf` into its binary (CachyOS does
  by default); any change then stops Limine from starting. `limine_locked`
  (lib/common.sh) checks this; test with
  `DISK_SETUP=dualboot LIMINE_ENROLL=yes ... tests/install-alongside-limine.conf`.
- KDE Plasma in FreeBSD packages is Wayland-only (6.8 on "latest", 6.7.5 on
  "quarterly", which KDE-only installs use). The SDDM login screen
  still runs on X11.
- Hyprland + Caelestia need the `latest` package branch; KDE alone uses
  `quarterly`. Kernel modules come from the `FreeBSD-ports-kmods` repository
  matching the minor release.
- There is no systemd, logind, NetworkManager, BlueZ, UPower power profiles,
  udev or cgroups. ConsoleKit2, seatd, devd, `libudev-devd` and UPower (battery
  only) exist. Most "missing feature" reports trace back to one of these.
- What the desktops actually call, read from source (Plasma 6.8.3, Quickshell
  0.3.2, Caelestia shell v2.5.0; recheck when these change):
  - Power profiles: PowerDevil and Quickshell read only
    `org.freedesktop.UPower.PowerProfiles` (our `files/power-profiles/`). Do
    not add a D-Bus activation file for it: PowerDevil treats an activatable
    name as supported, and dbus-daemon stalls 25 s when the service exits.
  - Caelestia's network panel runs `nmcli` (`services/Nmcli.qml`) and reads
    `/sys/class/net`; its Bluetooth panel uses BlueZ over D-Bus through
    Quickshell. Its session and launcher actions go to login1 unless the
    command is not one of the names it intercepts, which is why
    `files/caelestia/shell.json` uses full commands. A JSON array in
    `shell.json` replaces the whole default list.
  - KDE: `plasma-nm`, `bluez-qt` and `bluedevil` are not in ports, so Plasma
    has no network or Bluetooth applet (NetworkMgr is the tray tool).
    `networkmanager-shim` is a build-time stub with no daemon. System
    Monitor's Processes page uses sysctl and works; the Applications page
    needs cgroups and cannot. ksystemstats has no lm-sensors plugin, and its
    GPU page only sees NVIDIA cards (`nvidia-smi`). Discover has no AppStream
    catalogue for FreeBSD's package repositories.
- Hibernate (S4) does not exist on FreeBSD amd64 (only S4BIOS, which almost no
  machine has); never offer it. `zzz` is suspend to RAM.
- `dmesg` needs root: `stages/security.sh` sets
  `security.bsd.unprivileged_read_msgbuf=0`. Write `doas dmesg` in user docs.
- The login shell is never changed. fish as login shell breaks `as_user`
  (`su -c` with `PATH=...`); zsh as login shell drops `~/.profile` from
  desktop sessions. Terminal styles run inside the terminal app only.
- Caelestia is built from source; `pkg upgrade` does not update it.
  `doas freebsd-setup caelestia` rebuilds the newest release tag and
  refreshes the dotfiles (upstream `main`). `sysup` says when the packages it
  was built against have changed.
