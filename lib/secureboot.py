#!/usr/bin/env python3
# Written by FreeBSD-setup
"""Secure Boot building blocks for LunaBSD (Python standard library only;
signatures are made with the openssl command).

LunaBSD starts with Secure Boot on the way Linux distributions without their
own Microsoft signature do (Arch's shim-signed, Ventoy): a shim signed by
Microsoft (Fedora's) starts FreeBSD's loader.efi, which is signed with a key
of this machine that the user enrolled once in shim's MOK list. On firmware
in Setup Mode, the machine's own keys go straight into the firmware, as
sbctl does. docs/SECUREBOOT.md explains it; lib/secureboot.sh uses this.

  secureboot.py sbat IN OUT VERSION       add a .sbat section (shim needs it)
  secureboot.py sections FILE             list the PE sections
  secureboot.py mok-request CERT.der CODE DIR
                                          DIR/MokNew and DIR/MokAuth: what
                                          `mokutil --import` writes; CODE is
                                          what the user types in MokManager
  secureboot.py esl OWNER OUT CERT.der... an EFI signature list (OWNER: a
                                          GUID, or "ms" for Microsoft's)
  secureboot.py guid                      a new random GUID (key owner)
  secureboot.py esl-certs FILE            SHA-256 of each certificate in an ESL
  secureboot.py auth VAR ESL OUT --cert C.pem --key K.pem [--append]
                                          an authenticated (time-based) write
                                          of VAR (PK, KEK or db) with ESL
"""

import datetime
import hashlib
import os
import struct
import subprocess
import sys
import tempfile
import uuid

GLOBAL_GUID = "8be4df61-93ca-11d2-aa0d-00e098032b8c"     # PK, KEK, SecureBoot
IMAGE_DB_GUID = "d719b2cb-3d3a-4596-a3bc-dad00e67656f"   # db, dbx
SHIM_GUID = "605dab50-e046-4300-abb6-3dd810dd8b23"       # MokNew, MokList...
CERT_X509_GUID = "a5c059a1-94e4-4aa7-87b5-ab155c2bf072"
CERT_PKCS7_GUID = "4aafd29d-68df-49ee-8aa9-347d375665a7"
MICROSOFT_OWNER = "77fa9abd-0359-4d32-bd60-28f4e78f784b"

NV, BS, RT, TIME_AUTH, APPEND = 0x01, 0x02, 0x04, 0x20, 0x40
VAR_GUID = {"PK": GLOBAL_GUID, "KEK": GLOBAL_GUID, "db": IMAGE_DB_GUID, "dbx": IMAGE_DB_GUID}


def guid_bytes(text):
    return uuid.UUID(text).bytes_le


# ------------------------------------------------------------------ PE ---

class PE:
    """The few parts of a PE32+ image needed to add a section."""

    def __init__(self, data):
        self.data = bytearray(data)
        if self.data[:2] != b"MZ":
            raise ValueError("not a PE file (no MZ header)")
        self.pe = struct.unpack_from("<I", self.data, 0x3C)[0]
        if self.data[self.pe:self.pe + 4] != b"PE\0\0":
            raise ValueError("not a PE file (no PE signature)")
        coff = self.pe + 4
        self.nsect_off = coff + 2
        self.nsect, = struct.unpack_from("<H", self.data, self.nsect_off)
        opt_size, = struct.unpack_from("<H", self.data, coff + 16)
        self.opt = coff + 20
        magic, = struct.unpack_from("<H", self.data, self.opt)
        if magic != 0x20B:
            raise ValueError("not a PE32+ (64-bit) image")
        self.sect_align, self.file_align = struct.unpack_from("<II", self.data, self.opt + 32)
        self.size_of_image, self.size_of_headers = struct.unpack_from("<II", self.data, self.opt + 56)
        self.ndirs, = struct.unpack_from("<I", self.data, self.opt + 108)
        self.table = self.opt + opt_size

    def sections(self):
        out = []
        for i in range(self.nsect):
            off = self.table + 40 * i
            name = bytes(self.data[off:off + 8]).rstrip(b"\0").decode("ascii", "replace")
            vsize, va, rawsize, rawptr = struct.unpack_from("<IIII", self.data, off + 8)
            flags, = struct.unpack_from("<I", self.data, off + 36)
            out.append((name, va, vsize, rawptr, rawsize, flags))
        return out

    def security_dir(self):
        if self.ndirs <= 4:
            return 0, 0
        return struct.unpack_from("<II", self.data, self.opt + 112 + 8 * 4)


def _align(n, a):
    return (n + a - 1) // a * a


def pe_checksum(data, checksum_off):
    """The PE header checksum (as Windows' CheckSumMappedFile computes it)."""
    total = 0
    buf = bytes(data) + (b"\0" if len(data) % 2 else b"")
    for i in range(0, len(buf), 2):
        if i in (checksum_off, checksum_off + 2):
            continue
        total += buf[i] | (buf[i + 1] << 8)
        total = (total & 0xFFFF) + (total >> 16)
    total = (total & 0xFFFF) + (total >> 16)
    return (total + len(data)) & 0xFFFFFFFF


def add_section(data, name, payload, flags=0x40000040):
    """Return the image with one more section (initialized, read-only data)
    holding payload. Refuses signed images (the signature would no longer
    match) and images whose headers have no room for another entry."""
    pe = PE(data)
    if any(s[0] == name for s in pe.sections()):
        raise ValueError("the image already has a %s section" % name)
    if pe.security_dir()[1]:
        raise ValueError("the image is signed; add sections before signing")
    sects = pe.sections()
    entry = pe.table + 40 * pe.nsect
    first_raw = min((s[3] for s in sects if s[4]), default=pe.size_of_headers)
    if entry + 40 > min(pe.size_of_headers, first_raw):
        raise ValueError("no room in the PE headers for another section")
    if any(pe.data[entry:entry + 40]):
        raise ValueError("the space after the section table is not empty")
    va = _align(max(s[1] + max(s[2], s[4]) for s in sects), pe.sect_align)
    raw_end = max(s[3] + s[4] for s in sects)
    rawptr = _align(max(raw_end, len(pe.data)), pe.file_align)
    rawsize = _align(len(payload), pe.file_align)
    out = pe.data
    out[len(out):] = b"\0" * (rawptr - len(out))
    out[rawptr:rawptr] = payload + b"\0" * (rawsize - len(payload))
    struct.pack_into("<8sIIIIIIHHI", out, entry, name.encode("ascii")[:8].ljust(8, b"\0"),
                     len(payload), va, rawsize, rawptr, 0, 0, 0, 0, flags)
    struct.pack_into("<H", out, pe.nsect_off, pe.nsect + 1)
    struct.pack_into("<I", out, pe.opt + 56, _align(va + len(payload), pe.sect_align))
    init_data, = struct.unpack_from("<I", out, pe.opt + 8)
    struct.pack_into("<I", out, pe.opt + 8, init_data + rawsize)
    struct.pack_into("<I", out, pe.opt + 64, 0)
    struct.pack_into("<I", out, pe.opt + 64, pe_checksum(out, pe.opt + 64))
    return bytes(out)


def sbat_text(version):
    """SBAT metadata (https://github.com/rhboot/shim/blob/main/SBAT.md):
    shim refuses a second stage without it. The generations only matter if
    someone ever revokes this loader."""
    return ("sbat,1,SBAT Version,sbat,1,https://github.com/rhboot/shim/blob/main/SBAT.md\n"
            "freebsd.loader,1,The FreeBSD Project,loader.efi,%s,https://www.freebsd.org/\n"
            "freebsd.loader.lunabsd,1,LunaBSD,loader.efi,%s,https://github.com/nimonht/LunaBSD\n"
            % (version, version)).encode("ascii")


# ----------------------------------------------------- signature lists ---

def esl(certs_der, owner):
    """One EFI_SIGNATURE_LIST per X.509 certificate (as mokutil and
    cert-to-efi-sig-list write them)."""
    out = b""
    for cert in certs_der:
        if cert[:2] != b"\x30\x82":
            raise ValueError("not a DER certificate")
        size = 16 + len(cert)
        out += guid_bytes(CERT_X509_GUID) + struct.pack("<III", 28 + size, 0, size)
        out += guid_bytes(owner) + cert
    return out


def esl_certs(data):
    """The DER certificates in a list of EFI signature lists."""
    certs, off = [], 0
    while off + 28 <= len(data):
        stype = data[off:off + 16]
        lsize, hsize, ssize = struct.unpack_from("<III", data, off + 16)
        if lsize < 28 or off + lsize > len(data) or ssize < 16:
            break
        if stype == guid_bytes(CERT_X509_GUID):
            p = off + 28 + hsize
            while p + ssize <= off + lsize:
                certs.append(bytes(data[p + 16:p + ssize]))
                p += ssize
        off += lsize
    return certs


def mok_request(cert_der, code):
    """MokNew and MokAuth for enrolling one certificate in shim's MOK list.
    MokAuth is the form MokManager checks as SHA-256(MokNew || password in
    UCS-2, no terminator): typing CODE in MokManager confirms the request."""
    moknew = esl([cert_der], SHIM_GUID)
    mokauth = hashlib.sha256(moknew + code.encode("utf-16-le")).digest()
    return moknew, mokauth


# ------------------------------------------- authenticated variables ---

def efi_time(when=None):
    t = when or datetime.datetime.now(datetime.timezone.utc)
    return struct.pack("<HBBBBBBIhBB", t.year, t.month, t.day, t.hour, t.minute, t.second,
                       0, 0, 0, 0, 0)


def _der_tlv(b, i):
    """(start of the value, end of the value) of the DER element at i."""
    n = b[i + 1]
    if n < 0x80:
        return i + 2, i + 2 + n
    k = n & 0x7F
    return i + 2 + k, i + 2 + k + int.from_bytes(b[i + 2:i + 2 + k], "big")


def signed_data(content_info):
    """The SignedData inside a PKCS#7 ContentInfo: the UEFI specification
    puts SignedData alone in the authentication header (as efitools does)."""
    start, _ = _der_tlv(content_info, 0)          # ContentInfo SEQUENCE
    _, oid_end = _der_tlv(content_info, start)    # contentType OID
    if content_info[oid_end] != 0xA0:
        raise ValueError("unexpected PKCS#7 structure")
    inner, _ = _der_tlv(content_info, oid_end)    # [0] EXPLICIT
    _, end = _der_tlv(content_info, inner)
    return content_info[inner:end]


def auth_payload(var, data, cert_pem, key_pem, append=False, when=None):
    """EFI_VARIABLE_AUTHENTICATION_2 + data, for SetVariable() with the
    time-based authenticated attribute: what sign-efi-sig-list writes."""
    attrs = NV | BS | RT | TIME_AUTH | (APPEND if append else 0)
    stamp = efi_time(when)
    signed = var.encode("utf-16-le") + guid_bytes(VAR_GUID[var]) + struct.pack("<I", attrs) + stamp + data
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "in")
        with open(src, "wb") as f:
            f.write(signed)
        p7 = subprocess.run(["openssl", "smime", "-sign", "-binary", "-noattr", "-md", "sha256",
                             "-outform", "DER", "-signer", cert_pem, "-inkey", key_pem, "-in", src],
                            check=True, capture_output=True).stdout
    p7 = signed_data(p7)
    cert = struct.pack("<IHH", 4 + 2 + 2 + 16 + len(p7), 0x0200, 0x0EF1) + guid_bytes(CERT_PKCS7_GUID) + p7
    return stamp + cert + data, attrs


# ------------------------------------------------------------------ CLI ---

def main(argv):
    if len(argv) < 2:
        sys.stderr.write(__doc__)
        return 2
    cmd, args = argv[1], argv[2:]
    if cmd == "sbat" and len(args) == 3:
        data = open(args[0], "rb").read()
        out = add_section(data, ".sbat", sbat_text(args[2]))
        with open(args[1], "wb") as f:
            f.write(out)
    elif cmd == "sections" and len(args) == 1:
        for name, va, vsize, rawptr, rawsize, flags in PE(open(args[0], "rb").read()).sections():
            print("%-8s va=%#x vsize=%#x raw=%#x rawsize=%#x flags=%#x" % (name, va, vsize, rawptr, rawsize, flags))
    elif cmd == "mok-request" and len(args) == 3:
        moknew, mokauth = mok_request(open(args[0], "rb").read(), args[1])
        for name, data in (("MokNew", moknew), ("MokAuth", mokauth)):
            with open(os.path.join(args[2], name), "wb") as f:
                f.write(data)
    elif cmd == "esl" and len(args) >= 3:
        owner = MICROSOFT_OWNER if args[0] == "ms" else args[0]
        with open(args[1], "wb") as f:
            f.write(esl([open(c, "rb").read() for c in args[2:]], owner))
    elif cmd == "guid" and not args:
        print(uuid.uuid4())
    elif cmd == "esl-certs" and len(args) == 1:
        for cert in esl_certs(open(args[0], "rb").read()):
            print(hashlib.sha256(cert).hexdigest())
    elif cmd == "auth" and len(args) >= 7 and args[0] in VAR_GUID:
        append = "--append" in args
        rest = [a for a in args if a != "--append"]
        var, src, out = rest[0], rest[1], rest[2]
        opts = dict(zip(rest[3::2], rest[4::2]))
        payload, attrs = auth_payload(var, open(src, "rb").read(), opts["--cert"], opts["--key"], append)
        with open(out, "wb") as f:
            f.write(payload)
        print("%x" % attrs)
    else:
        sys.stderr.write(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except (OSError, ValueError, subprocess.CalledProcessError) as e:
        sys.stderr.write("secureboot.py: %s\n" % e)
        sys.exit(1)
