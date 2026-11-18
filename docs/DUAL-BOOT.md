# Dual boot: FreeBSD next to Windows or Linux

The installer's *Install next to the existing systems* option adds FreeBSD in
unallocated disk space and shares the existing EFI system partition. It needs a
GPT disk and the USB stick started in UEFI mode. It does not resize anything:
make room first (Windows *Disk Management* → *Shrink Volume*, or GParted from a
Linux live USB).

## How FreeBSD gets started

The installer copies FreeBSD's boot loader to `EFI/freebsd/loader.efi` on the
EFI partition and then, depending on what it finds there:

| Found on the EFI partition | What the installer does |
|---|---|
| anything | adds a firmware boot entry **FreeBSD** (at the end of the boot order unless you chose FreeBSD as default) |
| Limine (`limine.conf`) | appends a `/FreeBSD` entry (backup: `limine.conf.before-freebsd`), unless Limine checks that file against an enrolled checksum: then nothing (see below) |
| systemd-boot (`loader/entries/`) | adds `loader/entries/A-freebsd.conf` |
| rEFInd | nothing: rEFInd finds `EFI/freebsd/loader.efi` by itself |
| GRUB | nothing (GRUB's menu is generated from Linux; see below) |
| Windows Boot Manager or another default loader | FreeBSD's own menu gets **Start ... (L)** to go back to it |

Before you restart, you choose which system starts by default: the current one
(recommended), or FreeBSD's menu.

## Windows

- Switch off **Fast Startup** in Windows (Control Panel → Power Options →
  *Choose what the power buttons do*). With it on, Windows never really shuts
  down and leaves its disk half-mounted.
- **BitLocker** / device encryption: FreeBSD needs Secure Boot off, and
  Windows then asks once for its 48-digit recovery key. Save the key first
  (<https://aka.ms/myrecoverykey>). To avoid the prompt, suspend BitLocker for
  a few restarts right before switching Secure Boot off, in an administrator
  prompt: `manage-bde -protectors -disable C: -RebootCount 3`. Starting
  Windows from FreeBSD's menu (key L) may ask for the key every time: keep
  Windows as the default, or start it from the firmware boot menu. The
  installer detects BitLocker and asks whether you have the key.
- **Clock**: Windows keeps the hardware clock in local time. The installer asks
  and sets FreeBSD to match (`/etc/wall_cmos_clock`).
- **Starting FreeBSD**: with Windows as the default, use the firmware boot menu
  (F12/F11/F8/Esc at power-on, depending on the maker) and pick *FreeBSD*. With
  FreeBSD's menu as default, press **L** there to start Windows.
- Big **Windows updates** sometimes put Windows first in the boot order again.
  Fix it in the firmware setup or with `doas efibootmgr -o ...` from FreeBSD.

## Linux with Limine (e.g. CachyOS)

Limine can protect its menu file: a checksum of `limine.conf` is enrolled into
the Limine program on the EFI partition, and Limine then refuses to start
("CHECKSUM MISMATCH FOR CONFIG FILE") if the file changes by even one byte.
CachyOS does this by default (`ENABLE_ENROLL_LIMINE_CONFIG=yes` in
`/etc/default/limine`). The installer looks for an enrolled checksum in every
Limine program on the EFI partition:

- **None enrolled:** it appends the FreeBSD entry to `limine.conf`, and FreeBSD
  appears in the Limine menu right away.
- **Enrolled, or it cannot tell:** it leaves `limine.conf` alone. FreeBSD
  starts from the firmware boot menu until you add the entry from Linux.

Either way, the supported way to add the entry on CachyOS is its own command,
which also enrolls the new checksum. Run it once from CachyOS:

```sh
sudo limine-entry-tool --add-efi "FreeBSD" "/boot/EFI/freebsd/loader.efi" --comment "FreeBSD" --overwrite
```

(`/boot` is where CachyOS mounts the EFI partition; adjust if yours differs.
`sudo limine-scan` and picking *FreeBSD* from the firmware entries does the same
interactively.)

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

The installer adds `loader/entries/A-freebsd.conf`:

```
title   FreeBSD
efi     /EFI/freebsd/loader.efi
```

## FreeBSD's own boot menu

FreeBSD's menu shows the boot environments (key **8**) and, when the installer
found another default boot loader, **Start <name> (L)**. That entry comes from
two lines in `/boot/loader.conf`:

```
fbs_chain_path="/EFI/Microsoft/Boot/bootmgfw.efi"
fbs_chain_name="Windows Boot Manager"
```

and `/boot/lua/local.lua`, which finds the partition holding that file at every
boot. Change the path to start a different system (for example
`/EFI/limine/limine_x64.efi`).

## Removing FreeBSD

From the other system:

1. Delete the partitions labelled `fbsd-zfs` and `fbsd-swap` (Windows Disk
   Management, or GParted), then grow a neighbouring partition into the space.
2. Delete the folder `EFI/freebsd` from the EFI partition.
3. Remove the FreeBSD entry: the `/FreeBSD` block in `limine.conf`,
   `loader/entries/A-freebsd.conf`, or your GRUB `40_custom` entry.
4. Remove the firmware entry: `sudo efibootmgr` lists them,
   `sudo efibootmgr -b <number> -B` deletes one (Linux), or use the firmware
   setup.
