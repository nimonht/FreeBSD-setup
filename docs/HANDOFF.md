# Handoff: from "it boots" to "it is usable"

Written 2026-11-16 by a cloud session that could not run FreeBSD, for a local
Claude Code session on the owner's Arch Linux machine that can. It records what
the owner wants, what real-hardware testing found, what is known about each gap,
and how to set up a development loop. Delete sections as they are completed;
this file is a work brief, not permanent documentation.

**How sure each statement is** is marked: *verified* (seen on the owner's
hardware, or in FreeBSD's package catalogue on 2026-11-15), or *to verify*
(recalled or inferred; check before building on it).

## 0. Progress log

**2026-11-16, local session on the owner's Arch (CachyOS) host:**

- The host **is** the ROG laptop from section 2. The owner's real FreeBSD
  install is on the same disk (`nvme0n1p5` ZFS, `p6` swap): never attach it
  to a VM. Both screen outputs are wired to the Intel GPU and the NVIDIA card
  has none, so NVIDIA passthrough (6.2 option 1) cannot show a picture. IOMMU
  is off. The owner chose **no host changes**: the dev VM uses SSH plus
  software rendering, and hardware checks are done by the owner rebooting into
  FreeBSD and running `tests/desktop-probe.sh` (results land on the shared
  EFI partition, `/boot/fbs-probe/` from Linux). The owner can do hardware
  rounds whenever needed. The USB Bluetooth adapter may be lent to the VM,
  but ask each time.
- Dev VM: `tests/vm/dev-vm.sh` (base image from `run-iso-test.sh`, overlays,
  SSH on 127.0.0.1:2222). Files in `~/VMs/freebsd-setup-dev`.
- Upstream research for 4.1 to 4.5, read from source at pinned versions:
  [notes/upstream-research-2026-11.md](notes/upstream-research-2026-11.md).
  Key outcomes:
  - Power profiles: KDE and Quickshell both read only
    `org.freedesktop.UPower.PowerProfiles`.
  - Caelestia v2.5.0 networking is `nmcli` calls only, so an `nmcli`
    look-alike would cover it.
  - NetworkMgr was silently broken by our own sudoers file (fixed).
  - No bluez-qt or bluedevil in ports, so KDE has no Bluetooth UI at all.
  - Hibernate (S4) is unsupported on FreeBSD.
  - Discover has no AppStream catalogue to browse.
- Done, not yet verified on hardware:
  - `files/power-profiles/` plus `stages/system.sh`: power-profiles D-Bus
    service, tested by `tests/power-profiles-test.sh`.
  - sudoers file order fix in `stages/base.sh`.
- Checked in the dev VM (FreeBSD 15.1-p5, DESKTOP=both, over SSH, no
  desktop session):
  - `setup.sh base system security` runs again cleanly.
  - sudo: `sudo -l -U tester` now lists the NetworkMgr NOPASSWD rule last,
    so it wins. (`visudo -c` still complains that the networkmgr package's
    own file is not mode 440; that file is the package's.)
  - Power profiles on the real system bus with the real polkit, using the
    fake backend: the desktop user (wheel, operator) can read and switch,
    `nobody` is refused for switch and hold, and the legacy name answers.
    The VM CPU has no power setting, so `--check` says `none` and the rc
    script skips quietly.
  - Found and fixed in the VM: the D-Bus activation file made dbus-daemon
    wait 25 s on machines without a CPU setting (and PowerDevil counts an
    activatable name as supported), so it was removed; FreeBSD's rc.d/dbus
    has no `reload`, so the stage now calls `ReloadConfig`; our firewall
    blocked the VM's SSH, which showed that user rules in `/etc/pf.conf`
    were lost on every re-run, so `/etc/pf.local.conf` (created once, never
    replaced) is now included.
  - `tests/desktop-probe.sh` runs to the end as the user and as root, with no
    unredacted MAC addresses, serials or UUIDs in the result.
- Not yet checked: polkit inside a real desktop session (needs the laptop),
  and everything visual.
- Terminal style (owner request: an optional CachyOS-like terminal). Research:
  [notes/terminal-research-2026-11.md](notes/terminal-research-2026-11.md).
  Owner decisions: fish preselected; zsh without oh-my-zsh (the port is a
  stale 2024 snapshot, powerlevel10k is not packaged); fastfetch in every new
  shell, as CachyOS does; JetBrainsMono Nerd Font on KDE too. The login shell
  is never changed (fish as login shell breaks `as_user`; zsh drops
  `~/.profile` from desktop sessions). `stages/terminal.sh`, `files/shell/`,
  `terminal-style` (per-user off switch). Caelestia's own fastfetch box called
  Linux-only commands; `files/caelestia/fastfetch-freebsd.jq` fixes the
  downloaded copy (the dots are GPL-3, so no modified copy is shipped).
  Checked in the dev VM: each style starts with greeting and prompt and no
  errors, scripted shells stay silent, `terminal-style` switches work,
  switching to `none` removes only our files, re-runs are clean, foot accepts
  both foot.ini files, Konsole lists the profile and KConfig resolves it as
  default with Plasma's XDG_CONFIG_DIRS. Not checked: how it looks (font,
  icons, colours) - see tests/desktop-walk.txt.
- Hardware round 1, prepared: `tests/desktop-probe.sh` and
  `tests/desktop-walk.txt` (the systematic walk of 4.6 as a checklist).

- **2026-11-17, Limine lock-out (reported by the owner, fixed):** next to a
  Limine whose binary has an enrolled checksum of `limine.conf` (CachyOS's
  default, `ENABLE_ENROLL_LIMINE_CONFIG=yes`), appending the FreeBSD entry made
  Limine stop with "CHECKSUM MISMATCH FOR CONFIG FILE" (Limine source
  `common/lib/config.c` `init_config`; reproduced in QEMU with Limine 12.10).
  The installer now checks every Limine binary on the EFI partition
  (`limine_locked`) and leaves `limine.conf` alone when one is enrolled or
  when it cannot tell; the end of the install shows the
  `limine-entry-tool --add-efi` command. Recovery for machines already hit:
  docs/TROUBLESHOOTING.md (firmware menu -> FreeBSD -> restore
  `limine.conf.before-freebsd`; checked in QEMU). Tests:
  `tests/limine-test.sh`, and the VM test with `LIMINE_ENROLL=yes`.

- **2026-11-17, out-of-the-box polish (owner asked for all of it):** Baloo
  indexing off (`/usr/local/etc/xdg/baloofilerc`); KDE theme Breeze Dark
  (`/usr/local/etc/xdg/kdeglobals`, read by startplasma's look-and-feel
  defaults); Ark opens the destination folder (`/etc/xdg/arkrc`, because the
  ark package owns `/usr/local/etc/xdg/arkrc`; the About page is branded by
  kinfocenter's own file already); Firefox `policies.json` in
  `/etc/firefox/policies/` (about:policies in the VM lists all of it, no
  errors); `noto-sans-sc` as CJK fallback for everyone (fontconfig matches it
  for ja, ko, zh-tw); printer drivers hplip, brlaser, splix, escpr. Checked in
  the dev VM with kreadconfig6; nothing visual seen yet.

- **2026-11-17, package downloads:** two VM installs lost KDE to one broken
  download ("pkg: An error occurred while fetching package"); the warning
  wrongly blamed package rebuilds. `pkg_get` now retries broken downloads (3
  tries) for every package install, and the KDE warning names the real
  cause. KDE-only VM install afterwards: one retry happened, Plasma, the KDE
  defaults, `noto-sans-sc` and the fish terminal style all installed in the
  chroot.

- **2026-11-18, audit and safety fixes:** a source audit of boot managers,
  firmware, the installer and first use found 66 problems
  ([notes/audit-2026-11-18.md](notes/audit-2026-11-18.md); #0 and #10 turned
  out wrong for FreeBSD 15.1). Fixed (owner's priority "safety first"):
  Caelestia lock screen refusing every password (#51, pamtester in the VM);
  passwords typed in US layout for non-US keyboards (#30); USB/backup disk
  pre-selected and silent erase (#33) and erasing a disk other systems
  depend on (#18, #19, #37); key L only for loaders FreeBSD's chain can start
  (#1, #17, #45); systemd-boot entry becoming default (#3, bootctl);
  BitLocker warning (#2, #16); GRUB steps printed (#5, #44); lock before
  suspend (#52, ConsoleKit part tested in the VM); base download retries.
  The owner's laptop had its old FreeBSD removed (Limine entry via
  limine-remove-entry, partitions wiped); the owner will reinstall once the
  safety fixes are pushed. Then the first-use groups the owner chose:
  first start (#34 Wi-Fi firmware from the install media, #35 setup
  warnings on the last screen, #36 doas early / su advice); Hyprland
  (#53 sleep via doas -n /usr/sbin/zzz, #54 launcher actions, #55 distinct
  session name); KDE (#59 no PulseAudio autospawn, #64 QT_IM_MODULES, #63
  Firefox language, #61 wallet unlocked by SDDM's PAM, #56 timedate1
  service for Date & Time); devices (#60 webcamd always, #65 games group,
  #57 adduser.conf groups, #62 2 monthly snapshots + pkg cache cleaned).
  Most were checked in the dev VM (pamtester, doas -C, about:policies,
  adduser, the timedate1 service on the system bus); none on screen yet.
  Still open: the lower-priority audit findings not listed above.

## 1. What the owner wants

A friendly, preconfigured, modern FreeBSD desktop, comparable in out-of-the-box
experience to Ubuntu, Fedora, CachyOS or NixOS, and explicitly not "old-fashioned
like GhostBSD". Delivered as scripts on top of the official FreeBSD image, never
a custom ISO. The references the owner gave for "what a complete distro
provides":

- <https://wiki.cachyos.org/cachyos_basic/navigation-guide/>
- <https://wiki.archlinux.org/title/Main_page>

The owner named Linux features as examples of the level expected: hardware
detection like CachyOS `chwd`, scheduler tuning (sched-ext, BPF), zram/zswap,
working suspend and hibernate. Treat these as the *standard to meet*, not a list
to port: several have no FreeBSD counterpart (section 5). Where FreeBSD cannot
do something, say so plainly to the owner instead of faking it.

The owner's verdict after 20 minutes on real hardware: **not usable yet**. They
expect more problems than they found.

## 2. The owner's test machine

*Verified* from photos of the console:

- ASUS ROG laptop (hostname `freebsd-rog`; matches fixture
  `tests/fixtures/asus-gl553vd`): Intel Kaby Lake-H HD Graphics 630 drives the
  panel, NVIDIA GeForce GTX 1050 Mobile as second GPU (legacy 580 driver).
- FreeBSD 15.1, installed with `DESKTOP=both` (KDE Plasma + Hyprland/Caelestia),
  SDDM login screen, Wi-Fi configured by the installer and working.
- Loaded: `i915kms`, `nvidia-modeset`, `nvidia-drm`; `/dev/dri/card0`, `card1`.

Already fixed on branch `claude/hopeful-volta-xhvbo7`: SDDM showed a black
screen and KDE froze on this hybrid laptop until X was pinned to the Intel GPU
(`files/bin/gpu-xorg-config`, rerun at every boot). The owner confirmed the
manual version of that fix on the laptop; the scripted version has only run
against fixtures.

## 3. What the owner found broken

All *verified* by the owner on the laptop, in both desktops unless noted.

| # | Symptom | Likely root cause |
|---|---|---|
| 1 | No Wi-Fi control: KDE has no network applet; Caelestia shows an error icon | No NetworkManager on FreeBSD. `networkmgr` is installed by `stages/network.sh` (KDE only) but the owner saw no usable GUI: find out why |
| 2 | No Bluetooth control in KDE or Caelestia | No BlueZ on FreeBSD; KDE's Bluetooth module is not packaged |
| 3 | No power profile switch (balanced / performance / power saver) | No `power-profiles-daemon`; nothing provides its D-Bus service |
| 4 | "Sensors missing" in KDE system apps | KDE's sensor plugins are mostly Linux (`lm-sensors`, sysfs) |
| 5 | System Monitor cannot show applications/processes ("not supported") | The Applications page needs cgroups; whether the Processes page also fails is *to verify* |

Network *connectivity* works; what is missing is any friendly way to change it.

## 4. Analysis and suggested approach per gap

The guiding idea: KDE and Caelestia (through Quickshell) both talk to the same
freedesktop D-Bus services. **Provide those services on FreeBSD once**, and both
desktops work unmodified and keep working across upstream updates. Patching each
desktop separately does not scale.

Package facts below are *verified* against the `latest` catalogue for
FreeBSD 15 amd64 on 2026-11-15. Everything about upstream source code is
*to verify* by reading the version actually packaged.

### 4.1 Power profiles (start here)

Smallest gap with the clearest design, and it fixes both desktops at once.

- Not packaged: `power-profiles-daemon`, `tlp`. Packaged: `upower` 1.91,
  `plasma6-powerdevil` 6.8, `powerdxx`, `acpi_call`.
- Write a small system D-Bus service implementing the power-profiles-daemon
  interface: bus name `net.hadess.PowerProfiles` and the newer
  `org.freedesktop.UPower.PowerProfiles`, with `ActiveProfile` (read/write),
  `Profiles`, `PerformanceDegraded`, `ActiveProfileHolds`, `HoldProfile`,
  `ReleaseProfile`. Take the exact interface from the upstream XML, not from
  this list.
- Back it with what FreeBSD has: Intel HWP energy preference
  (`dev.hwpstate_intel.N.epp`), AMD equivalents, `powerd` flags, and a fallback
  for CPUs with neither. Inspect the real sysctl tree on the laptop first.
- Ship it like the existing helpers: file in `files/`, rc script in
  `files/rc.d`, D-Bus policy file, polkit rule if needed, installed by
  `stages/system.sh`. Persist the chosen profile across reboots.
- *To verify:* that PowerDevil's FreeBSD build looks for this service (and is not
  compiled out), and which Quickshell/Caelestia version reads it.
- Test without any display: `busctl`/`gdbus introspect` and set the property;
  then check the slider appears in KDE's battery applet and Caelestia.

### 4.2 Wi-Fi and network control

The largest gap and the most visible one.

- Packaged: `networkmgr` 6.9 (GhostBSD's GTK tray tool; uses `sudo`),
  `wifimgr`, `wpa_supplicant_gui`, `kf6-networkmanager-qt`,
  `networkmanager-shim` 1.52 ("a shim to bypass Linux dependencies for other
  ports": a build-time stand-in, *to verify* that it runs no daemon).
  Not packaged: `plasma6-plasma-nm`, `iwd`.
- Step 1, cheap: find out why `networkmgr` gave the owner nothing in Plasma
  (autostart? tray icon not shown on Wayland? `sudo` rule? Hyprland never gets
  it because the stage only installs it for KDE). A working tray tool is an
  acceptable interim answer for KDE.
- Step 2, read what Caelestia actually calls for networking in the pinned
  version (`nmcli`, or Quickshell's network module speaking NetworkManager
  D-Bus). If it shells out to `nmcli`, an `nmcli` look-alike on top of
  `wpa_cli`/`ifconfig`/`dhclient` (same pattern as `files/bin/brightnessctl`)
  is days of work, not weeks.
- Step 3, the real fix, to be weighed after steps 1 and 2: a daemon exposing the
  subset of the `org.freedesktop.NetworkManager` D-Bus API that the applets use
  (list devices, scan, list access points, connect with a secret, connection
  state, signal strength), backed by `wpa_supplicant`'s control socket and
  `rc.conf`/`wpa_supplicant.conf`. That would allow building `plasma-nm` too.
  It is a substantial project: do not start it before measuring how much of the
  API the clients need.
- Changes must survive reboot (the installer writes `wlans_*`/`ifconfig_wlan0`
  in `rc.conf` and `/etc/wpa_supplicant.conf`) and must not need the user to
  type a root password for every network switch.

### 4.3 Bluetooth

- FreeBSD has its own stack (`ng_ubt`, `hccontrol`, `hcsecd`, `bthidd`,
  `bluetooth-config`), no BlueZ, so nothing answers `org.bluez` on D-Bus.
  Packaged: `iwmbt-firmware`, `rtlbt-firmware`, `virtual_oss_bluetooth`
  (a Bluetooth audio backend for `virtual_oss`).
- The README and `docs/TROUBLESHOOTING.md` say Bluetooth audio is unsupported.
  `virtual_oss_bluetooth` suggests headphones can work: *to verify* on hardware,
  then correct the docs either way.
- Realistic target: pairing of keyboards, mice and (if it works) headphones
  through one simple tool, and no dead Bluetooth controls in either desktop.
  A full `org.bluez` service is out of proportion; decide between a small
  dedicated GUI and hiding the panels.

### 4.4 Sensors and System Monitor

- Packaged: `plasma6-ksystemstats`, `plasma6-libksysguard`,
  `plasma6-plasma-systemmonitor` (all 6.8.3).
- First reproduce and list exactly which pages and sensors fail. Expected:
  the Applications page (cgroups) cannot work; CPU, memory, disk, network and
  the Processes page should, through the FreeBSD backends. If Processes really
  fails, check `/proc` is mounted and read the backend.
- Temperatures and fans exist as sysctls (`dev.cpu.N.temperature` with
  `coretemp`/`amdtemp`, ACPI thermal zones). `caelestia/libsensors-shim/`
  already maps the lm-sensors API onto them for Caelestia; reuse the idea (or a
  small ksystemstats plugin) for KDE.
- Ship a default System Monitor layout without the pages that cannot work.

### 4.5 Suspend and hibernate

- The laptop reports S3 (*verified* in the fixture). `stages/system.sh` disables
  suspend-on-lid whenever an NVIDIA driver is installed because resume is
  unreliable; test whether that is still true with the 580 driver.
- *To verify:* that Sleep in KDE's menu and in Caelestia actually suspends
  (ConsoleKit2/UPower path) and that the screen locks first.
- Hibernate (suspend to disk) has no working implementation on FreeBSD amd64 as
  far as this session knows: *to verify*, then hide the entry everywhere.
  `files/caelestia/shell.json` currently maps "hibernate" to `doas zzz`, which
  is suspend to RAM under a wrong name.
- Laptops with only "modern standby" (no S3) cannot sleep; the report already
  says so.

### 4.6 Everything the owner has not tested yet

The owner tested for 20 minutes. Before fixing gaps one by one, **do a
systematic walk** in a running desktop and write down every control that is
missing, dead or shows an error:

- KDE: every System Settings page, every default panel applet, KInfoCenter,
  Discover (is there any package backend, or is it empty?), user management,
  firewall, printers, displays, night light, screen lock, notifications,
  screen sharing through the portal, touchpad gestures, media and brightness
  keys, keyboard backlight, removable drives, file associations.
- Caelestia: every panel of the bar and dashboard, launcher, session menu,
  lock screen, screenshots and recording, colour scheme and wallpaper tools.
- Both: first login experience, updates (`sysup` is terminal-only; a distro has
  an update notifier), installing software without a terminal, time zone and
  clock, input methods, HiDPI, external monitor hot-plug, audio device
  switching, webcam and microphone in a browser call.

Turn the result into a prioritised list in this file and agree the order with
the owner. "Usable" is a judgement the owner makes on the laptop, not a test
that passes in a VM.

## 5. The Linux features the owner named, on FreeBSD

Do not copy Linux tuning by name. For each, the honest FreeBSD position:

| Linux | FreeBSD |
|---|---|
| CachyOS `chwd` hardware detection | `lib/hw.sh` plays this role. Extend it with fixtures; `dsbdriverd` (packaged) is prior art for load-drivers-by-PCI-ID |
| sched-ext, scx schedulers, BPF | No equivalent. The scheduler is ULE with `kern.sched.*` sysctls; tracing is DTrace. Desktop responsiveness tuning must come with a measurement or a cited source |
| zram / zswap | No equivalent in the base system as far as this session knows (*to verify*). Memory pressure tools here are the ZFS ARC limit (already set in `stages/zfs.sh`) and swap sizing |
| Suspend, hibernate | Suspend to RAM where the firmware offers S3; no hibernate (see 4.5) |
| Preconfigured drivers | `stages/drivers.sh` plus `fwget`. Hardware FreeBSD has no driver for cannot be fixed by this project; `wifibox` (packaged, runs the Linux Wi-Fi driver in a tiny VM) is the one workaround worth automating for unsupported Wi-Fi cards |

When a comparison comes out as "FreeBSD cannot do this", tell the owner and
update the README's comparison table. An accurate table is part of being
friendly.

## 6. Development environment on the Arch Linux host

The owner's plan: a FreeBSD VM under QEMU/KVM on their Arch system, with GPU
passthrough, so changes can be seen immediately; the owner then confirms on the
real laptop.

### 6.1 Before touching anything on the host

**Ask the owner before any of these**, each of which can leave the host without
a working screen or network: editing the kernel command line or boot loader
configuration, regenerating the initramfs, binding a device to `vfio-pci`,
unbinding a GPU or the Wi-Fi card from its host driver, changing libvirt
networks. Explain what will change and how to undo it.

**Never give the VM a raw host disk or partition.** Use image files only. If the
host is the same laptop, its disk holds the owner's real FreeBSD installation
next to Arch; do not boot or mount that from the VM.

Start by inspecting, read-only: CPU virtualisation and IOMMU support, `lspci
-nnk`, IOMMU groups, which GPU the host's display runs on, which physical video
outputs are wired to which GPU, and whether QEMU/libvirt/OVMF are installed.
It is not known whether the Arch host is the ROG laptop from section 2 or
another machine: ask.

### 6.2 Choosing how the VM gets graphics

A plain QEMU guest has no KMS driver on FreeBSD, so neither Plasma nor Hyprland
starts normally. Options, best first; all *to verify* on the actual host:

1. **Pass through a second GPU** (`vfio-pci`) while the host keeps the other.
   On a hybrid laptop that means passing the NVIDIA card. Known obstacles:
   mobile NVIDIA cards usually need their video BIOS supplied as a ROM file;
   the picture only appears on outputs wired to that card (often HDMI), so an
   external monitor is needed; there is no Looking Glass guest for FreeBSD.
   Confirm FreeBSD's NVIDIA driver accepts the passed-through card.
2. **Intel GVT-g** (a virtual Intel GPU; Kaby Lake is in the supported range)
   if the host kernel still offers it and FreeBSD's `i915kms` works as its
   guest. Experimental on both ends.
3. **No GPU, software rendering.** `virtio-gpu-qemu-kmod` (packaged) gives the
   guest a framebuffer an X server can drive with `xf86-video-scfb`. On top of
   X, run a nested Wayland compositor (`labwc`, `sway` and `cage` are packaged
   and wlroots has an X11 backend), and Hyprland or KWin nested inside that if
   their builds allow. Slow, but enough to see applets, panels and settings
   pages react to the shims.
4. **No display at all.** Most of the work in section 4 is services and D-Bus.
   Develop and test those over SSH with `busctl`/`gdbus`, and only then look at
   them in a desktop.

Do not let option 1 block progress: start with 4 and 3 while passthrough is
being sorted out.

### 6.3 What a VM cannot show

- **Wi-Fi.** The guest has no wireless card. Pass through a USB Wi-Fi adapter
  (`-device usb-host`), or check whether FreeBSD's simulated wireless driver
  `wtap(4)` is enough for scan/connect UI work.
- **Bluetooth.** Same: a USB Bluetooth adapter passed through.
- **Battery, lid, backlight, CPU power states, temperature sensors, suspend.**
  Absent or fake in a guest. Give every shim a backend that can read recorded
  values (the `HW_FIXTURES` pattern in `lib/hw.sh`), record the real values on
  the laptop, and leave the final check to the owner on hardware.

### 6.4 A fast loop

1. Install once into a qcow2 image with the existing harness
   (`tests/vm/run-iso-test.sh`, `BOOT_TEST=no`) or by hand, then keep that image
   as a read-only base and work in overlays (`qemu-img create -b`), so a broken
   experiment costs seconds.
2. Give the guest SSH (user-mode networking with a forwarded port) and a serial
   console.
3. Get the working tree into the guest (shared folder if the guest supports
   one, otherwise `rsync` over SSH) and rerun only the stage being worked on:
   `doas ./setup.sh system`. Stages are idempotent by design.
4. Run the four fast test commands from `CLAUDE.md` before every commit.
5. For the owner's hardware round, push a branch and give them the
   `bootstrap.sh ... FBS_REF=BRANCH` one-liner from `CLAUDE.md` with the stages
   to rerun, plus exactly what to look at and report.

## 7. Suggested order

1. Inspect the host, agree the VM approach with the owner, get a bootable
   FreeBSD guest with SSH (6.1 to 6.4).
2. The systematic walk (4.6), so priorities rest on a full list.
3. Power profiles (4.1): small, proves the "one D-Bus shim, both desktops" idea.
4. Network control (4.2), steps 1 and 2; decide on step 3 with the owner.
5. Sensors and System Monitor (4.4); suspend and the hibernate entry (4.5).
6. Bluetooth (4.3).
7. Updates and software installation without a terminal, first-login
   experience, and whatever the walk turned up.

After each item: tests, a short entry in `docs/TROUBLESHOOTING.md` if users can
hit a failure, README comparison table kept truthful, and a hardware check by
the owner before calling it done.

## 8. State of the repository at handoff

- Branch `claude/hopeful-volta-xhvbo7` holds the hybrid-GPU login-screen fix,
  `gpu-xorg-config` with its boot service and tests, `CLAUDE.md` and this file.
  It was not merged into `main` at the time of writing; check, and merge or
  rebase onto it first.
- Known loose ends from that work: `files/bin/hypr-session` always puts the
  integrated GPU first, which is wrong on a laptop switched to discrete-only
  graphics; after a graphics card swap, the old kernel modules stay in
  `kld_list`; nothing sets `KWIN_DRM_DEVICES` for KDE on hybrid machines (the
  owner's freeze went away with the X pin alone, so it may not be needed).
- `docs/HARDWARE.md` lists only the QEMU test machine under "Machines
  reported". The owner's laptop can be added once the desktop is usable on it.
