# What makes a desktop distribution, and where LunaBSD stands

Ubuntu, Linux Mint, Fedora and CachyOS are popular for much the same reasons.
This page lists those reasons, how LunaBSD does each one on FreeBSD, and
what is still missing. It is the project's roadmap.

| What people like | Who does it well | LunaBSD now | Still to do |
|---|---|---|---|
| **Try before installing**: the USB stick starts a full desktop | Ubuntu, Mint, Fedora, CachyOS | Live KDE Plasma from RAM; *Welcome* window with *Try* / *Install* (`iso/`) | Not yet tried on real hardware |
| **It always starts**: a fallback when the graphics driver fails | Ubuntu ("safe graphics"), Fedora ("basic graphics") | No driver or a VM: the installer on the firmware framebuffer, with the reason; boot menu *Troubleshooting* (basic graphics, text installer) | |
| **A graphical installer that cannot surprise you** | CachyOS/Calamares, Ubuntu, Windows Setup | Step list, hardware check first, *next to Windows* with a size slider, encryption, summary, explicit tick before erasing; the tested `install.sh` underneath (`installer/`) | Translations of the installer's own text |
| **"What works on my computer?"** before installing | (rare: most distros assume Linux works) | Hardware report on the installer's third page, the same as `freebsd-setup --report` | Report a working/failing machine from the live system in one click |
| **Drivers without thinking** | Ubuntu (*Additional Drivers*), Mint (*Driver Manager*), CachyOS (`chwd`) | Decided from PCI IDs at every live start and in `stages/drivers.sh`; NVIDIA branch per GPU; firmware via `fwget`; `gpu-xorg-config` at every boot | A *Driver Manager* window for switching the NVIDIA branch by hand |
| **Safe updates and undo** | Fedora Silverblue, openSUSE (snapper), CachyOS (Btrfs + Limine snapshots) | ZFS boot environments before each `sysup`, automatic snapshots, `snap files` | An *Update Manager* window (Mint) instead of the terminal command |
| **A welcome app after the first login** | Mint (*Welcome*), CachyOS (*Hello*), Ubuntu | Live session only | First-login *Welcome*: tour, drivers, updates, help links |
| **Software centre** | All of them | KDE Discover has no catalogue for FreeBSD packages; `pkg` in the terminal | OctoPkg is in ports; or an AppStream catalogue for FreeBSD's packages |
| **Wi-Fi and Bluetooth in the panel** | All of them (NetworkManager, BlueZ) | Installer: own Wi-Fi page; desktop: NetworkMgr tray icon | A `nmcli`/NetworkManager D-Bus shim on top of `wpa_supplicant`, so Plasma's and Caelestia's own panels work (see CLAUDE.md: shims, not patches) |
| **A recognisable look** | All of them | Name and sunrise in the boot menu, wallpaper, login screen, *About this System*, `os-release` | Plymouth-style boot splash (`boot_mute` + `splash` in loader.conf hides errors, so not yet); SDDM theme |
| **Its own name** | All of them | LunaBSD. The FreeBSD Foundation's trademark policy does not allow a derived system to call itself FreeBSD | |
| **Regular releases, built by machines** | Ubuntu (6-monthly), Fedora, CachyOS (monthly ISOs) | `iso/build.sh`; GitHub Actions builds and boot-tests the ISO, a tag publishes it | A release every FreeBSD minor release (June, December) plus monthly ISO refreshes |
| **Own package repository** for what upstream lacks | CachyOS (optimised packages), Mint (its tools) | None: Caelestia is built from source on each machine | A `pkg` repository (poudriere in CI) for Caelestia, the shims and LunaBSD's own tools, so `pkg upgrade` updates them |
| **Install without internet** | Ubuntu, Mint, Fedora (offline ISO) | Online install: always the newest packages, small ISO | Optional offline install: copy the live system (`zfs send`) and adjust it |

## Principles (from what went wrong elsewhere)

- **Stock FreeBSD underneath.** No kernel or base-system patches: FreeBSD's
  security advisories and `freebsd-update` apply unchanged.
- **One installer backend.** The text installer and the graphical one run the
  same `install.sh`; the graphical one only asks and shows progress. The
  backend has years of fixes (dual boot, Limine checksums, BitLocker, GELI)
  that a second implementation would have to relearn.
- **Hardware is decided at run time**, never baked into an image: the same
  stick and the same installed disk must work when moved to another machine.
- **Say what does not work.** The README's comparison table and the
  installer's hardware page are part of the product, not fine print.
