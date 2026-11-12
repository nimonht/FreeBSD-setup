# Testing

Three layers, from fast to slow.

## 1. Lint (seconds)

```sh
shellcheck -s sh -S warning -e SC1090,SC1091,SC2034,SC2154,SC3043 \
  setup.sh install.sh bootstrap.sh lib/*.sh stages/*.sh files/bin/* caelestia/build.sh
```

Runs in CI on every push (`.github/workflows/ci.yml`).

## 2. Hardware detection against recorded machines (seconds)

```sh
sh tests/run.sh          # every profile
sh tests/run.sh -v NAME  # one profile, with its full report
```

Each directory in `tests/fixtures/` holds the raw output of the probes the
detection reads (`pciconf -lv`, `usbconfig`, `sysctl`, `kenv`, `/dev/sndstat`)
for one machine, plus `expect.txt` with the results it must produce (driver
choices, desktop capability, report lines). The tests run with any POSIX `sh`,
also on Linux and macOS, and in CI.

Current profiles: ASUS GL553VD (Intel + NVIDIA Pascal), ThinkPad T480 (Intel,
fingerprint reader), AMD Ryzen desktop with Radeon RX 6700 XT, NVIDIA RTX 3060
desktop, NVIDIA Kepler desktop with legacy BIOS, VirtualBox, Lenovo Legion
(AMD APU + RTX 3050, MediaTek Wi-Fi, no S3), MacBook Pro with Broadcom Wi-Fi,
Lunar Lake laptop with SOF audio, Radeon HD 7850 on 3 GB RAM.

**Add your machine**: on FreeBSD run `sh tests/collect-fixture.sh <name>`, check
`tests/fixtures/<name>/expect.txt`, and open a pull request.

## 3. End to end on the official install image (hours)

```sh
sh tests/vm/run-iso-test.sh FreeBSD-15.1-RELEASE-amd64-disc1.iso tests/install-erase-kde.conf
```

This boots the unmodified FreeBSD install ISO in QEMU (UEFI), goes through the
loader menu, chooses **Live System** at the installer's welcome screen, logs in
as root, gets an address with DHCP, and runs `install.sh` with the answers from
the config file, exactly as a user would after the bootstrap one-liner. The
serial console is driven by `tests/vm/drive.py`. The test passes when the
installer reports *FreeBSD is installed* and exits 0; the installed disk is left
in `tests/vm/work/target.qcow2` to boot and inspect.

Without KVM, everything is emulated and a KDE install takes several hours. A
virtual machine can only check the console side: the KDE and Hyprland sessions
need a real GPU, so they are not started in this test.

### Results

| Date | FreeBSD | Scenario | Result |
|---|---|---|---|
| 2026-11-12 | 15.1-RELEASE disc1, UEFI, QEMU without KVM | Live System → erase disk → KDE Plasma, apps, printing, firewall, snapshots | see below |
| 2026-11-11 | 15.1-RELEASE, UEFI, QEMU | install next to existing EFI/Linux/Windows partitions, Limine menu entry, boot through Limine 10.8.5 | passed (earlier version of the installer) |
| 2026-11-11 | 15.1-RELEASE | Hyprland + Caelestia 2.5.0 build and all Hyprland stages | passed (build; no GPU to start the session) |
