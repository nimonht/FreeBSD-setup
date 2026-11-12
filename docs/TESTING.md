# Testing

Four layers, from fast to slow.

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

## 3. The dialogs, with real key presses (a minute, FreeBSD only)

```sh
sh tests/ui-test.sh
```

Runs each `bsddialog` wrapper of `lib/ui.sh` (menus, checklists, input,
passwords, yes/no) inside a pseudo-terminal (`script(1)`) and types keys into
it: Enter, arrows, letter shortcuts, Space, Escape. Needs FreeBSD's
`bsddialog`, so it does not run in CI; the installed systems from the VM tests
carry it in `/usr/local/share/freebsd-setup/tests/`.

## 4. End to end on the official install image (hours)

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

All on FreeBSD 15.1-RELEASE's official `disc1` image, UEFI (OVMF), QEMU
without KVM. "Boot test" = the installed disk booted on its own, login on the
serial console, checks run on the installed system.

| Date | Scenario | Result |
|---|---|---|
| 2026-11-12 | Whole disk, **encrypted** (GELI), console only, German keyboard | **Pass**: installer and every setup stage (0 warnings); boot loader asks for the passphrase; root on `zroot/ROOT/default` over `vtbd0p4.eli`, swap on `fbsd-swap.eli`; firewall on; `@installed` and `@setup-…` snapshots present |
| 2026-11-12 | Next to existing EFI + Linux + Windows partitions, Limine 10.8.5 as boot manager | **Pass** (boot path): FreeBSD added to the Limine menu, boots from it, login works; after a restart FreeBSD's menu shows *Start Windows Boot Manager (L)* and **L** chainloads the other loader. (The setup stages in this run hit the bug fixed below; re-run with Hyprland in progress.) |
| 2026-11-12 | `tests/ui-test.sh`: every dialog type driven with real key presses | **Pass** 11/11 on FreeBSD 15.1 with the base system's `bsddialog` |
| 2026-11-12 | Whole disk, KDE Plasma (quarterly packages), apps, printing, with `freebsd-update` | in progress |
| 2026-11-12 | Next to Windows/Linux (Limine), Hyprland + Caelestia, Vietnamese input, gaming | in progress |
| 2026-11-11 | Hyprland + Caelestia 2.5.0 build and Hyprland stages on an installed system | Pass (build; no GPU to start the session) |

### Bugs these tests caught before any user did

- The setup stages were started in the new system with `SSL_CA_CERT_FILE`
  set to an empty string, which makes FreeBSD's fetch library reject every
  HTTPS certificate: **every install would have ended without a desktop**.
- A successful install with no warnings exited with status 1 (a `set -e`
  pitfall in building the final message).
- An unattended run with an existing user name looped forever.
- In the test harness itself: the dual-boot disk was not partitioned, two
  6 GB VMs ran the machine out of memory, and check markers matched the echo
  of the typed command.
