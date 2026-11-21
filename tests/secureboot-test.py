#!/usr/bin/env python3
"""Secure Boot building blocks (lib/secureboot.py), checked against the
reference tools where they are installed (efitools: cert-to-efi-sig-list,
sign-efi-sig-list; sbsigntool: sbsign, sbverify; binutils objdump):

  python3 tests/secureboot-test.py

LOADER_EFI=path/to/loader.efi also checks FreeBSD's real loader (the ISO has
one in boot/). What this cannot check is the firmware and shim themselves:
tests/vm/run-secureboot-test.sh boots them in QEMU."""
import datetime
import hashlib
import os
import shutil
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "lib"))
import secureboot as sb  # noqa: E402

failed = 0


def check(name, ok, detail=""):
    global failed
    print(("ok:   " if ok else "FAIL: ") + name + ("" if ok else "  " + detail))
    if not ok:
        failed = 1


def have(tool):
    return shutil.which(tool) is not None


def tiny_pe():
    """A minimal PE32+ EFI application: headers and two sections."""
    data = bytearray(0x800)
    data[0:2] = b"MZ"
    struct.pack_into("<I", data, 0x3C, 0x80)
    data[0x80:0x84] = b"PE\0\0"
    struct.pack_into("<HHIIIHH", data, 0x84, 0x8664, 2, 0, 0, 0, 0xF0, 0x22)
    opt = 0x98
    struct.pack_into("<HBBIIIII", data, opt, 0x20B, 0, 0, 0x200, 0x200, 0, 0x1000, 0x1000)
    struct.pack_into("<Q", data, opt + 24, 0)                          # ImageBase
    struct.pack_into("<II", data, opt + 32, 0x1000, 0x200)            # alignments
    struct.pack_into("<II", data, opt + 56, 0x3000, 0x400)            # SizeOfImage, headers
    struct.pack_into("<HH", data, opt + 68, 10, 0)                    # EFI application
    struct.pack_into("<I", data, opt + 108, 16)                       # data directories
    table = opt + 0xF0
    struct.pack_into("<8sIIIIIIHHI", data, table, b".text", 0x10, 0x1000, 0x200, 0x400, 0, 0, 0, 0, 0x60000020)
    struct.pack_into("<8sIIIIIIHHI", data, table + 40, b".data", 0x10, 0x2000, 0x200, 0x600, 0, 0, 0, 0, 0xC0000040)
    data[0x400:0x401] = b"\xC3"
    return bytes(data)


tmp = tempfile.mkdtemp()
try:
    # --- PE: adding the .sbat section -----------------------------------
    sbat = sb.sbat_text("15.1")
    lines = sbat.decode().splitlines()
    check("SBAT: header line first, then the loader's entries",
          lines[0].startswith("sbat,1,") and all(len(l.split(",")) == 6 for l in lines), repr(lines))
    pe0 = tiny_pe()
    pe1 = sb.add_section(pe0, ".sbat", sbat)
    secs = sb.PE(pe1).sections()
    s = secs[-1]
    check("PE: one more section, named .sbat", len(secs) == 3 and s[0] == ".sbat", str(secs))
    check("PE: .sbat placed after the last section, aligned", s[1] == 0x3000 and s[3] == 0x800 and s[3] % 0x200 == 0,
          "va=%#x raw=%#x" % (s[1], s[3]))
    check("PE: .sbat holds exactly the SBAT text", pe1[s[3]:s[3] + s[2]] == sbat)
    hdr = sb.PE(pe1)
    check("PE: SizeOfImage covers the new section", hdr.size_of_image == 0x4000, "%#x" % hdr.size_of_image)
    ck_off = hdr.opt + 64
    check("PE: header checksum is consistent", struct.unpack_from("<I", pe1, ck_off)[0] == sb.pe_checksum(pe1, ck_off))
    check("PE: the original bytes before the new data are unchanged except the headers",
          pe1[0x400:0x800] == pe0[0x400:0x800])
    try:
        sb.add_section(pe1, ".sbat", sbat)
        check("PE: a second .sbat is refused", False)
    except ValueError:
        check("PE: a second .sbat is refused", True)
    signed = bytearray(pe0)
    struct.pack_into("<II", signed, 0x98 + 112 + 8 * 4, 0x800, 0x100)
    try:
        sb.add_section(bytes(signed), ".sbat", sbat)
        check("PE: a signed image is refused", False)
    except ValueError:
        check("PE: a signed image is refused", True)
    path1 = os.path.join(tmp, "tiny.efi")
    open(path1, "wb").write(pe1)
    if have("objdump"):
        out = subprocess.run(["objdump", "-h", path1], capture_output=True, text=True)
        check("objdump reads the image and sees .sbat", out.returncode == 0 and ".sbat" in out.stdout, out.stderr)

    # --- keys -------------------------------------------------------------
    def keypair(name):
        key, pem, der = (os.path.join(tmp, name + e) for e in (".key", ".pem", ".cer"))
        subprocess.run(["openssl", "req", "-new", "-x509", "-newkey", "rsa:2048", "-nodes", "-sha256",
                        "-days", "3650", "-subj", "/CN=test %s/" % name, "-keyout", key, "-out", pem],
                       check=True, capture_output=True)
        subprocess.run(["openssl", "x509", "-in", pem, "-outform", "DER", "-out", der], check=True)
        return key, pem, der
    dbkey, dbpem, dbcer = keypair("db")
    pkkey, pkpem, pkcer = keypair("PK")
    cert = open(dbcer, "rb").read()

    if have("sbsign") and have("sbverify"):
        out = os.path.join(tmp, "tiny-signed.efi")
        r = subprocess.run(["sbsign", "--key", dbkey, "--cert", dbpem, "--output", out, path1], capture_output=True, text=True)
        v = subprocess.run(["sbverify", "--cert", dbpem, out], capture_output=True, text=True)
        check("sbsign signs the image with .sbat; sbverify accepts it", r.returncode == 0 and v.returncode == 0,
              r.stderr + v.stderr)

    # --- signature lists and the MOK request ------------------------------
    owner = "11111111-2222-3333-4444-555555555555"
    e = sb.esl([cert], owner)
    check("ESL: size fields", struct.unpack_from("<III", e, 16) == (28 + 16 + len(cert), 0, 16 + len(cert)))
    check("ESL: certificate read back", sb.esl_certs(e + sb.esl([open(pkcer, "rb").read()], owner))
          == [cert, open(pkcer, "rb").read()])
    if have("cert-to-efi-sig-list"):
        ref = os.path.join(tmp, "ref.esl")
        subprocess.run(["cert-to-efi-sig-list", "-g", owner, dbpem, ref], check=True, capture_output=True)
        check("ESL: identical to efitools' cert-to-efi-sig-list", open(ref, "rb").read() == e)
    moknew, mokauth = sb.mok_request(cert, "12345678")
    check("MokNew: an ESL owned by shim's GUID", moknew == sb.esl([cert], sb.SHIM_GUID))
    want = hashlib.sha256(moknew + "12345678".encode("utf-16-le")).digest()
    check("MokAuth: SHA-256 of MokNew and the code in UCS-2 (MokManager's check)", mokauth == want and len(mokauth) == 32)
    check("MokAuth: a different code does not match",
          hashlib.sha256(moknew + "12345679".encode("utf-16-le")).digest() != mokauth)

    # --- authenticated variable writes ------------------------------------
    when = datetime.datetime(2026, 11, 21, 6, 30, 5)
    pk_esl = sb.esl([open(pkcer, "rb").read()], owner)
    payload, attrs = sb.auth_payload("PK", pk_esl, pkpem, pkkey, when=when)
    check("auth: attributes NV|BS|RT|time-based", attrs == 0x27)
    check("auth: EFI_TIME first (2026-11-21 06:30:05, rest zero)",
          payload[:16] == struct.pack("<HBBBBBBIhBB", 2026, 11, 21, 6, 30, 5, 0, 0, 0, 0, 0))
    length, rev, ctype = struct.unpack_from("<IHH", payload, 16)
    check("auth: WIN_CERTIFICATE_UEFI_GUID header", rev == 0x200 and ctype == 0xEF1
          and payload[24:40] == sb.guid_bytes(sb.CERT_PKCS7_GUID), "%#x %#x" % (rev, ctype))
    check("auth: the signature list follows the certificate", payload[16 + length:] == pk_esl)
    # wrap the bare SignedData in a ContentInfo again for openssl to verify
    sd = payload[40:16 + length]
    oid = bytes.fromhex("06092a864886f70d010702")
    def der(tag, body):
        n = len(body)
        return bytes([tag]) + (bytes([n]) if n < 0x80 else bytes([0x82, n >> 8, n & 0xFF])) + body
    p7 = der(0x30, oid + der(0xA0, sd))
    signed_data = "PK".encode("utf-16-le") + sb.guid_bytes(sb.GLOBAL_GUID) + struct.pack("<I", 0x27) + payload[:16] + pk_esl
    open(os.path.join(tmp, "p7.der"), "wb").write(p7)
    open(os.path.join(tmp, "signed.bin"), "wb").write(signed_data)
    v = subprocess.run(["openssl", "smime", "-verify", "-binary", "-inform", "DER", "-in", os.path.join(tmp, "p7.der"),
                        "-content", os.path.join(tmp, "signed.bin"), "-CAfile", pkpem, "-purpose", "any", "-out", os.devnull],
                       capture_output=True, text=True)
    check("auth: the PKCS#7 signature covers name, GUID, attributes, time and data", v.returncode == 0, v.stderr)
    if have("sign-efi-sig-list"):
        esl_path, ref = os.path.join(tmp, "pk.esl"), os.path.join(tmp, "PK.auth")
        open(esl_path, "wb").write(pk_esl)
        subprocess.run(["sign-efi-sig-list", "-t", "2026-11-21 06:30:05", "-c", pkpem, "-k", pkkey, "PK", esl_path, ref],
                       check=True, capture_output=True)
        r = open(ref, "rb").read()
        check("auth: byte for byte what efitools' sign-efi-sig-list writes", r == payload,
              "first bytes %s vs %s" % (r[:24].hex(), payload[:24].hex()))
    payload, attrs = sb.auth_payload("db", e, pkpem, pkkey, append=True, when=when)
    check("auth: appending to db sets the append flag", attrs == 0x67)

    # --- the Microsoft certificates shipped for Setup Mode ----------------
    msdir = os.path.join(HERE, "..", "files", "secureboot", "microsoft")
    names = {}
    for sub in ("KEK", "db"):
        for f in sorted(os.listdir(os.path.join(msdir, sub))):
            der = open(os.path.join(msdir, sub, f), "rb").read()
            r = subprocess.run(["openssl", "x509", "-inform", "DER", "-noout", "-subject"], input=der, capture_output=True)
            names[sub + "/" + f] = r.stdout.decode()
    check("Microsoft: 2 KEK and 5 db certificates, all readable",
          len(names) == 7 and all("Microsoft" in n or "Windows" in n for n in names.values()), str(names))
    readme = open(os.path.join(msdir, "README.md")).read()
    check("Microsoft: every file's hash is listed in the README",
          all(hashlib.sha256(open(os.path.join(msdir, k), "rb").read()).hexdigest() in readme for k in names))

    # --- FreeBSD's real loader --------------------------------------------
    real = os.environ.get("LOADER_EFI")
    if real:
        out = sb.add_section(open(real, "rb").read(), ".sbat", sbat)
        p = os.path.join(tmp, "loader.efi")
        open(p, "wb").write(out)
        check("loader.efi: .sbat added", sb.PE(out).sections()[-1][0] == ".sbat")
        if have("sbsign") and have("sbverify"):
            r = subprocess.run(["sbsign", "--key", dbkey, "--cert", dbpem, "--output", p + ".signed", p], capture_output=True, text=True)
            v = subprocess.run(["sbverify", "--cert", dbpem, p + ".signed"], capture_output=True, text=True)
            check("loader.efi: signs and verifies", r.returncode == 0 and v.returncode == 0, r.stderr + v.stderr)
finally:
    shutil.rmtree(tmp)
sys.exit(failed)
