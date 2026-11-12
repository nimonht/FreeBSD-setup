# ASUS ROG GL553VD

i7-7700HQ, Intel HD 630 + NVIDIA GTX 1050 Mobile (4 GB), 16 GB RAM. The
machine this project was first written for, triple-booting CachyOS (Limine),
Windows 10 and FreeBSD.

What FreeBSD-setup does on it (from the recorded profile in
`tests/fixtures/asus-gl553vd`):

| Part | Result |
|---|---|
| Intel HD 630 | `i915kms`, drives the screen, KDE Plasma/Hyprland run on it |
| GTX 1050 Mobile (10de:1c8d) | `nvidia-driver-580` + `nvidia-drm-kmod-580` (Pascal: 580 is the last branch); used for games with `gpu-run`, Steam does it automatically |
| CPU | Intel microcode, `coretemp` |
| ASUS hotkeys | `acpi_asus_wmi` |
| Touchpad | I2C HID (`ig4` + `iichid`) |
| Ethernet (RTL8111) | `re` |
| Wi-Fi (Intel 8265, `iwm`) | works; Wi-Fi firmware installed by `fwget` |
| Bluetooth | keyboards/mice only |
| Lid | does not suspend while the NVIDIA driver is loaded (resume unreliable) |

## Triple boot with CachyOS and Windows

1. Shrink a partition in Windows or CachyOS to leave 80 GB+ unallocated.
2. Boot the FreeBSD memstick (Esc for the ASUS boot menu, pick the UEFI entry),
   Live System, `bsdinstall netconfig`, then the one-line installer.
3. Choose *Install next to the existing systems*. The installer finds Limine's
   `limine.conf` on the shared EFI partition and adds FreeBSD to it, and
   detects Windows for the clock question (answer *Yes*: Windows keeps the
   clock in local time).
4. Back in CachyOS, hand the entry to CachyOS's own tool once so its updates
   manage it too:
   `sudo limine-entry-tool --add-efi "FreeBSD" "/boot/EFI/freebsd/loader.efi" --comment "FreeBSD" --overwrite`.

For the Hyprland + Caelestia look you use on CachyOS, pick *Hyprland +
Caelestia* (or *Both*) in the desktop question.

## Battery and heat

The GTX 1050 stays powered while its driver is loaded. For long battery life,
set `GPU_DRIVERS="intel"` in `/usr/local/etc/freebsd-setup.conf`, run
`doas freebsd-setup drivers` and restart: the NVIDIA card is then left without
a driver and powered down as far as FreeBSD can.
