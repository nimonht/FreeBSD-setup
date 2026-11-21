# Dual boot: FreeBSD next to Windows or Linux

The installer's *Install next to the existing systems* option adds FreeBSD in
unallocated disk space and shares the existing EFI system partition. It needs:

- a GPT disk, and the USB stick started in UEFI mode;
- an EFI system partition on the same disk FreeBSD goes on. If the disk's
  system starts from another disk's EFI partition, the installer cannot put
  FreeBSD next to it and only offers to erase that disk, which would delete
  the system on it. Quit, and choose the disk that has the EFI partition;
- one unallocated area (only the largest one is used) big enough for 30 GB of
  FreeBSD plus its swap (2 to 8 GB, depending on RAM).

It does not resize anything: make room first (Windows *Disk Management* →
*Shrink Volume*, or GParted from a Linux live USB).

Do not install next to another FreeBSD on the same disk. Both would share the
EFI partition's `EFI/freebsd` folder, and after the install every boot menu
entry starts the new FreeBSD. The old one is not deleted, but it can only be
started by hand: press 3 in FreeBSD's menu for the loader prompt, type
`set currdev=zfs:zroot/ROOT/default:` (with the old pool's name), then `boot`.
To replace an old FreeBSD, delete its partitions first (see
[Removing FreeBSD](#removing-freebsd)), or install on another disk.

## How FreeBSD gets started

The installer copies FreeBSD's boot loader to `EFI/freebsd/loader.efi` on the
EFI partition and then, depending on what it finds there:

| Found on the EFI partition | What the installer does |
|---|---|
| anything | adds a firmware boot entry *FreeBSD* (at the end of the boot order unless you chose FreeBSD to start first) |
| Limine (`limine.conf`) | appends a `/FreeBSD` entry to the first `limine.conf` it finds and names that file on screen (backup: the same name plus `.before-freebsd`), unless Limine checks that file against an enrolled checksum or this cannot be checked: then nothing (see below). If your EFI partition has more than one `limine.conf`, make sure the entry is in the one Limine reads (the one next to the Limine program comes first) |
| systemd-boot (`loader/loader.conf` and `EFI/systemd/`) | adds `loader/entries/A-freebsd.conf` (listed last, so your default stays) |
| rEFInd | nothing: rEFInd finds `EFI/freebsd/loader.efi` by itself |
| GRUB | nothing (GRUB's menu is generated from Linux; see below) |
| Windows Boot Manager, or Limine as the current default with its `limine.conf` at the EFI partition root or in `limine/`, `boot/`, `boot/limine/` or `EFI/BOOT/` | FreeBSD's own menu gets *Start ... (L)*. Other boot loaders (GRUB/shim, systemd-boot, rEFInd) cannot be started from FreeBSD's menu: use the firmware boot menu. When Windows Boot Manager is on the EFI partition, L starts Windows even if a Linux boot manager was the default |

Along with the other questions, before anything is written, you choose which
system starts when you turn the computer on: the current one (recommended), or
FreeBSD. If FreeBSD's menu can start your other system (key L, see the table),
choosing FreeBSD gives you that entry. Otherwise you then start the other
system from the firmware boot menu. With disk encryption, FreeBSD asks for its
passphrase before its menu appears, so reaching the other system through L
means typing that passphrase first.

## FreeBSD on its own disk

If you erase a second disk while Windows or Linux stays on another disk, the
installer asks which system starts when you turn the computer on. Keep the
other system first (recommended) and start FreeBSD from the firmware boot menu
(F12/F11/F8/Esc at power-on), or make FreeBSD start first. If the other system
is Windows, FreeBSD's own menu also gets *Start Windows Boot Manager (L)*, and
the clock question suggests local time. The other disk is not changed. Before
erasing, the installer names any system that starts from the disk being
erased.

## Windows

- Switch off *Fast Startup* in Windows (Control Panel → Power Options →
  *Choose what the power buttons do*). With it on, Windows never really shuts
  down and leaves its disk half-mounted.
- BitLocker / device encryption: LunaBSD keeps Secure Boot on
  ([SECUREBOOT.md](SECUREBOOT.md)), so Windows starts as before. Save the
  48-digit recovery key anyway (<https://aka.ms/myrecoverykey>): Windows asks
  for it if Secure Boot is ever switched off (to avoid that, suspend
  BitLocker for a few restarts first, in an administrator prompt:
  `manage-bde -protectors -disable C: -RebootCount 3`), and may ask every
  time it is started from FreeBSD's menu (key L): keep Windows as the
  default, or start it from the firmware boot menu. The installer detects
  BitLocker and says what applies.
- Clock: Windows keeps the hardware clock in local time. The installer asks
  and sets FreeBSD to match (`/etc/wall_cmos_clock`).
- Starting FreeBSD: with Windows as the default, use the firmware boot menu
  (F12/F11/F8/Esc at power-on, depending on the maker) and pick *FreeBSD*. With
  FreeBSD's menu as default, press L there to start Windows.
- Big Windows updates sometimes put Windows first in the boot order again.
  Fix it in the firmware setup or with `doas efibootmgr -o ...` from FreeBSD.

## Linux with Limine (e.g. CachyOS)

Limine can protect its menu file: a checksum of `limine.conf` is enrolled into
the Limine program on the EFI partition, and Limine then refuses to start
("CHECKSUM MISMATCH FOR CONFIG FILE") if the file changes by even one byte.
CachyOS does this by default (`ENABLE_ENROLL_LIMINE_CONFIG=yes` in
`/etc/default/limine`). The installer looks for an enrolled checksum in every
Limine program on the EFI partition:

- None enrolled: it appends the FreeBSD entry to `limine.conf`, and FreeBSD
  appears in the Limine menu right away.
- Enrolled, or it cannot tell: it leaves `limine.conf` alone. FreeBSD
  starts from the firmware boot menu until you add the entry from Linux.

Either way, the supported way to add the entry on CachyOS is its own command,
which also enrolls the new checksum. Run it once from CachyOS:

```sh
sudo limine-entry-tool --add-efi FreeBSD /boot/EFI/freebsd/loader.efi --comment FreeBSD --overwrite
```

It prints `Updated: ...limine.conf` when it worked. If it prints nothing, your
EFI partition is not mounted at `/boot`: `findmnt -t vfat` shows where it is;
use that folder instead of `/boot` and run it again. `sudo limine-scan`, then
picking *FreeBSD* from the firmware entries, does the same interactively.

On other systems with an enrolled checksum, add the entry by hand, then enroll
the new checksum into the Limine program the firmware starts (and sign it again
if you use Secure Boot):

```
/FreeBSD
    protocol: efi
    path: boot():/EFI/freebsd/loader.efi
```

```sh
sudo limine enroll-config /boot/EFI/BOOT/BOOTX64.EFI "$(b2sum /boot/limine.conf | cut -d' ' -f1)"
```

## Linux with GRUB (Ubuntu, Fedora, Debian, Mint, openSUSE...)

GRUB's menu is generated on Linux, so add FreeBSD from there. Add this to
`/etc/grub.d/40_custom` (append to it; keep its first two lines, `#!/bin/sh` and
`exec tail -n +3 $0`). The first two lines below show the GRUB menu even when
your distribution hides it because only one system was installed:

```
set timeout_style=menu
if [ "${timeout}" = 0 ]; then set timeout=10; fi
menuentry "FreeBSD" {
    insmod part_gpt
    insmod fat
    search --no-floppy --file --set=root /EFI/freebsd/loader.efi
    chainloader /EFI/freebsd/loader.efi
}
```

Then regenerate the menu:
`sudo update-grub` (Debian/Ubuntu/Mint), `sudo grub2-mkconfig -o /boot/grub2/grub.cfg`
(Fedora/openSUSE), or `sudo grub-mkconfig -o /boot/grub/grub.cfg` (Arch).

`os-prober` does not detect FreeBSD's EFI loader, so the custom entry is needed.

## Linux with systemd-boot

The installer adds `loader/entries/A-freebsd.conf`. It sorts last, so your
current default stays the default:

```
# Written by FreeBSD-setup
title   FreeBSD
efi     /EFI/freebsd/loader.efi
```

On CachyOS or Arch with sdboot-manage: if FreeBSD disappears from the menu
after a Linux kernel update, open `/etc/sdboot-manage.conf`, set
`REMOVE_EXISTING="no"`, and create the file above again. Until then, start
FreeBSD from the firmware boot menu.

## FreeBSD's own boot menu

FreeBSD's menu shows the boot environments (key 8). When the installer could
set it up (Windows Boot Manager, or a Limine whose `limine.conf` is at the EFI
partition root or in `limine/`, `boot/`, `boot/limine/` or `EFI/BOOT/`), it
also shows *Start <name> (L)*. That entry comes from two lines in
`/boot/loader.conf`:

```
fbs_chain_path="/EFI/Microsoft/Boot/bootmgfw.efi"
fbs_chain_name="Windows Boot Manager"
```

and `/boot/lua/local.lua`. At every start, local.lua looks for that file on
the first four disks (partitions 1-12) and uses the first match; if it finds
none, the L entry is not shown. You can change the path to start a different
Windows or Limine. GRUB/shim cannot be started this way.

## Removing FreeBSD

From the other system:

1. Delete the partitions labelled `fbsd-zfs` and `fbsd-swap` (or `fbsd-zfs1`,
   `fbsd-swap1`... when an earlier install already used the plain names; there
   is no swap partition if you chose none) with Windows Disk Management or
   GParted, then grow a neighbouring partition into the space.
2. Delete the folder `EFI/freebsd` from the EFI partition.
3. Remove the FreeBSD entry: the `/FreeBSD` block in `limine.conf` (if your
   Limine checks an enrolled checksum, as on CachyOS, enroll the new checksum
   afterwards as shown above, or Limine stops starting),
   `loader/entries/A-freebsd.conf`, or your GRUB `40_custom` entry.
4. Remove the firmware entry: `sudo efibootmgr` lists them,
   `sudo efibootmgr -b <number> -B` deletes one (Linux), or use the firmware
   setup.
