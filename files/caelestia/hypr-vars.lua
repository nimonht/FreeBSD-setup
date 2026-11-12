-- ~/.config/caelestia/hypr-vars.lua - variable overrides for the Caelestia
-- Hyprland config (see ~/.config/hypr/variables.lua for everything you can
-- set). Installed by FreeBSD-setup; yours to edit, never overwritten.
return {
  -- Apps (FreeBSD package names / binaries)
  terminal        = "foot",
  browser         = "firefox",
  editor          = "foot nvim",
  fileExplorer    = "thunar",
  audioSettings   = "pavucontrol",

  -- Cursor theme shipped by x11-themes/bibata-cursor-theme
  cursorTheme     = "Bibata-Modern-Classic",
  cursorSize      = 24,

  -- systemd is Linux-only: suspend through ACPI instead
  sleepGestureCmd = "doas zzz",
}
