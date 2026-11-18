# Written by FreeBSD-setup: makes Caelestia's fastfetch box work on FreeBSD.
# Applied to ~/.config/fastfetch/config.jsonc after the dotfiles are copied:
# the rows that call Linux-only commands (uptime -p, free, hostnamectl) use
# fastfetch's own modules or FreeBSD commands instead, and the distro row
# reads /etc/os-release itself (fastfetch looks for it elsewhere).
.modules |= map(
  if type != "object" then .
  elif .type == "command" and (.text | test("uptime -p")) then
    { type: "uptime", key: .key, format: "{formatted>22} │" }
  elif .type == "command" and (.text | test("free -m")) then
    { type: "memory", key: .key, format: "{$3}{used>10} / {total>9}{$1} │" }
  elif .type == "command" and (.text | test("hostnamectl")) then
    .text = "hostname -s"
  elif .type == "os" then
    { type: "command", key: .key, text: ". /etc/os-release && echo \"$NAME $VERSION_ID\"", format: "{$4}{>22}{$1} │" }
  else . end
)
