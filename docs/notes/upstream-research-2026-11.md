# Upstream research: power profiles, network, Bluetooth, sleep, KDE sensors

Read from source on 2026-11-16 (nothing here was run on FreeBSD).
"VERIFIED" = read in the source at the cited tag; "INFERRED" = conclusion
not yet tested. Versions: power-profiles-daemon 0.30, Plasma 6.8.3, KF6 6.31,
Quickshell 0.3.2 (FreeBSD port), Caelestia shell v2.5.0, networkmgr 6.9,
freebsd-ports 6b24a18. Recheck when any of these versions change.

## Power profiles
## Power profiles: what KDE Plasma 6.8 and Caelestia need from a D-Bus shim

I shallow-cloned each source at the tags below, under (local scratch clones)/. I did not modify the repo.

| Source | Tag | Commit |
|---|---|---|
| power-profiles-daemon (ppd) | 0.30 | 5b4994c |
| powerdevil | v6.8.3 | 3070bf5 |
| quickshell | v0.3.2 | 4f508be |
| caelestia shell | v2.5.0 | d999d48 |
| freebsd-ports | HEAD | 6b24a18, 2026-11-16 (a clone that already existed in the scratchpad; I only read it) |

V means I read it in the source. I means inferred.

### 1. The upstream ppd interface (gitlab.freedesktop.org/upower/power-profiles-daemon, tag 0.30)

**Names (V, meson.build:73-74, src/power-profiles-daemon.c:29-36)**
- New: bus name and interface `org.freedesktop.UPower.PowerProfiles`, object path `/org/freedesktop/UPower/PowerProfiles`.
- Legacy: bus name and interface `net.hadess.PowerProfiles`, object path `/net/hadess/PowerProfiles`.
- One process owns both names (c:1152-1175) and sends PropertiesChanged on both paths (c:420-433).

**Interface (V, src/org.freedesktop.UPower.PowerProfiles.xml.in)**
- Methods:
  - `HoldProfile(in s profile, in s reason, in s application_id, out u cookie)` (line 45). Only `power-saver` or `performance` can be held; if both are held, power-saver wins.
  - `ReleaseProfile(in u cookie)` (line 57).
  - `SetActionEnabled(in s action, in b enabled)` (line 68).
- Signal: `ProfileReleased(u cookie)` (line 80). It goes only to the process that held the profile.
- Properties:

| Property | Type | Access | Line |
|---|---|---|---|
| ActiveProfile | s | readwrite | 90 |
| PerformanceInhibited | s | read; deprecated, unused since 0.9 | 97 |
| PerformanceDegraded | s | read | 110 |
| Profiles | aa{sv} | read | 130 |
| Actions | as | read | 139 |
| ActionsInfo | aa{sv} | read | 150 |
| ActiveProfileHolds | aa{sv} | read | 160 |
| Version | s | read | 167 |
| BatteryAware | b | readwrite | 175 |

- The legacy `net.hadess` interface has no `SetActionEnabled`, `ActionsInfo` or `BatteryAware` (V, diff of the two XMLs; c:1069-1075 rejects SetActionEnabled on it).

**Contents of the dictionaries (V)**
- `Profiles` entries (c:240-277):
  - `Profile` (s) is `power-saver`, `balanced` or `performance`, sorted in that order.
  - Optional `CpuDriver` (s) and `PlatformDriver` (s).
  - `Driver` (s) is kept for older clients: it is `"multiple"` when both drivers apply, otherwise the one driver's name. ppd's fallback driver is named `placeholder` (ppd-driver-placeholder.c:32).
- `PerformanceDegraded` is `""`, `lap-detected` or `high-operating-temperature`. The XML tells clients to tolerate other values.
- `ActiveProfileHolds` entries have the keys `ApplicationId`, `Profile` and `Reason` (c:344-348).
- `ActionsInfo` entries have the keys `Action`, `Description` (s) and `Enabled` (b) (c:318-320).

**D-Bus policy (V, data/power-profiles-daemon.dbus.conf.in)**
- Only root may own the name.
- Anyone may send to the main interface, `Introspectable`, `Properties` and `Peer`.

**Polkit (V, data/power-profiles-daemon.policy)**
- Actions: `org.freedesktop.UPower.PowerProfiles.switch-profile`, `.hold-profile`, `.configure-action` and `.configure-battery-aware`.
- All four use `allow_any=no`, `allow_inactive=no`, `allow_active=yes`.
- The check (c:906-930) calls `polkit_authority_check_authorization_sync` on the caller's bus name with flags NONE, so no password prompt is ever shown.
- Where each action is checked:
  - Setting `ActiveProfile` checks switch-profile (c:991).
  - Setting `BatteryAware` checks configure-battery-aware (c:1001).
  - `HoldProfile` checks hold-profile (c:1061).
  - `SetActionEnabled` checks configure-action (c:1081).
  - `ReleaseProfile` has no check (c:1067).

**Activation file (V, data/power-profiles-daemon.dbus.service.in)**
- `Exec=/bin/false`, `User=root`, `SystemdService=...`. Upstream relies on systemd to start the daemon.
- FreeBSD's dbus package ships `libexec/dbus-daemon-launch-helper` (V, ports devel/dbus/pkg-plist). So a `system-services/*.service` file with a real `Exec=` could start our shim on demand (I).

### 2. KDE PowerDevil 6.8.3 (invent.kde.org/plasma/powerdevil)

**The daemon action, daemon/actions/bundled/powerprofile.cpp (V)**
- It uses only `org.freedesktop.UPower.PowerProfiles` and `/org/freedesktop/UPower/PowerProfiles` on the system bus (lines 32-33). It never uses `net.hadess`.
- It reads all properties with `Properties.GetAll` (line 55) and listens to PropertiesChanged (lines 44, 274).
- It reads `ActiveProfile`, `Profiles`, `PerformanceInhibited`, `PerformanceDegraded` and `ActiveProfileHolds` (lines 27-30, 225-270).
- It switches profile with `Properties.Set ActiveProfile` (line 141). It also calls `HoldProfile`, `ReleaseProfile` and listens for `ProfileReleased` (lines 45, 177, 197).
- **Profile list:** the list stays empty when `profiles.first()["Driver"] == "placeholder"` (lines 237-242); otherwise it uses each entry's `Profile`.
  - A missing `Driver` key passes.
  - So the shim must never report `Driver=placeholder`. `Profile` is the only key it really needs.
- **When the action is loaded:**
  - `isSupported()` (lines 103-106) is true if the name is activatable or currently registered.
  - `Core::refreshActions()` is called only at startup (powerdevilcore.cpp:177) and when the screen brightness controller's display list changes (:95).
  - Nothing re-checks when the ppd name appears later.
  - So the shim must be running, or activatable, before PowerDevil starts in the session. Otherwise the power profile action is never loaded. Starting it from rc.d at boot is the safe choice (I, from the code above).
- The action re-exports the profile state on the session bus as `org.kde.Solid.PowerManagement.Actions.PowerProfile` at `/org/kde/Solid/PowerManagement/Actions/PowerProfile`. Methods include `profileChoices`, `currentProfile` and `setProfile`, with matching `*Changed` signals (org.kde.Solid.PowerManagement.Actions.PowerProfile.xml).

**The battery applet, applets/batterymonitor (V)**
- It sets `isPowerProfileDaemonInstalled` only when both of these are registered (plugin/powerprofilescontrol.cpp:65-67, 220):
  - the system-bus name `org.freedesktop.UPower.PowerProfiles`;
  - the session-bus name `org.kde.Solid.PowerManagement`.
- The check is "registered", not "activatable", so the shim must actually be running.
- If an executable named `tlp` is on PATH, the applet says "The TLP service automatically controls power profiles" instead of offering the slider (cpp:52, PowerProfileItem.qml:304). Nothing this project installs may be named `tlp`.
- The slider is shown when `profiles.length > 0` (PopupDialog.qml:100, PowerProfileItem.qml:117).
- The slider is fixed at three stops, 0 to 2, mapped to power-saver, balanced and performance (PowerProfileItem.qml:38-55, 115-125). A profile list without `performance` would still show a Performance stop (I).
- Degradation text exists for `lap-detected` and `high-operating-temperature`, with a generic text for anything else (lines 242-255).
- plasma-workspace v6.8.3 has no power profile client code (V, grep).

### 3. FreeBSD port sysutils/plasma6-powerdevil (ports HEAD 6b24a18)

All V:
- The Makefile has no OPTIONS and there is no `files/` directory, so there are no patches.
- Dependencies: `libudev-devd` and `RUN_DEPENDS` on upower.
- pkg-plist ships `powerdevil/action/powerdevil_powerprofileaction.so`, the batterymonitor QML plugin and `kcm_powerdevilprofilesconfig.so`, so power profiles are compiled in.
- `lib/systemd/user/plasma-powerprofile-osd.service` is commented out in pkg-plist. The applet's on-screen message goes through plasmashell's `org.kde.osdService.powerProfileChanged` instead (powerprofilescontrol.cpp:368-378), so it should still work (I).
- DDCUtil is an optional `find_package` (CMakeLists.txt:69-76) and the port does not depend on it. Nothing Linux-only blocks power profiles.
- No power-profiles-daemon or tlp port exists in the tree (V, path and Makefile grep).
- `KDE_PLASMA6_VERSION=6.8.3` on HEAD (Mk/Uses/kde.mk:124). I did not check which version the quarterly branch carries.

### 4. Quickshell, PowerProfiles singleton (src/services/upower/powerprofiles.cpp, tag v0.3.2)

**Which service and what it reads (V)**
- It uses only `org.freedesktop.UPower.PowerProfiles` and `/org/freedesktop/UPower/PowerProfiles` on the system bus (lines 74-80).
- It binds `ActiveProfile`, `Profiles`, `PerformanceDegraded` and `ActiveProfileHolds`, all marked required (hpp:150-153; the 5-argument macro means required=true, dbus/properties.hpp:326). A missing one only causes a warning (properties.cpp:207-212).

**Startup (V)**
- If the service is not there, it calls `StartServiceByName` once (lines 82-97, dbus/bus.cpp). If that fails, it never retries.
- So the shim must be running before the shell starts, or be bus-activatable (I).

**Strict value parsing (V)**
- Any `Profile` value other than `power-saver`, `balanced` or `performance` is an error, and the whole property update is dropped (lines 155-185).
- Any `PerformanceDegraded` value other than `""`, `lap-detected` or `high-operating-temperature` is an error (lines 191-202).
- The shim must send only these exact strings.

**Profile list and switching (V)**
- `hasPerformanceProfile` is true when `Profiles` contains an entry with `Profile=performance` (line 61). Quickshell ignores `Driver`.
- `setProfile` refuses Performance when that entry is missing. Otherwise it writes `ActiveProfile` through `Properties.Set` (lines 106-125).

**FreeBSD package**
- The port is x11/quickshell, not x11-toolkits. The Makefile has `DISTVERSION=0.3.2` and `GIT_COMMIT_HASH=4f508be`, which is the v0.3.2 tag commit (V).
- The UPower module is always built: `SERVICE_UPOWER` defaults to ON and pkg-plist ships `Quickshell/Services/UPower` (V).
- I did not check freshports or pkg.freebsd.org, so the version in the built `latest` package is only inferred to be 0.3.2 (I).

### 5. Caelestia shell v2.5.0 (github.com/caelestia-dots/shell)

The repo's caelestia/build.sh builds the latest tag (V).

- `modules/bar/popouts/Battery.qml`:
  - Three profile buttons, PowerSaver, Balanced and Performance (lines 203, 212, 223). Clicking sets `PowerProfiles.profile` (line 248).
  - It never checks `hasPerformanceProfile` (V, grep).
  - It shows the current profile when there is no laptop battery (line 64).
  - A degradation banner is active when `degradationReason !== None` (line 85).
- `modules/bar/components/status/BatteryStatus.qml:13-15`: on machines without a battery, the bar icon shows the active profile.

### What this means for the shim (I)

1. Run as root from rc.d at boot. Optionally also add a system-services activation file with a real `Exec=`. **Tested in the VM (2026-11-16): do not.** PowerDevil treats an activatable name as supported, and dbus-daemon waits 25 s when an activated service exits with status 0, so machines with no CPU setting would get a broken switch and a stall.
2. Own `org.freedesktop.UPower.PowerProfiles`. `net.hadess.PowerProfiles` is optional, since no current consumer uses it.
3. Always offer all three profiles: both UIs assume three. Send `Driver` set to anything except `placeholder`.
4. Implement:
   - Properties.Get, GetAll and Set;
   - PropertiesChanged on `ActiveProfile`;
   - `PerformanceInhibited=""`, `PerformanceDegraded=""` and `ActiveProfileHolds=[]`;
   - `HoldProfile`, `ReleaseProfile` and `ProfileReleased`.
5. Polkit `allow_active` relies on polkit seeing the caller in an active session. On FreeBSD that session tracking is ConsoleKit2, so this is the likeliest thing to fail on real hardware.


## Network
Networking research for Caelestia, KDE and networkmgr. All sources were read on 2026-11-16. Clones are in (local scratch clones)/. The repo was not modified.

Sources:
- Caelestia shell v2.5.0 = d999d48. Main = e72df8e (2026-11-15).
- Quickshell v0.3.2 = 4f508be.
- freebsd-ports @ 6b24a18.
- networkmgr 6.9 = f97cbc4.
- plasma-workspace v6.8.3.
- Package catalog: pkg.freebsd.org/FreeBSD:15:amd64/latest/packagesite.pkg, which lists quickshell 0.3.2, networkmanager-shim 1.52.0_1, networkmgr 6.9, wifimgr 1.26, kf6-networkmanager-qt 6.31.0 and plasma6-plasma-workspace 6.8.3. VERIFIED.

## Main findings

**A. Likely cause of "networkmgr gave nothing in Plasma".** INFERRED: each piece below was verified, but the combination was not run.
- The networkmgr package installs `etc/sudoers.d/networkmgr` containing `%wheel ALL=(ALL) NOPASSWD: /usr/local/bin/networkmgr` (networkmgr src/sudoers.d/networkmgr; setup.py:95).
- Our `stages/base.sh:60` writes `/usr/local/etc/sudoers.d/wheel` containing `%wheel ALL=(ALL:ALL) ALL`.
- sudoers(5) (https://www.sudo.ws/docs/man/sudoers.man/) says included files "are parsed in sorted lexical order" and "the last match is used". VERIFIED.
- So `wheel` is read after `networkmgr` and its password rule overrides NOPASSWD.
- The autostart line `Exec=sudo networkmgr` has no tty, so it would fail silently.

**B. networkmanager-shim is a build-time stub.**
- Port Makefile (net-mgmt/networkmanager-shim/Makefile `do-build`) builds `libnm.so.0` from `nm-enum-types.c` only. Meson options include `-Dnmcli=false` and `-Dpolkit=false`. VERIFIED.
- pkg-plist contains only `include/libnm/*.h`, `lib/libnm.so`, `lib/libnm.so.0` and `libdata/pkgconfig/libnm.pc`. There is no daemon, no rc script, no D-Bus config and no nmcli. VERIFIED.
- kf6-networkmanager-qt has `LIB_DEPENDS=libnm.so:net-mgmt/networkmanager-shim` and `USE_QT=base declarative`. VERIFIED.
- The only libnm consumers in the catalog are kf6-networkmanager-qt and lightdm-kde-greeter. VERIFIED.
- So NetworkManagerQt can only link enum symbols and must talk plain D-Bus. A daemon that implements `org.freedesktop.NetworkManager` would satisfy it. INFERRED.
- `plasma6-plasma-nm` is absent from the ports tree: no directory and no MOVED entry. Mk/Uses/kde.mk lists no plasma-nm (KDE_PLASMA6_VERSION 6.8.3, line 124). VERIFIED.

**C. Caelestia uses nmcli, not Quickshell.Networking.**
- `Quickshell.Networking` appears nowhere at v2.5.0 or at main e72df8e. `git log -S'Quickshell.Networking' --all` returns nothing. VERIFIED.
- Every call goes through `services/Nmcli.qml`, which the bar, nexus and utilities modules use. The cheap path is therefore an `nmcli` look-alike.

**D. Linux-only paths fail silently on FreeBSD.** VERIFIED. This conflicts with the rule "a control that cannot work must not be shown broken".
- Nmcli.qml:273 runs `sh -c 'test -d /sys/class/net || exit 1; …/sys/class/net/$i/device…'`. On failure it keeps the unfiltered ethernet list (L261-263).
- Ethernet speed comes from `cat /sys/class/net/IF/speed` (L1294) and data usage from `…/statistics/rx_bytes tx_bytes` (L1306). Both come out empty.
- VPN.qml:71 defaults the status command to `["ip","link","show"]`. VPN.qml:233 reads `/sys/class/net/IF/statistics` and VPN.qml:238 runs `ping -c1 -W2 -I IF 1.1.1.1`. VPN.qml:610 also runs `nmcli monitor`.

## 1. nmcli calls in Caelestia v2.5.0

Source: https://github.com/caelestia-dots/shell/blob/v2.5.0/services/Nmcli.qml. All entries VERIFIED.

How commands run:
- Commands are built as `["nmcli", ...args]` (L192).
- They run with environment `LANG=C.UTF-8, LC_ALL=C.UTF-8` (L1742-1745, L1706-1708).

Device and status:
- `-t -f DEVICE,TYPE,STATE,CONNECTION device status` (L210, 217, 226, 372). Lines are split on `:` without unescaping (L146). Types used: `wifi` and `ethernet`.
- Connected means `state.startsWith("connected")` (L178). Connecting means a `connecting` prefix (L182). Ethernet with no cable means `unavailable` (L41).
- `device status`, non-terse, split on whitespace with column 3 as the state (L380-385).
- `-g ACTIVE,SIGNAL,FREQ,SSID,BSSID,SECURITY d w`, i.e. `device wifi` list (L969).
  - Parsed by L81-100: `\:` is replaced, the line is split on `:`, then the fields are restored in order.
  - Fields: ACTIVE `yes`/no; SIGNAL int; FREQ via parseInt, so `2437 MHz` works; SSID; BSSID (needs `\:` escapes); SECURITY.
  - An empty SECURITY means open (`isSecure = security.length > 0`, L1814). Duplicate SSIDs are merged (L105).
- `-t -f SSID,SIGNAL,SECURITY device wifi list [ifname IF]` (L1015). Split on `:` without unescaping.
- `dev wifi list --rescan yes` (L1697). Its output is ignored and `getNetworks()` runs afterwards.
- `device wifi rescan [ifname IF]` (L914).

Radio:
- `radio wifi` must print exactly `enabled` (L951-953).
- `radio wifi on|off` (L931).

Connecting:
- `device wifi connect SSID [password PW]` (L455-458, fallback L494). It is retried twice (L466).
- With a password and BSSID: `connection show SSID`, then `connection delete SSID` (L506-508), then `connection add type wifi con-name SSID ifname * ssid SSID 802-11-wireless.bssid BSSID 802-11-wireless-security.key-mgmt wpa-psk 802-11-wireless-security.psk PW` (L480), then `connection up SSID` (L522).
- An exit code of 1-9 from `connection add` is treated as a duplicate (L489).
- Hidden networks use the same `connection add` plus `802-11-wireless.hidden yes|no` (L698, L701).
- Password needed is detected from stderr substrings such as "Secrets were required" and "No secrets provided" (L78).

Saved connections:
- `-t -f NAME,TYPE connection show` (L529). The Wi-Fi type is `802-11-wireless`.
- Then per connection `-t -f 802-11-wireless.ssid,802-11-wireless-security.key-mgmt connection show NAME` (L583). The output is parsed as `key:value` lines.
- `-t -f connection.autoconnect connection show NAME` (L729).
- `connection modify NAME connection.autoconnect yes|no`, optionally with `802-11-wireless-security.psk-flags 0|2` and `psk ""` (L755-771).
- `connection delete NAME` (L796).

Disconnect and ethernet:
- `connection up|down NAME` (L309, 359, 823, 1274).
- `device connect|disconnect IF` (L324, 809, 879, 897).
- `device disconnect wifi` (L814, 829).
- `device show IF`, non-terse (L838, 1153, 1324). Each line is split at the first `:`. Keys used: `IP4.ADDRESS*` (`a.b.c.d/NN`), `IP4.GATEWAY`, `IP4.DNS*` and `GENERAL.HWADDR`. `--` means empty (L1341-1382).
- `-t -f ipv4.method,ipv4.addresses,ipv4.gateway,ipv4.dns,ipv4.ignore-auto-dns,connection.autoconnect connection show NAME` (L1177).
- `connection modify NAME ipv4.method manual|auto ipv4.addresses … ipv4.gateway … ipv4.dns "a b" ipv4.ignore-auto-dns yes|no`, then `connection up` (L1243-1274).

Events:
- `nmcli monitor` runs permanently (L1701-1714). Every line triggers a full refresh. It is restarted 2 s after exit (L1716-1721).
- A shim that prints one line and exits therefore gives 2 s polling. INFERRED.

Other tools: nmcli does not use `iw`, `iwctl` or `wpa_cli`.

## 2. Quickshell's Networking module

- The FreeBSD Quickshell 0.3.2 package ships it. Port pkg-plist lines 24-25 list `Quickshell/Networking/qmldir` and `quickshell-network.qmltypes`. The CMake option `NETWORK` is ON by default (CMakeLists.txt:83) and the port does not turn it off. VERIFIED.
- Its only backend is the NetworkManager D-Bus service (src/network/module.md: "the only backend available is the NetworkManager DBus interface"). VERIFIED.
- It watches `org.freedesktop.NetworkManager` at `/org/freedesktop/NetworkManager` (src/network/nm/backend.cpp:54-59). VERIFIED.
- The D-Bus interfaces it uses, measured from its XML files in src/network/nm/:
  - `org.freedesktop.NetworkManager`
  - `.Device`, `.Device.Wireless`, `.Device.Wired`
  - `.AccessPoint`
  - `.Connection.Active`
  - `.Settings.Connection`
- Caelestia v2.5.0 does not use this module (see C).

## 3. networkmgr 6.9

Tray icon:
- networkmgr uses GTK3 `Gtk.StatusIcon`, which is XEmbed (NetworkMgr/trayicon.py:4, 60-63). It has no AppIndicator or StatusNotifierItem support. VERIFIED.

Autostart:
- The file `/usr/local/etc/xdg/autostart/networkmgr.desktop` contains `Exec=sudo networkmgr`, `NoDisplay=true` and `X-KDE-autostart-after=panel`. It has no OnlyShowIn. VERIFIED.

Privileges:
- The whole GUI runs as root through sudo, using the NOPASSWD rule for wheel (see A). VERIFIED.
- devd hooks in `etc/devd/networkmgr.conf` run setup-nic.py, link-up.py and auto-switch.py. VERIFIED.

Files and commands it touches (VERIFIED):
- `/etc/wpa_supplicant.conf`: appended (trayicon.py:497, 509), entries deleted (net_api.py:430-440), mode 0600.
- `/etc/rc.conf` through `sysrc wlans_NIC=wlanN`, `ifconfig_wlanN=WPA DHCP` and `ifconfig_NIC=DHCP` (setup-nic.py:54-60).
- `/etc/resolv.conf` (configuration.py:494).
- Connecting runs `killall wpa_supplicant; ifconfig IF ssid …; wpa_supplicant -B -i IF -c /etc/wpa_supplicant.conf` (net_api.py:403-413).
- Wi-Fi off/on is `ifconfig IF down/up` (net_api.py:394-400).
- Other commands: `service netif|dhclient|routing restart`.

Will it show in Plasma 6 Wayland?
- sudo's default env_keep list keeps `DISPLAY` and `XAUTHORITY` but not `WAYLAND_DISPLAY` or `XDG_RUNTIME_DIR` (sudo plugins/sudoers/env.c `initial_keepenv_table`, main branch). VERIFIED.
- So GTK most likely uses X11 on Xwayland. INFERRED.
- Plasma ships `xembedsniproxy` (pkg-plist lines 21 and 25, autostart desktop file). That file has `OnlyShowIn=KDE;` and `X-KDE-autostart-phase=0`. Its main.cpp:44-52 forces `QT_QPA_PLATFORM=xcb`, so it works through Xwayland. VERIFIED.
- So the icon should appear once sudo works (fix A). INFERRED; must be tested in the VM.

Will it show in Hyprland/Caelestia?
- Caelestia's tray is Quickshell `SystemTray` (modules/bar/components/Tray.qml:5), which is StatusNotifierItem only. VERIFIED.
- xembedsniproxy is limited to KDE by `OnlyShowIn=KDE`. VERIFIED.
- `stages/network.sh:18-20` installs networkmgr only when `WANT_KDE=yes`. VERIFIED.
- The repo has no `exec-once` or XDG-autostart handling. VERIFIED by grep.
- Hyprland does not run XDG autostart on its own. INFERRED.
- Conclusion: networkmgr cannot appear there today. Running it plus `xembedsniproxy` from `exec-once` is an untested option. INFERRED.

## 4. Ports summary

All VERIFIED unless marked.
- `net-mgmt/networkmanager-shim` exists and runs nothing (see B).
- `plasma6-plasma-nm` is absent (see B).
- `kf6-networkmanager-qt` depends on networkmanager-shim, Qt base and Qt declarative, and is built with `-DKF_IGNORE_PLATFORM_CHECK=true`.
- The `latest` package catalog has no `nmcli` binary in any package. INFERRED from the shim's `-Dnmcli=false` and the absence of a net/networkmanager port.

## 5. wifimgr 1.26

All VERIFIED. Tarball sha256 matches distinfo.
- Toolkit: GTK3, or GTK2 with the port option. It uses X11 (`USE_XORG=x11`).
- It has no tray icon: no StatusIcon, AppIndicator or tray code in src/.
- It edits `/etc/wpa_supplicant.conf` (wifimgr.h:38) and reads `/etc/rc.conf` (wifimgr.h:39).
- Privileges: a setuid helper `libexec/wifimgrsu` (pkg-plist mode 4511) checks the **root password** (wifimgrsu.c:87-96).

## Bluetooth, sleep, hibernate
Sources pinned: Caelestia shell v2.5.0 (latest tag, d999d48, github.com/caelestia-dots/shell); Quickshell v0.3.2 (4f508be, the FreeBSD port's GIT_COMMIT_HASH); freebsd-ports main 6b24a18; freebsd-src releng/15.0 (2b7df8c) and releng/15.1 (95719d8). acpi.4 and bt.c are byte-identical in 15.0 and 15.1. virtual_oss.8 differs only in the date and in a dropped CPU-tuning example; its Bluetooth examples are the same. Clones are in (local scratch clones)/. The repo was not modified.

## 1. Caelestia Bluetooth (v2.5.0)
- **The panel uses Quickshell.Bluetooth (BlueZ D-Bus), not `bluetoothctl`.** VERIFIED: `import Quickshell.Bluetooth` in `modules/bar/popouts/Bluetooth.qml:6`, `modules/bar/components/status/BluetoothStatus.qml:6`, `modules/utilities/cards/Toggles.qml:5`, plus `modules/nexus/pages/BluetoothPage.qml`. No file in the tag calls `bluetoothctl` or runs a process for Bluetooth. VERIFIED by grep.
- **With no adapter and no BlueZ, nothing is hidden and no error is shown.** VERIFIED:
  - `BluetoothStatus.qml:34-35` shows the icon `bluetooth_disabled`.
  - Toggles and switches use `Bluetooth.defaultAdapter?.enabled ?? false`, and their click handler does nothing when `adapter` is null (`Toggles.qml:94-99`, `popouts/Bluetooth.qml:31-46`, `BluetoothPage.qml:36,197,214`).
  - The popout reads "0 devices available" (`popouts/Bluetooth.qml:52-58`).
  - Result: dead controls.
- **The `bar.status.showBluetooth`/`showNetwork`/`showBattery` keys do not exist in v2.5.0.** VERIFIED in `plugin/src/Caelestia/Config/barconfig.hpp`. What exists:
  - `bar.statusIcons` is a list of `{id, enabled}`. Defaults (`barconfig.hpp:118-127`): lockStatus true, audio false, microphone false, kbLayout false, network true, bluetooth true, battery true.
  - `bar.entries` is a list (`:128-139`).
  - `bar.popouts.statusIcons` is a bool (`:29`).
  - `utilities.quickToggles` is a list (`utilitiesconfig.hpp:67-76`): wifi, bluetooth, mic, settings, gameMode, dnd true; vpn false.
  - `utilities.cards.quickToggles` is a bool (`:56`).
- **A JSON array in shell.json replaces the whole default list. It is not merged by id.** VERIFIED: `plugin/src/Caelestia/Settings/listnode.cpp:219-237` clears `m_elements` and then inserts each JSON element.
  - To hide Bluetooth, ship the full list with `{"id":"bluetooth","enabled":false}`.
  - The same rule means the repo's `general.idle.timeouts` already drops the default 600 s `suspendThenHibernate` entry.
- The network icon is driven by `nmcli` (`services/Nmcli.qml:192,1697,1705`; `StatusIcons.qml:124`). VERIFIED.

## 2. Quickshell Bluetooth module (v0.3.2, `src/bluetooth/`)
- The FreeBSD port builds this module. VERIFIED:
  - The `BLUETOOTH` option defaults to ON (`CMakeLists.txt:82`).
  - The port does not turn it off: https://raw.githubusercontent.com/freebsd/freebsd-ports/main/x11/quickshell/Makefile
  - `pkg-plist` lists `Quickshell/Bluetooth/qmldir`.
- D-Bus surface it uses. VERIFIED from `bluez.cpp`, `adapter.hpp`, `device.hpp` and the XML files:
  - System bus, `org.bluez`, ObjectManager on `/`: GetManagedObjects plus the InterfacesAdded and InterfacesRemoved signals (`bluez.cpp:45-61`).
  - Adapter1 properties: Alias, Powered (rw), PowerState, Discoverable, DiscoverableTimeout, Discovering, Pairable, PairableTimeout (`adapter.hpp:160-167`). Methods: StartDiscovery, StopDiscovery, RemoveDevice(o).
  - Device1 properties: Address, Name, Alias, Connected, Paired, Bonded, Trusted, Blocked, WakeAllowed, Icon, Adapter (`device.hpp:206-216`). Methods: Connect, Disconnect, Pair, CancelPairing.
  - `org.bluez.Battery1.Percentage` (`device.hpp:219`, `device.cpp:251`).
  - Standard org.freedesktop.DBus.Properties.
  - `defaultAdapter` is the first adapter found (`bluez.cpp:30-33`).
- No `org.bluez.Agent1` implementation exists, so pairing needs an external agent. VERIFIED: grep for "Agent" finds nothing.
- **If `org.bluez` is absent:** `setInterface` fails, a debug message "BlueZ is not running" is logged, and init returns (`bluez.cpp:61-64`; `dbus/objectmanager.cpp:35-41`). `defaultAdapter` stays null and `devices` stays empty.
  - There is no QDBusServiceWatcher in `src/dbus` or `src/bluetooth`. VERIFIED.
  - So a service that starts after Quickshell is never picked up. INFERRED.

## 3. KDE Bluetooth
- **Neither bluez-qt nor bluedevil is packaged, so Plasma has no Bluetooth applet or Bluetooth settings page at all.**
  - bluez-qt is not ported. VERIFIED: `Mk/Uses/kde.mk:312` has the comment "Not ported to FreeBSD: bluez-qt modemmanagerqt", and the KF6 list `_USE_FRAMEWORKS6_ALL` (`:330`) has no bluez-qt entry.
  - bluedevil is absent from `_USE_PLASMA6_ALL` (`:348-361`). VERIFIED.
  - The 404s on guessed port paths support this but are weak evidence on their own. https://raw.githubusercontent.com/freebsd/freebsd-ports/main/Mk/Uses/kde.mk
  - That Plasma shows no Bluetooth applet or page follows from bluedevil being missing. INFERRED.
  - A shim on `org.bluez` would also need bluez-qt and bluedevil to be ported. INFERRED.

## 4. Bluetooth audio
- **virtual_oss is in base since 15.0. The Bluetooth backend is the port `audio/virtual_oss_bluetooth`, which builds `lib/virtual_oss/voss_bt.so` from `${SRC_BASE}/lib/virtual_oss/bt`.** VERIFIED: the port Makefile, and `pkg-descr`, which says the backend "gets loaded dynamically only when a virtual_oss(8) invocation uses a bluetooth device". The `LIBAV` option adds AAC.
  - The port has no pkg-message. VERIFIED: 404.
  - The base commit message says the bluetooth and sndio backends "are built as ports, because they depend on third-party libraries" (freebsd-src releng/15.0 history of `lib/virtual_oss/Makefile`, "virtual_oss: Port to base", D52308).
- **Command lines** (`usr.sbin/virtual_oss/virtual_oss/virtual_oss.8:282-293`). VERIFIED:
  - Playback only: `virtual_oss -C 2 -c 2 -r 48000 -b 16 -s 4ms -R /dev/null -P /dev/bluetooth/xx:xx:xx:xx:xx:xx -d dsp`
  - Playback and recording: `virtual_oss -C 2 -c 2 -r 48000 -b 16 -s 4ms -f /dev/bluetooth/xx:xx:xx:xx:xx:xx -d dsp`
- **Playback to A2DP sinks (headphones) works over SBC.** VERIFIED: `lib/virtual_oss/bt/bt.c:631-650`, where `bt_play_open` uses `SDP_SERVICE_CLASS_AUDIO_SINK` and sets up the SBC encoder.
  - Recording opens `SDP_SERVICE_CLASS_AUDIO_SOURCE` (`bt.c:615-628`). VERIFIED.
  - That means it records from an A2DP source device, not a headset microphone, so HFP/HSP microphones are unsupported. INFERRED.
  - Pairing and link keys come from the base stack (`hcsecd`). INFERRED.
- `virtual_bt_speaker(8)` provides the reverse role: FreeBSD acts as a speaker, for example `virtual_bt_speaker -d /dev/dspX` (`virtual_bt_speaker.8:39-62`). VERIFIED.

## 5. Caelestia session menu (v2.5.0)
- **Keys** (`plugin/src/Caelestia/Config/sessionconfig.hpp:22-29`). VERIFIED:
  - `session.commands.logout = ["logout"]`
  - `session.commands.shutdown = ["poweroff"]`
  - `session.commands.hibernate = ["hibernate"]`
  - `session.commands.reboot = ["reboot"]`
  - Icons: `session.icons.{logout,shutdown,hibernate,reboot}` (`:13-20`).
  - `session.enabled` (`:34`).
- **The menu has four icon-only buttons and no Suspend button** (`modules/session/Content.qml:20-80`). VERIFIED.
- **Execution:** `if (!SessionManager.exec(command)) Quickshell.execDetached(command)` (`Content.qml:88-91`). VERIFIED.
  - `exec` (`plugin/src/Caelestia/Services/sessionmanager.cpp:63-94`) catches the names logout, suspend, suspendthenhibernate, hibernate, poweroff and reboot. It also catches `systemctl X`, `loginctl X` and `loginctl terminate-user ''`, after removing `-` and `_` and lowercasing.
  - Those calls go to `org.freedesktop.login1`, which does not exist on FreeBSD.
  - Commands that do not match run as plain processes. That is why the repo's `["doas","zzz"]` and `["shutdown","-p","now"]` work: they bypass login1.
- **login1 surface a shim would need.** VERIFIED from `sessionmanager.cpp`:
  - Manager at `/org/freedesktop/login1`, interface `org.freedesktop.login1.Manager`:
    - `GetSession(s "auto") -> o`
    - `Suspend(b)`, `SuspendThenHibernate(b)`, `Hibernate(b)`, `PowerOff(b)`, `Reboot(b)`
    - `CanHibernate() -> s`, where "yes" or "challenge" counts as available
    - signal `PrepareForSleep(b)`
  - Session interface `org.freedesktop.login1.Session`: `Terminate()` and the signals `Lock` and `Unlock`.
  - ConsoleKit2 has similar methods under `org.freedesktop.ConsoleKit`, which Caelestia does not use. INFERRED.
- **Problems that `session.commands` cannot fix:**
  - **Critical battery:** at `general.battery.criticalLevel` (default 3, `generalconfig.hpp:~99`), a toast says "Hibernating in 5 seconds" (`BatteryMonitor.qml:32-34`). After 5 s it calls `SessionManager.hibernate()` (`:83`). `CanHibernate` then fails and the user sees the toast "Hibernate failed / Enable hibernation to use this feature" (`sessionmanager.cpp:114-122`). VERIFIED. Setting `criticalLevel` to -1 disables this. INFERRED.
  - **Launcher "Sleep":** the action runs `["suspendThenHibernate"]` (`launcherconfig.hpp:~128-130`) and fails silently, with only a log warning. VERIFIED. The `launcher.actions` list (`:55`) can be replaced from shell.json.
  - **Lock before sleep:** `general.idle.lockBeforeSleep` locks only on login1 `PrepareForSleep` (`modules/IdleMonitors.qml:40-44`). Without login1 the screen will not lock before `doas zzz`. VERIFIED code path; INFERRED outcome on FreeBSD. This answers the open question in HANDOFF 4.5.

## 6. FreeBSD hibernate (S4)
- **S4 is not supported on FreeBSD amd64 unless the firmware offers S4BIOS, which almost no current machine does.** VERIFIED:
  - acpi(4), `share/man/man4/acpi.4:183-190` (15.0 = 15.1): "S4 Suspend to disk ... Not yet supported by FreeBSD unless S4BIOS is available."
  - `hw.acpi.s4bios` (`:145-153`): "Most current systems do not support S4BIOS."
  - Kernel comment in `sys/dev/acpica/acpi.c`: "Currently we support S1-S5 but S4 is only S4BIOS" (15.0 `:3345`, 15.1 `:3355`).
  - Handbook, freebsd-doc `documentation/content/en/books/handbook/config/_index.adoc:1459-1486`: "S4 (Hibernation) ... *Not yet supported by FreeBSD*" and "FreeBSD does *not* yet support the S4 state."
- acpiconf(8) `-s 4` is described as storing memory to disk, but "the supported states depend on BIOS implementation" (`acpiconf.8:55-70`). VERIFIED.
- zzz(8) runs `acpiconf -s $(sysctl hw.acpi.suspend_state)` (`usr.sbin/zzz/zzz.sh:13,28`). That state is S3 by default, so the repo's "hibernate" set to `doas zzz` really suspends to RAM. VERIFIED script; the S3 default is INFERRED.
- **Recommendation:** hide hibernate everywhere.

## KDE System Monitor, sensors, Discover
KDE System Monitor, sensors and Discover on FreeBSD (research, nothing run on FreeBSD)

Sources: KDE tag v6.8.3 for ksystemstats `3ec94520`, libksysguard `05c5f30f`, plasma-systemmonitor `332601e4` and discover `fcf8a820`. Also freebsd-ports `6b24a183` (KDE_PLASMA6_VERSION=6.8.3, KF6 6.31.0 in Mk/Uses/kde.mk:124,136), PackageKit v1.4.0 `16c3c84a`, pkg-appstream v1.0.4 `b1bc5edb`, solid v6.31.0, and freebsd-src releng/15.0. KDE links use the form https://invent.kde.org/plasma/<repo>/-/blob/v6.8.3/<path>. Clones are in (local scratch clones)/

## 1. Which ksystemstats plugins are built

- **Upstream build rules** (plugins/CMakeLists.txt#L8-L25): osinfo, network, power, disks, cpu and memory are always built. pressure is Linux-only. gpu needs UDev or Devinfo. lmsensors needs SENSORS_FOUND, and the top-level CMakeLists.txt#L57-L58 only looks for Sensors on Linux. **VERIFIED**
- **What the port installs** (sysutils/plasma6-ksystemstats/pkg-plist L3-L9): cpu, disk, gpu, memory, network, osinfo, power. No lmsensors, no pressure. The port builds without NetworkManagerQt (Makefile L16) and patches only the network SysctlBackend getifaddrs leak (files/patch-network). **VERIFIED**
- **CPU**: on FreeBSD it uses freebsdcpuplugin.cpp (plugins/cpu/CMakeLists.txt#L8-L9). Usage comes from `kern.cp_times`. Frequency comes from `dev.cpu.N.freq` and `.freq_levels`. Temperature comes from `dev.cpu.N.temperature`, deci-Kelvin converted to °C (freebsdcpuplugin.cpp#L79-L84), with the maximum from `dev.cpu.N.coretemp.tjmax` (#L113-L118). The "wait" value is always 0 (#L123). **VERIFIED**
- **Memory**: freebsdbackend.cpp, linked with kvm (plugins/memory/CMakeLists.txt#L1-L9). **VERIFIED**
- **Network**: SysctlBackend.cpp. **VERIFIED**
- **GPU**: the FreeBSD backend finds a card only when its devinfo driver name is `"nvidia"` (plugins/gpu/FreeBSDBackend.cpp#L50). Data comes from `nvidia-smi` (FreeBSDNvidiaGpu and NvidiaSmiProcess); x11/nvidia-driver/pkg-plist L3 ships `bin/nvidia-smi`. **Intel and AMD GPUs never appear**, so on the owner's hybrid laptop only the NVIDIA card shows. **VERIFIED**
- **Disks**: volumes are listed through Solid (disks.cpp#L166). Read/write rates come from geom devstat, matched by `/dev/<provider>` (#L388-L405). Solid on FreeBSD builds the fstab, upower and udisks2 backends (solid v6.31.0 CMakeLists.txt#L139-L147, **VERIFIED**). kf6-solid needs `bsdisks` at run time, and the repo already installs and enables it (stages/desktop.sh:19-20). **INFERRED**: ZFS datasets are not geom providers, so read/write rates for ZFS volumes are probably missing. Whether bsdisks reports ZFS datasets at all still has to be checked on the machine.
- **Power**: batteries are listed through Solid's UPower backend (power.cpp#L117). It works only if upowerd runs (**INFERRED**).
- **Expected missing on FreeBSD**:
  - fans, ACPI thermal zones (`hw.acpi.thermal.tz*`), and every other hwmon-style sensor, because the lmsensors plugin is not built
  - GPU temperature and usage for Intel and AMD
  - CPU "wait"
  - memory pressure (PSI)

## 2. Processes page and Applications page

- **Processes**: processes_local_p.cpp#L9-L10 includes processes_freebsd_p.cpp on FreeBSD. That backend reads `sysctl` KERN_PROC_PID, KERN_PROC_ARGS and KERN_PROC_ALL (#L53, #L128, #L185). It does not use /proc, so the hint in HANDOFF 4.4 to check that /proc is mounted is irrelevant. **VERIFIED**
- Per-process network usage (libpcap plugin) is inside a Linux-only block (libksysguard CMakeLists.txt#L53-L70). **VERIFIED**
- **Applications page**:
  - `ApplicationDataModel` uses root `/user.slice/user-UID.slice/user@UID.service` (processcore/application_data_model.cpp#L20).
  - `CGroupSystemInformation` takes `/sys/fs/cgroup[/unified]` as the base path (cgroup.cpp#L228-L237).
  - `CGroupDataModel::setRoot` sets `available = QFile::exists(base + root)` (cgroup_data_model.cpp#L379-L390), and `isAvailable()` returns that (#L484).
  - The page then shows "Applications view is unsupported on your system" when `!appModel.available` (src/faces/applicationstable/contents/ui/ApplicationsTableView.qml#L26-L30) and logs a "systemd.io/DESKTOP_ENVIRONMENTS" error (#L224).
  - On FreeBSD this can never be true. A shim would need a fake cgroupfs. **VERIFIED**
- The port's libksysguard patch (patch-processcore_cgroup__data__model.cpp) only moves a timer `setInterval` call. **VERIFIED**

## 3. CPU temperature

- The code path already exists (see section 1).
  - coretemp adds `dev.cpu.N.temperature` and `dev.cpu.N.coretemp.tjmax`, both "IK" (coretemp.c L280-L295). **VERIFIED**
  - amdtemp adds `dev.cpu.N.temperature` for N below sc_ncores (amdtemp.c L625-L645). **VERIFIED**
  - The repo already loads both modules (stages/drivers.sh:11,15). **VERIFIED**
  - So `cpu/cpuN/temperature` and `cpu/all/{maximum,minimum,average}Temperature` (cpu.cpp#L140-L158) should work. **INFERRED**: not yet tested on hardware.
- **Why it can look broken**:
  - The sensor is created with value 0 (freebsdcpuplugin.cpp#L81), and `SysctlSensor::update()` calls `setValue` only when `sysctlbyname` succeeds (libksysguard systemstats/SysctlSensor.h#L95-L96).
  - So **if the sysctl is missing (module not loaded, or the CPU is not covered), it shows 0 °C instead of disappearing**. **VERIFIED**
  - On AMD, which CPUs get a sysctl depends on `sc_ncores` = CPUID cores+1 (amdtemp.c L521). **INFERRED** that this covers every logical CPU.
- **The cleanest way to add more sensors** (ACPI thermal zones, fans, NVMe, i915/amdgpu temperatures) is our own out-of-tree ksystemstats plugin:
  - The daemon loads plugins with `KPluginMetaData::findPlugins("ksystemstats")` (src/daemon.cpp#L95), so a .so in `/usr/local/lib/qt6/plugins/ksystemstats/` is picked up. **VERIFIED** for the call; the path is **INFERRED** from %%QT_PLUGINDIR%%.
  - The SDK headers (SensorPlugin.h, SysctlSensor.h) and the KSysGuard CMake config are packaged (plasma6-libksysguard pkg-plist L34-L44). **VERIFIED**
  - Downside: it is C++ and has to be compiled.
- Re-enabling the upstream lmsensors plugin against `caelestia/libsensors-shim` would mean rebuilding ksystemstats itself, because of the Linux-only `find_package(Sensors)` gate. That makes it a worse fit.

## 4. Plasma System Monitor pages

- **Where the pages are**: CMake installs `{applications,history,overview,processes,old-history,old-overview}.page` into `${DATADIR}/plasma-systemmonitor` (src/CMakeLists.txt#L51-L58). The port puts them in `/usr/local/share/plasma-systemmonitor/` (pkg-plist L226-L231). **VERIFIED**
- **How they load**:
  - PageManager scans every `QStandardPaths::AppDataLocation` directory in reverse order. For the same file name the most local copy wins, so `~/.local/share/plasma-systemmonitor/X.page` overrides the system copy (src/page/PageManager.cpp#L109-L135, #L158-L193). **VERIFIED**
  - A page's `[page] version=` decides whether a copy is marked "outdated" (#L179-L183). **VERIFIED**
- **How to hide the Applications page**:
  - The setting is `hiddenPages` (a StringList) in group `[General]` of `systemmonitorrc` (src/page/systemmonitor.kcfg#L18-L26). Next to it are `pageOrder` (default `overview.page,applications.page,history.page,processes.page`) and `startPage`. **VERIFIED**
  - The sidebar uses `visible: !model.hidden` (Main.qml#L197) and `PageController::isHidden` (PageController.cpp#L54-L56). **VERIFIED**
  - Ship it as a system-wide default `[General] hiddenPages=applications.page` in `/usr/local/etc/xdg/systemmonitorrc`. **INFERRED**: that this is in XDG_CONFIG_DIRS on FreeBSD; check it.
- **Catch: the Overview page also contains an Applications card.** overview.page has `chartFace=org.kde.ksysguard.applicationstable` (Face-108592549200736, line 295; listed in the layout at L551), so it would show "unsupported" there too. **VERIFIED**
  - Fix: ship a modified `overview.page` (same name, `version=1`) in a data directory placed before `/usr/local/share` in XDG_DATA_DIRS, or copy it into each user's `~/.local/share/plasma-systemmonitor/`.
  - Do not edit the packaged files, because package upgrades replace them.

## 5. Discover on FreeBSD

- **Backends built**: the port (sysutils/plasma6-discover Makefile L9-L13) hard-depends on appstream-qt, packagekit-qt and PackageKit. pkg-plist L6-L9 installs only `packagekit-backend.so`, `kns-backend.so`, `appstream-preview-backend.so` and `DiscoverPackageKitNotifier.so`. **VERIFIED**
- **No Flatpak, fwupd or Snap backend.** Upstream detects these automatically (libdiscover/backends/CMakeLists.txt#L53-L85). There is no flatpak port in the tree (checked by listing the tree). `sysutils/fwupd` exists, but the Discover pkg-plist has no fwupd backend. **VERIFIED**
- **PackageKit port** (ports-mgmt/packagekit, version 1.4.0):
  - Meson options: `-Dpackaging_backend=freebsd -Dsystemd=false -Doffline_update=false` (L35-L38).
  - Installs `lib/packagekit-backend/libpk_backend_freebsd.so`, the system D-Bus service `org.freedesktop.PackageKit` and a polkit rule (pkg-plist).
  - Needs consolekit2 at run time.
  - Its port patch sets `pkg_set_ignore_osversion(TRUE)`.
  - **VERIFIED**
- **Gaps in the PackageKit FreeBSD backend** (backends/freebsd/pk-backend-freebsd.cpp, L557, L601, L919, L926, L1264, L1273, L1401):
  - `get_files`, `get_files_local`, `install_signature`, `install_files`, `repo_set_data`, `what_provides` and `repair_system` just call `g_error()`, which aborts the process. **VERIFIED**
  - Discover calls `getFilesLocal` when it opens a local package file (LocalFilePKResource.cpp#L59). **VERIFIED** for the call path; that it crashes packagekitd is **INFERRED**.
  - The upstream polkit rule lets `wheel` members run updates without a password, only for system-update and offline-update actions (data/policy/org.freedesktop.packagekit.rules). **VERIFIED**
- **No application catalogue**:
  - Discover builds its application list from an AppStream pool (PackageKitBackend.cpp#L326-L389).
  - `ports-mgmt/pkg-appstream` (not a dependency of either port) is a libpkg plugin that downloads `AppStreamComponents.xml.gz` from the repository root into `/var/lib/swcatalog/xml/<repo>-Components.xml.gz`. It has to be listed in `PLUGINS` in pkg.conf (pkg-appstream README; appstream.c L16-L50). **VERIFIED**
  - On 2026-11-16, `https://pkg.freebsd.org/FreeBSD:15:amd64/{latest,quarterly}/AppStreamComponents.xml.gz` returned HTTP 404. The repo root lists only data.pkg, meta, meta.conf and packagesite.pkg. **VERIFIED**
  - **INFERRED**: Discover's application browsing will be empty or almost empty, and only updates and KNS add-ons would be useful. The fix would be to serve our own AppStream catalogue (`ports-mgmt/appstream-generator` exists) or to hide Discover's browse pages.

**Nothing here was run on FreeBSD.** Every claim comes from reading source code. What to check first on the laptop:
1. `sysctl dev.cpu | grep temperature`
2. `kstatsviewer --list | grep -E 'temperature|disk|gpu'`
3. `pkg info -l PackageKit`
4. whether `upowerd` and `bsdisks` are running
