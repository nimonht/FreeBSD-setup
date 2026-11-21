# Hardware

FreeBSD-setup detects the hardware at install time and picks drivers itself.
This page explains the rules it follows, so you can judge a machine before
buying or installing, and lists machines people have tried.

Run the check yourself on an installed FreeBSD 15:

```sh
fetch -qo- https://raw.githubusercontent.com/nimonht/LunaBSD/main/bootstrap.sh | sh -s -- --report
# or, when FreeBSD-setup is already installed:
freebsd-setup --report
```

From the Live System of the install USB stick, run the same line with
`--dry-run` instead of `--report`. The installer's first screen is the
hardware report. You can quit there, or go through the questions: nothing is
written to disk.

## Graphics: what decides whether the desktop runs

KDE Plasma 6 (6.8 on the "latest" package branch, 6.7 on "quarterly") and Hyprland are
Wayland desktops: they need a graphics driver with kernel mode setting (KMS).

| GPU | Driver chosen | Desktop |
|---|---|---|
| Intel HD/UHD/Iris/Iris Xe/Arc integrated (Sandy Bridge 2011 → Meteor Lake, Arrow Lake) | `i915kms` (drm-kmod) | Yes |
| Intel Arc (DG2) desktop cards | `i915kms` | Experimental |
| Intel Lunar Lake, Battlemage, Panther Lake | `i915kms` is installed but does not drive them; they need the `xe` driver, which FreeBSD does not have yet | No |
| AMD Radeon GCN 1.2 and newer (R9 285/Fury, RX 400 to 7000, Vega, Ryzen APUs) | `amdgpu` | Yes |
| AMD Radeon RX 9000 (RDNA 4) | `amdgpu` (installed, with a warning) | Probably not yet: newer than FreeBSD's driver. The desktop is still set up, so you can try it |
| AMD Radeon HD 2000 to R9 290 (TeraScale, GCN 1.0/1.1) | `radeonkms` | Yes, slower |
| NVIDIA GeForce 16/20/30/40/50 series (Turing and newer) | `nvidia-driver` (current) | Yes |
| NVIDIA GeForce GTX 750/900/10 series, Titan V (Maxwell, Pascal, Volta) | `nvidia-driver-580` (legacy, last for these GPUs) | Yes |
| NVIDIA Kepler (GTX 600/700) and older | `nvidia-driver-470/390/340/304`; cards older than that get no driver | No, when this card drives the screen (X11-only drivers). On a laptop whose Intel/AMD GPU drives the screen, the desktop runs there and the NVIDIA card stays unused |
| VirtualBox, VMware, QEMU/KVM, Hyper-V, bhyve | none | No: console only |

The NVIDIA branch comes from NVIDIA's own list of device IDs
([lib/nvidia-branches.txt](../lib/nvidia-branches.txt), generated from the
driver's README), so every card gets exactly the driver NVIDIA supports it with.

Laptops with two GPUs (Intel/AMD + NVIDIA/AMD): the desktop runs on the
integrated GPU, which drives the screen; `gpu-run <program>` runs a program on
the other one. On FreeBSD the extra GPU cannot be powered down completely, so
expect shorter battery life than on Windows or Linux. To leave the NVIDIA card
without a driver, set `GPU_DRIVERS="intel"` (or `amd`) in
`/usr/local/etc/freebsd-setup.conf` before installing (in the installer's
answers file) or before running the setup. If the NVIDIA driver is already
installed, also run `doas sysrc kld_list-="nvidia-modeset nvidia-drm"` and
restart. FreeBSD then powers the card down as far as it can; how much battery
that saves has not been measured.

## Other parts

| Part | Works | Doesn't |
|---|---|---|
| Wi-Fi | Intel (`iwlwifi`, `iwm`), Realtek RTW88/RTW89, many USB adapters; newer MediaTek and Qualcomm chips in FreeBSD 15 | Broadcom (use [wifibox](https://github.com/pgj/freebsd-wifibox) or a USB adapter) |
| Ethernet | Intel, Realtek, most others. The newest Realtek chips need `doas pkg install realtek-re-kmod`, which is not installed automatically (the hardware report says when you need it) | a few very new chips |
| Sound | Intel HDA codecs (Realtek, Conexant, Cirrus...), HDMI/DP audio, USB audio | Intel "Smart Sound"/SOF DSP audio (many 2020+ thin laptops) |
| Touchpad | I2C HID (most laptops since 2015), PS/2 Synaptics/Elantech | |
| Webcam | most USB UVC webcams (`webcamd`) | IPU6 MIPI cameras (Intel 2021+ laptops) |
| Bluetooth | keyboards, mice (manual pairing) | headphones/speakers |
| Fingerprint, IR face login | none | all |
| Sleep | S3 suspend on many Intel laptops; closing the lid suspends | modern standby (S0ix)-only laptops; laptops with an NVIDIA driver installed (lid close does nothing, because resume is unreliable); hibernate |
| Storage | NVMe, SATA in AHCI mode | Intel RST/RAID mode (switch to AHCI) |

## Machines reported

Add yours with a pull request or an issue (include `freebsd-setup --report`).

| Machine | FreeBSD | Desktop | Notes |
|---|---|---|---|
| QEMU/KVM virtual machine (q35, OVMF) | 15.1 | console only (as expected) | the automated test machine; installer and all setup stages pass |
