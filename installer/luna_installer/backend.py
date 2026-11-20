"""The installer's logic, without any user interface.

Everything here is plain Python (no Qt) so that it can be tested anywhere
(tests/installer-test.py). The real work is done by install.sh; this module
reads what install.sh --probe reports, checks the answers the same way
install.sh does, writes them as an answers file, and turns install.sh's
output into progress.
"""

import os
import re
import shlex

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


# ------------------------------------------------------------- identity ---

def read_conf(path):
    """KEY="value" lines of a plain sh file (distro.conf)."""
    out = {}
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                m = re.match(r'^([A-Z_][A-Z0-9_]*)="([^"]*)"', line.strip())
                if m:
                    out[m.group(1)] = m.group(2)
    except OSError:
        pass
    return out


def read_distro(repo=REPO):
    d = {"DISTRO_NAME": "LunaBSD", "DISTRO_ID": "lunabsd", "DISTRO_VERSION": "",
         "DISTRO_CODENAME": "", "DISTRO_TAGLINE": "", "DISTRO_URL": "", "ISO_LABEL": "LUNABSD"}
    d.update(read_conf(os.path.join(repo, "distro.conf")))
    return d


def read_wizard_tables(repo=REPO):
    """Languages and keyboard layouts, from lib/wizard.sh (one list for the
    text and the graphical installer)."""
    with open(os.path.join(repo, "lib", "wizard.sh"), encoding="utf-8") as f:
        text = f.read()

    def table(name):
        m = re.search(name + r"='(.*?)'", text, re.S)
        rows = []
        for line in (m.group(1) if m else "").splitlines():
            parts = line.split("|")
            if len(parts) == 3:
                rows.append(parts)
        return rows

    langs = [{"code": c, "locale": l, "label": n} for c, l, n in table("WIZ_LANGS")]
    layouts = [{"xkb": x, "keymap": k, "label": n} for x, k, n in table("WIZ_LAYOUTS")]
    return langs, layouts


def read_timezones(path="/usr/share/zoneinfo/zone1970.tab"):
    """[{zone, region, city, comment}] sorted by region and city; UTC first."""
    zones = [{"zone": "UTC", "region": "UTC", "city": "UTC (Coordinated Universal Time)", "comment": ""}]
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                if line.startswith("#") or not line.strip():
                    continue
                cols = line.rstrip("\n").split("\t")
                if len(cols) < 3:
                    continue
                zone = cols[2]
                region, _, city = zone.partition("/")
                zones.append({"zone": zone, "region": region, "city": city.replace("_", " "),
                              "comment": cols[3] if len(cols) > 3 else ""})
    except OSError:
        pass
    zones[1:] = sorted(zones[1:], key=lambda z: (z["region"], z["city"]))
    return zones


# Time zone to preselect for a language (the user can always change it).
LANG_ZONES = {
    "vi": "Asia/Ho_Chi_Minh", "de": "Europe/Berlin", "fr": "Europe/Paris", "es": "Europe/Madrid",
    "pt-br": "America/Sao_Paulo", "pt": "Europe/Lisbon", "it": "Europe/Rome", "nl": "Europe/Amsterdam",
    "pl": "Europe/Warsaw", "cs": "Europe/Prague", "sv": "Europe/Stockholm", "tr": "Europe/Istanbul",
    "ru": "Europe/Moscow", "uk": "Europe/Kyiv", "zh-cn": "Asia/Shanghai", "zh-tw": "Asia/Taipei",
    "ja": "Asia/Tokyo", "ko": "Asia/Seoul",
}

# Keyboard layout to preselect for a language.
LANG_LAYOUTS = {
    "de": "de", "fr": "fr", "es": "es", "pt-br": "br", "pt": "pt", "it": "it", "nl": "us",
    "pl": "pl", "cs": "cz", "sv": "se", "tr": "tr", "ru": "ru", "uk": "ua", "ja": "jp",
}

# Input methods suggested for a language (same as wiz_suggest_im).
LANG_IMS = {"vi": "vi", "zh-cn": "zh-cn", "zh-tw": "zh-tw", "ja": "ja", "ko": "ko"}


# ---------------------------------------------------------------- probe ---

def _yes(v):
    return v == "yes"


def parse_probe(text):
    """The tab-separated lines of install.sh --probe -> a dict."""
    p = {"distro": {}, "hw": {}, "report": [], "disks": [], "boot": {}, "other": {},
         "bitlocker": False, "min_gb": 30, "net": None}
    for line in text.splitlines():
        f = line.split("\t")
        kind = f[0]
        if kind == "distro" and len(f) >= 3:
            p["distro"] = {"name": f[1], "version": f[2]}
        elif kind == "hw" and len(f) >= 3:
            p["hw"][f[1]] = f[2]
        elif kind == "report" and len(f) >= 3:
            p["report"].append({"status": f[1], "text": f[2]})
        elif kind == "min_gb" and len(f) >= 2 and f[1].isdigit():
            p["min_gb"] = int(f[1])
        elif kind == "bitlocker" and len(f) >= 2:
            p["bitlocker"] = _yes(f[1])
        elif kind == "net" and len(f) >= 2:
            p["net"] = _yes(f[1])
        elif kind == "disk" and len(f) >= 11:
            size = int(f[2]) if f[2].isdigit() else 0
            free = int(f[7]) if f[7].isdigit() else 0
            p["disks"].append({
                "name": f[1], "bytes": size, "gb": size // 1073741824, "descr": f[3].strip(),
                "removable": _yes(f[4]), "contents": f[5].strip(), "efi": f[6].strip(),
                "free_bytes": free, "free_gb": free // 1073741824,
                "alongside": _yes(f[8]), "why": f[9], "windows": _yes(f[10]),
            })
        elif kind == "boot" and len(f) >= 9:
            p["boot"][f[1]] = {"limine": f[2], "sdboot": _yes(f[3]), "refind": _yes(f[4]),
                               "grub": _yes(f[5]), "windows": _yes(f[6]),
                               "chain": f[7], "default": f[8]}
        elif kind == "other" and len(f) >= 4:
            p["other"][f[1]] = {"name": f[2], "chainable": _yes(f[3])}
    return p


def default_disk(disks, min_gb=0):
    """The disk to preselect: the largest built-in one, never a USB drive
    (often the backup the README asked for), as install.sh does; none that
    is too small."""
    big = [d for d in disks if d["gb"] >= min_gb]
    fixed = [d for d in big if not d["removable"]]
    pool = fixed or big
    return max(pool, key=lambda d: d["bytes"])["name"] if pool else ""


def boot_places(boot, distro_name="LunaBSD"):
    """Where the new system will be reachable from, in words (side by side)."""
    out = []
    if boot.get("limine") == "locked":
        out.append("your Limine menu, after one command in Linux (shown at the end)")
    elif boot.get("limine") == "yes":
        out.append("an entry in your Limine menu")
    if boot.get("sdboot"):
        out.append("an entry in your systemd-boot menu")
    if boot.get("refind"):
        out.append("rEFInd finds it by itself")
    if boot.get("grub"):
        out.append("your GRUB menu, after a few commands in Linux (shown at the end)")
    out.append("'FreeBSD' in the firmware boot menu (F12, F11, F8 or Esc right after power-on)")
    if boot.get("chain"):
        out.append("%s's own boot menu: 'Start %s' (key L)" % (distro_name, boot["chain"]))
    return out


# ----------------------------------------------------------- validation ---
# The same rules as install.sh (valid_user, valid_hostname, valid_fullname).

# FreeBSD's own accounts, for when /etc/passwd cannot be read (tests).
SYSTEM_USERS = {
    "root", "toor", "daemon", "operator", "bin", "tty", "kmem", "games", "news", "man", "sshd",
    "smmsp", "mailnull", "bind", "unbound", "proxy", "_pflogd", "_dhcp", "uucp", "pop", "auditdistd",
    "www", "ntpd", "_ypldap", "hast", "tests", "nobody",
}


def system_users(passwd="/etc/passwd"):
    """Accounts the system uses itself (uid below 1000 or 65530 and up), as
    install.sh's valid_user reads them."""
    names = set()
    try:
        with open(passwd, encoding="utf-8", errors="replace") as f:
            for line in f:
                p = line.split(":")
                if len(p) > 2 and p[2].isdigit() and (int(p[2]) < 1000 or int(p[2]) >= 65530):
                    names.add(p[0])
    except OSError:
        return set(SYSTEM_USERS)
    return names or set(SYSTEM_USERS)


def check_fullname(name):
    if not name.strip():
        return "Type your name."
    if any(c in name for c in ':"\\') or any(ord(c) < 32 or ord(c) == 127 for c in name):
        return "The name must not contain a colon (:), a double quote or a backslash."
    return ""


def check_username(name, reserved=None):
    if not name:
        return "Choose a login name."
    if not re.fullmatch(r"[a-z_][a-z0-9_-]{0,15}", name):
        return "Use lower-case letters, digits, - or _, starting with a letter (at most 16 characters)."
    if name in (SYSTEM_USERS if reserved is None else reserved):
        return "'%s' is a name the system uses itself; choose another one." % name
    return ""


def check_hostname(name):
    if not re.fullmatch(r"[A-Za-z0-9]([A-Za-z0-9.-]{0,62}[A-Za-z0-9])?", name or ""):
        return "Use letters, digits, dots and dashes, starting and ending with a letter or digit."
    return ""


def check_password(p1, p2, what="password"):
    if not p1:
        return "Choose a %s." % what
    if p1 != p2:
        return "The two %ss are not the same." % what
    return ""


def password_strength(p):
    """0 (weak) .. 3 (strong): a hint, never a rule."""
    if not p:
        return 0
    score = 0
    if len(p) >= 8:
        score += 1
    if len(p) >= 12:
        score += 1
    kinds = sum(bool(re.search(r, p)) for r in (r"[a-z]", r"[A-Z]", r"[0-9]", r"[^A-Za-z0-9]"))
    if kinds >= 3:
        score += 1
    return min(score, 3)


def suggest_username(fullname):
    first = (fullname.strip().split() or [""])[0].lower()
    first = re.sub(r"[^a-z0-9_-]", "", first)
    if first and not re.match(r"[a-z_]", first):
        first = "u" + first
    return first[:16]


def is_ascii_printable(s):
    return all(32 <= ord(c) < 127 for c in s)


# --------------------------------------------------------------- answers ---

def sh(value):
    """A value as a single-quoted sh word."""
    return shlex.quote(str(value)) if value != "" else "''"


ANSWER_KEYS = [
    "INSTALL_DISK", "INSTALL_MODE", "ZFS_SIZE_GB", "SWAP_SIZE",
    "USER_FULLNAME", "USERNAME", "USER_PASSWORD", "ROOT_PASSWORD", "HOSTNAME_NEW",
    "ENCRYPT", "ENCRYPT_PASSPHRASE", "TIMEZONE", "RTC_LOCAL", "BOOT_DEFAULT",
    "WIZ_LANG", "KEYBOARD_LAYOUT", "DESKTOP", "INPUT_METHODS", "TERMINAL_STYLE",
    "INSTALL_APPS", "INSTALL_PRINTING", "INSTALL_GAMING", "INSTALL_DEVTOOLS",
    "FIREWALL", "AUTO_SNAPSHOTS", "PKG_BRANCH",
]


def build_answers(a):
    """The answers (a dict from the user interface) as the answers file
    install.sh --config reads. Raises ValueError for answers install.sh
    would refuse, so the installer can say what is wrong before starting."""
    def yn(v):
        return "yes" if v in (True, "yes") else "no"

    disk = a.get("disk", "")
    mode = a.get("mode", "")
    if not disk:
        raise ValueError("No disk was chosen.")
    if mode not in ("erase", "alongside"):
        raise ValueError("Choose whether to erase the disk or install next to the other systems.")
    for check, value in ((check_fullname, a.get("fullname", "")),
                         (check_username, a.get("username", "")),
                         (check_hostname, a.get("hostname", ""))):
        msg = check(value)
        if msg:
            raise ValueError(msg)
    if not a.get("password"):
        raise ValueError("Choose a password.")
    if a.get("encrypt") and not a.get("passphrase"):
        raise ValueError("Choose a passphrase for the disk encryption.")
    desktop = a.get("desktop", "kde")
    if desktop not in ("kde", "hyprland", "both", "none"):
        raise ValueError("Unknown desktop '%s'." % desktop)
    term = a.get("terminal", "fish")
    if term not in ("fish", "zsh", "bash", "none"):
        raise ValueError("Unknown terminal style '%s'." % term)
    ims = [i for i in a.get("input_methods", []) if i in ("vi", "zh-cn", "zh-tw", "ja", "ko", "m17n")]
    branch = a.get("pkg_branch", "latest")
    if branch not in ("latest", "quarterly"):
        raise ValueError("Unknown package branch '%s'." % branch)
    if desktop in ("hyprland", "both"):
        branch = "latest"          # Hyprland and Caelestia need it

    values = {
        "INSTALL_DISK": disk,
        "INSTALL_MODE": mode,
        "ZFS_SIZE_GB": str(int(a["size_gb"])) if mode == "alongside" and a.get("size_gb") else "",
        "SWAP_SIZE": "auto",
        "USER_FULLNAME": a.get("fullname", ""),
        "USERNAME": a["username"],
        "USER_PASSWORD": a["password"],
        "ROOT_PASSWORD": a.get("root_password") or a["password"],
        "HOSTNAME_NEW": a["hostname"],
        "ENCRYPT": yn(a.get("encrypt")),
        "ENCRYPT_PASSPHRASE": a.get("passphrase", "") if a.get("encrypt") else "",
        "TIMEZONE": a.get("timezone", "UTC"),
        "RTC_LOCAL": "auto",
        "BOOT_DEFAULT": "freebsd" if a.get("boot_first") else "keep",
        "WIZ_LANG": a.get("language", "en"),
        "KEYBOARD_LAYOUT": a.get("layout", "us"),
        "DESKTOP": desktop,
        # "none" (not empty): empty would let install.sh suggest some again
        "INPUT_METHODS": " ".join(ims) if ims else "none",
        "TERMINAL_STYLE": term,
        "INSTALL_APPS": yn(a.get("apps", True)),
        "INSTALL_PRINTING": yn(a.get("printing", True)),
        "INSTALL_GAMING": yn(a.get("gaming", False)),
        "INSTALL_DEVTOOLS": yn(a.get("dev", False)),
        "FIREWALL": yn(a.get("firewall", True)),
        "AUTO_SNAPSHOTS": yn(a.get("snapshots", True)),
        "PKG_BRANCH": branch,
    }
    lines = ["# Answers for install.sh, written by the LunaBSD graphical installer."]
    lines += ["%s=%s" % (k, sh(values[k])) for k in ANSWER_KEYS]
    return "\n".join(lines) + "\n"


def result_details(text, distro_name):
    """install.sh's final message without the lines the installer already
    shows as its heading."""
    drop = {"%s is installed." % distro_name, "Remove the USB stick and restart the computer."}
    lines = [l for l in text.splitlines() if l.strip() not in drop]
    while lines and not lines[0].strip():
        lines.pop(0)
    return "\n".join(lines).rstrip()


# -------------------------------------------------------------- progress ---

# What install.sh and setup.sh print as "==== title ====", with the share of
# the whole installation where each part starts, and friendlier words.
INSTALL_STEPS = [
    ("Partitioning", 0.01, "Preparing the disk"),
    ("Encrypting", 0.02, "Encrypting the disk"),
    ("Creating the ZFS pool", 0.03, "Preparing the disk"),
    ("Downloading and installing FreeBSD", 0.04, "Downloading and installing the base system"),
    ("Configuring the new system", 0.20, "Configuring the new system"),
    ("Creating the user account", 0.21, "Creating your account"),
    ("Making it bootable", 0.22, "Making it start"),
    ("Copying", 0.23, "Copying the setup tools"),
    ("Installing the desktop", 0.24, "Installing the desktop"),
    ("Finishing", 0.98, "Finishing"),
]

# setup.sh's stages (in order) and what to call them.
STAGES = [
    ("base", "Setting up packages and updates"), ("drivers", "Installing drivers for your hardware"),
    ("system", "Configuring services and power saving"), ("network", "Setting up the network"),
    ("zfs", "Setting up snapshots"), ("audio", "Setting up sound"),
    ("desktop", "Installing fonts and the login screen"), ("kde", "Installing KDE Plasma (the longest part)"),
    ("hyprland", "Installing Hyprland"), ("caelestia", "Building the Caelestia shell"),
    ("branding", "Applying the LunaBSD look"), ("terminal", "Setting up the terminal"),
    ("input", "Setting up input methods"), ("printing", "Setting up printing"),
    ("apps", "Installing apps"), ("gaming", "Installing gaming tools"),
    ("security", "Setting up the firewall"), ("finish", "Finishing the desktop"),
]
DESKTOP_START, DESKTOP_END = 0.24, 0.97


class Progress:
    """Feed install.sh output line by line; read .fraction and .title."""

    def __init__(self):
        self.fraction = 0.0
        self.title = "Starting"
        self.detail = ""
        self._stage = None
        self._span = (0.0, 0.0)
        self._base_part = 0

    def _set(self, value):
        self.fraction = max(self.fraction, min(value, 1.0))

    def feed(self, line):
        line = line.rstrip("\n")
        m = re.match(r"^\s*==== (.*) ====\s*$", line)
        if m:
            head = m.group(1)
            names = [s for s, _ in STAGES]
            if head in names:
                i = names.index(head)
                width = (DESKTOP_END - DESKTOP_START) / len(STAGES)
                start = DESKTOP_START + i * width
                self._stage, self._span = head, (start, start + width)
                self.title = STAGES[i][1]
                self.detail = ""
                self._set(start)
                return
            for key, frac, words in INSTALL_STEPS:
                if head.startswith(key):
                    self._stage, self._span = None, (frac, frac)
                    self.title, self.detail = words, ""
                    self._set(frac)
                    return
            return
        # pkg: "[12/345] Installing foo-1.0..." -> progress inside a stage
        m = re.match(r"^\s*\[(\d+)/(\d+)\] (Fetching|Installing|Upgrading|Extracting) (\S+)", line)
        if m and self._stage:
            n, total = int(m.group(1)), int(m.group(2))
            a, b = self._span
            # fetching is the first half of a pkg run, installing the second
            part = n / max(total, 1) / 2
            if m.group(3) != "Fetching":
                part += 0.5
            self._set(a + (b - a) * part)
            self.detail = "%s %s" % (m.group(3), re.sub(r"\.\.\.$", "", m.group(4)))
            return
        m = re.match(r"^\s*-> (downloading|unpacking) (base|kernel|lib32)\.txz", line)
        if m:
            parts = ["base", "kernel", "lib32"]
            k = parts.index(m.group(2)) * 2 + (1 if m.group(1) == "unpacking" else 0)
            self._set(0.04 + 0.14 * (k + 1) / 6)
            self.detail = "%s %s" % (m.group(1).capitalize(), m.group(2))
            return
        if "applying security patches" in line:
            self._set(0.185)
            self.detail = "Applying security patches"
            return
        m = re.match(r"^\s*-> (.*)$", line)
        if m:
            self.detail = m.group(1)[:120]
