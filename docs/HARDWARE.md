# Hardware

FreeBSD-setup detects the hardware at install time and picks drivers itself.
This page explains the rules it follows, so you can judge a machine before
buying or installing, and lists machines people have tried.

Run the check yourself on any FreeBSD 15 system or from the Live System of the
install USB stick:

```sh
fetch -qo- https://raw.githubusercontent.com/nimonht/FreeBSD-setup/main/bootstrap.sh | sh -s -- --dry-run
# or, in a cloned repository:
./setup.sh --report
```

## Graphics: what decides whether the desktop runs

KDE Plasma 6 (6.8 on the "latest" package branch, 6.7 on "quarterly") and Hyprland are
Wayland desktops: they need a graphics driver with kernel mode setting (KMS).

| GPU | Driver chosen | Desktop |
|---|---|---|
| Intel HD/UHD/Iris/Iris Xe/Arc integrated (Sandy Bridge 2011 → Meteor Lake, Arrow Lake) | `i915kms` (drm-kmod) | Yes |
| Intel Arc (DG2) desktop cards | `i915kms` | Experimental |
| Intel Lunar Lake, Battlemage, Panther Lake | needs the `xe` driver (not in FreeBSD yet) | No |
| AMD Radeon GCN 1.2 and newer (R9 285/Fury, RX 400–7000, Vega, Ryzen APUs) | `amdgpu` | Yes |
| AMD Radeon RX 9000 (RDNA 4) | `amdgpu` | Not yet: newer than FreeBSD's driver |
| AMD Radeon HD 2000 – R9 290 (TeraScale, GCN 1.0/1.1) | `radeonkms` | Yes, slower |
| NVIDIA GeForce 16/20/30/40/50 series (Turing and newer) | `nvidia-driver` (current) | Yes |
| NVIDIA GeForce GTX 750/900/10 series, Titan V (Maxwell, Pascal, Volta) | `nvidia-driver-580` (legacy, last for these GPUs) | Yes |
| NVIDIA Kepler (GTX 600/700) and older | `nvidia-driver-470/390/340` | No: X11-only drivers |
| VirtualBox, VMware, QEMU/KVM, Hyper-V, bhyve | none | No: console only |

The NVIDIA branch comes from NVIDIA's own list of device IDs
([lib/nvidia-branches.txt](../lib/nvidia-branches.txt), generated from the
driver's README), so every card gets exactly the driver NVIDIA supports it with.

**Laptops with two GPUs** (Intel/AMD + NVIDIA/AMD): the desktop runs on the
integrated GPU, which drives the screen; `gpu-run <program>` runs a program on
the other one. On FreeBSD the extra GPU cannot be powered down completely, so
expect shorter battery life than on Windows or Linux. Setting
`GPU_DRIVERS="intel"` (or `amd`) in `/usr/local/etc/freebsd-setup.conf` leaves
the NVIDIA card without a driver, which FreeBSD then powers down as far as it
can.

## Other parts

| Part | Works | Doesn't |
|---|---|---|
| Wi-Fi | Intel (`iwlwifi`, `iwm`), Realtek RTW88/RTW89, many USB adapters; newer MediaTek and Qualcomm chips in FreeBSD 15 | Broadcom (use [wifibox](https://github.com/pgj/freebsd-wifibox) or a USB adapter) |
| Ethernet | Intel, Realtek (`realtek-re-kmod` for the newest), most others | a few very new chips |
| Sound | Intel HDA codecs (Realtek, Conexant, Cirrus...), HDMI/DP audio, USB audio | Intel "Smart Sound"/SOF DSP audio (many 2020+ thin laptops) |
| Touchpad | I2C HID (most laptops since 2015), PS/2 Synaptics/Elantech | — |
| Webcam | most USB UVC webcams (`webcamd`) | IPU6 MIPI cameras (Intel 2021+ laptops) |
| Bluetooth | keyboards, mice (manual pairing) | headphones/speakers |
| Fingerprint, IR face login | — | all |
| Sleep | S3 suspend on many Intel laptops | modern standby (S0ix)-only laptops; hibernate |
| Storage | NVMe, SATA in AHCI mode | Intel RST/RAID mode (switch to AHCI) |

## Machines reported

Add yours with a pull request or an issue (include `freebsd-setup --report`).

| Machine | FreeBSD | Desktop | Notes |
|---|---|---|---|
| QEMU/KVM virtual machine (q35, OVMF) | 15.1 | console only (as expected) | the automated test machine; installer and all setup stages pass |
