# Secure Boot

Most PCs come with UEFI Secure Boot switched on: the firmware starts only
boot programs signed by a key it trusts, which on almost every PC means
signed by Microsoft. FreeBSD's boot loader is not signed by Microsoft, so
plain FreeBSD needs Secure Boot switched off. LunaBSD keeps it on, the way
Linux distributions without their own Microsoft signature do it (Arch's
`shim-signed`, Ventoy).

**Status.** What ran, and where:

| Part | Tested |
|---|---|
| Setup Mode: keys enrolled from the live system with Microsoft's; then the loader signed with the computer's key starts and FreeBSD's unsigned loader is refused (*Access Denied*) | In QEMU on EDK2's UEFI firmware (OVMF), `tests/vm/run-secureboot-test.sh ISO setup` |
| The `.sbat` section, signatures, MOK request and key lists, byte for byte against efitools and sbsigntool | `tests/secureboot-test.py`, `tests/secureboot-sh-test.sh` (CI) |
| Secure Boot on with Microsoft's keys: Fedora's shim starts, refuses the unknown loader, MokManager enrolls the stick's key file, then shim starts FreeBSD's loader and the live system (Secure Boot reported on); a MOK request written from FreeBSD with `efivar` is taken by MokManager with its 8-digit code, and both keys are then in shim's list | In QEMU on OVMF with Microsoft's keys, `tests/vm/run-secureboot-test.sh ISO mok` |
| The stick with Secure Boot off (shim starts the loader without checking) | The usual live test, `tests/vm/run-live-test.sh` |
| A whole installation with Secure Boot on, to the installed system's first start | Not yet as one run (each step above ran on its own) |
| Any of it on a real PC | Not yet |

## What you see

**Starting the USB stick with Secure Boot on**, once per computer (and once
more for each newer ISO, which has a key of its own):

1. A blue box says *Verification failed: (0x1A) Security Violation*. That is
   expected: the computer does not know this stick's key yet. Press Enter
   (OK).
2. *Press any key to perform MOK management* (10 seconds): press a key. The
   menu *Perform MOK management* opens (this is MokManager).
3. Choose **Enroll key from disk**, then **EFISYS** (the stick), then
   **ENROLL_THIS_KEY_IN_MOKMANAGER.cer**.
4. **Continue**, **Yes**, then **Reboot**. Start from the stick again; from
   now on it starts directly.

**After installing**, once:

1. At the first start, a blue screen says *Press any key to perform MOK
   management*. Press a key (within 10 seconds; if you miss it, it comes
   back at the next start).
2. Choose **Enroll MOK**, then **Continue**, then **Yes**.
3. Type the eight-digit code the installer showed at the end, press Enter,
   choose **Reboot**.

The code only proves that someone at the keyboard agreed; it is not a
password you need again. The keyboard in that screen is always an English
(US) one, which is why the code has digits only.

**Firmware in Setup Mode** (you cleared the Secure Boot keys in the firmware
settings, as sbctl and CachyOS's guide ask): the installer enrolls this
computer's own keys and asks nothing. See *Setup Mode* below.

## How it works

```
firmware  --(Microsoft UEFI CA)-->  shim (Fedora's, signed by Microsoft)
shim      --(MOK list)----------->  FreeBSD's loader.efi, signed with this
                                    computer's key (as grubx64.efi)
loader    ------------------------> FreeBSD's kernel
```

- **shim** is the small first-stage boot program that Linux distributions
  get signed by Microsoft. It trusts what Microsoft trusts plus a list of
  keys the owner of the computer added, the *MOK* list (Machine Owner Key).
  Adding a key needs someone at the keyboard to confirm it in MokManager,
  which is the blue screen above. LunaBSD uses Fedora's shim 16.1-7,
  signed with both Microsoft's 2011 and 2023 certificates (so it starts on
  older PCs and on new ones that trust only the 2023 one), checked by its
  SHA-256 before use (`lib/secureboot.sh`).
- **The live USB's loader** is signed with a key made for that ISO alone;
  its certificate is the `.cer` file on the stick. The private half is
  deleted as soon as the loader is signed, so nobody, the project included,
  can sign anything else with it. A newer ISO has a new key, enrolled once
  more the first time it starts (installed systems are not affected: they
  have their own keys).
- **An installed system** makes its own keys at installation
  (`/var/db/lunabsd-secureboot`, readable by root only), signs FreeBSD's
  loader with them and asks shim to add the key (what `mokutil --import`
  does on Linux, written with FreeBSD's `efivar`). The key file is also on
  the EFI partition, `EFI/freebsd/ENROLL_THIS_KEY_IN_MOKMANAGER.cer`, for
  *Enroll key from disk*.
- shim refuses a second stage without SBAT data (its revocation scheme), so
  the loader gets an `.sbat` section before it is signed
  (`lib/secureboot.py`).

Updates: `sysup` runs `secureboot refresh`, which signs FreeBSD's loader
again whenever an update put a new one in `/boot`, and puts it on the EFI
partition.

### Setup Mode

With the firmware's keys cleared (Setup Mode), the installer does what
`sbctl create-keys && sbctl enroll-keys --microsoft` does on Linux: this
computer's keys go into the firmware (db, KEK, then the platform key, which
ends Setup Mode), together with Microsoft's certificates
(`files/secureboot/microsoft/`, from Microsoft's own repository). Microsoft's
are needed: Windows, firmware updates and the firmware of graphics cards are
signed with them, and without them a PC can stay black at power-on.
Entries already in the firmware are kept (added to, never replaced). No shim
is used then; the loader is signed with this computer's db key.

## What it does not do

- **FreeBSD's loader does not check the kernel.** FreeBSD's default build
  has no such check (the `LOADER_EFI_SECUREBOOT` and `LOADER_VERIEXEC`
  options are off). Secure Boot stays on, so Windows, its BitLocker and games
  whose anti-cheat requires Secure Boot keep working, but the chain is
  checked up to FreeBSD's loader only, unlike Fedora or Ubuntu where shim's
  signature check reaches the kernel.
- **Fedora's shim trusts Fedora's key too.** Anything Fedora signed (its
  GRUB and kernels) starts on a computer that runs this shim, as on any PC
  with Fedora installed. This is the same trade-off Arch's `shim-signed`
  makes.
- **No Microsoft key is used to sign anything.** The firmware holds only
  Microsoft's *certificates*, which check signatures; the private keys that
  make them stay with Microsoft, which signs shims for distributions after a
  review. That is why a distribution without its own reviewed shim borrows
  one (here Fedora's) and brings its own key for what comes after it, and
  why sbctl makes your own keys instead of using Microsoft's.
- A signature by LunaBSD's own Microsoft-signed shim (no blue screen at
  all, as on Ubuntu) needs an organisation, the shim review board and
  Microsoft's signing service. It is on the roadmap
  ([DISTRO.md](DISTRO.md)), not done.

## Commands

```sh
secureboot                 # firmware state and this system's setup
doas secureboot enable     # set it up on a system installed with Secure Boot off
doas secureboot refresh    # sign the boot loader again (sysup does this)
```

`secureboot enable` on a system installed with Secure Boot off: run it, then
restart, confirm the key (the code it prints), and switch Secure Boot on in
the firmware settings.

## When something goes wrong

- **"Verification failed" and a blue screen at every start**: the key was
  not enrolled. Choose *Enroll key from disk* and
  `EFI/freebsd/ENROLL_THIS_KEY_IN_MOKMANAGER.cer`, or start with Secure
  Boot off and run `doas secureboot enable` for a new code.
- **"Security violation" with no blue screen**: the firmware did not start
  shim. Its db may lack Microsoft's third-party certificate (some PCs have
  an option such as *Allow Microsoft 3rd Party UEFI CA*: switch it on), or
  the PC trusts neither of the certificates shim is signed with.
- **Going back to Secure Boot off** needs nothing else: with it off, shim
  and the signed loader still start LunaBSD.

## Sources

How this was worked out, for whoever changes it:

- shim: <https://github.com/rhboot/shim> (`shim.c`: second stage
  `grubx64.efi`, MokManager on a verification failure or a pending request;
  `pe.c`: SBAT is mandatory for images shim loads; `MokManager.c`: a
  request's `MokAuth` may be SHA-256 of `MokNew` and the password in UCS-2);
  SBAT: <https://github.com/rhboot/shim/blob/main/SBAT.md>
- mokutil (what `--import` writes): <https://github.com/lcp/mokutil>
- sbctl (own keys, Microsoft's certificates, option ROMs):
  <https://github.com/Foxboron/sbctl>
- CachyOS: <https://wiki.cachyos.org/configuration/secure_boot_setup/>
- Arch Linux: the *Secure Boot* page of the ArchWiki, and the `shim-signed`
  package (Fedora's shim 16.1-7 from koji)
- Microsoft's 2023 certificates and the end of the 2011 ones:
  <https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/linux-distribution-guidance-handling-2023keys>,
  <https://lwn.net/Articles/1079808/>, the certificates:
  <https://github.com/microsoft/secureboot_objects>
- FreeBSD: `uefisign(8)`, `efivar(8)`
