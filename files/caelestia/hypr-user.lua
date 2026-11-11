-- ~/.config/caelestia/hypr-user.lua - loaded last by the Caelestia Hyprland
-- config. Installed by FreeBSD-setup; yours to edit, never overwritten.

-- Qt theming: "qtengine" does not exist on FreeBSD, qt6ct does.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")

-- Laptop panel + anything plugged in. List outputs with: hyprctl monitors
-- hl.monitor({ output = "eDP-1",    mode = "1920x1080@60", position = "0x0",    scale = 1 })
-- hl.monitor({ output = "HDMI-A-1", mode = "preferred",    position = "1920x0", scale = 1 })

hl.on("hyprland.start", function()
    -- Upstream starts these from Linux paths that do not exist here.
    hl.exec_cmd("/usr/local/libexec/polkit-gnome-authentication-agent-1")
    -- Audio (no systemd user session on FreeBSD); harmless if already running.
    hl.exec_cmd("start-pipewire")
end)
