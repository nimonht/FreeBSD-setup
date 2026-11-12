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
| Limine (`limine.conf`) | appends a `/FreeBSD` entry (backup: `limine.conf.before-freebsd`) |
| systemd-boot (`loader/entries/`) | adds `loader/entries/freebsd.conf` |
| rEFInd | nothing: rEFInd finds `EFI/freebsd/loader.efi` by itself |
| GRUB | nothing (GRUB's menu is generated from Linux; see below) |
| Windows Boot Manager or another default loader | FreeBSD's own menu gets **Start ... (L)** to go back to it |

Before you restart, you choose which system starts by default: the current one
(recommended), or FreeBSD's menu.

## Windows

- Switch off **Fast Startup** in Windows (Control Panel → Power Options →
  *Choose what the power buttons do*). With it on, Windows never really shuts
  down and leaves its disk half-mounted.
- **BitLocker** / device encryption: suspend it before changing partitions, or
  keep the recovery key at hand. A changed boot order can trigger the recovery
  screen once.
- **Clock**: Windows keeps the hardware clock in local time. The installer asks
  and sets FreeBSD to match (`/etc/wall_cmos_clock`).
- **Starting FreeBSD**: with Windows as the default, use the firmware boot menu
  (F12/F11/F8/Esc at power-on, depending on the maker) and pick *FreeBSD*. With
  FreeBSD's menu as default, press **L** there to start Windows.
- Big **Windows updates** sometimes put Windows first in the boot order again.
  Fix it in the firmware setup or with `doas efibootmgr -o ...` from FreeBSD.

## Linux with Limine (e.g. CachyOS)

The installer appends the FreeBSD entry to `limine.conf` and FreeBSD appears in
the Limine menu right away. CachyOS's `limine-entry-tool` updates its own kernel
entries and leaves other entries alone, but the officially supported way to add
an entry there is its own command. Run this once from CachyOS so the entry is
managed like the others:

```sh
sudo limine-entry-tool --add-efi "FreeBSD" "/boot/EFI/freebsd/loader.efi" --comment "FreeBSD" --overwrite
```

(`/boot` is where CachyOS mounts the EFI partition; adjust if yours differs.
`sudo limine-scan` and picking *FreeBSD* from the firmware entries does the same
interactively.)

## Linux with GRUB (Ubuntu, Fedora, Debian, Mint, openSUSE...)

GRUB's menu is generated on Linux, so add FreeBSD from there. Create
`/etc/grub.d/40_custom` (or append to it):

```
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

The installer adds `loader/entries/freebsd.conf`:

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
   `loader/entries/freebsd.conf`, or your GRUB `40_custom` entry.
4. Remove the firmware entry: `sudo efibootmgr` lists them,
   `sudo efibootmgr -b <number> -B` deletes one (Linux), or use the firmware
   setup.
