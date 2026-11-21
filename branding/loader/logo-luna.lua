--
-- Written by FreeBSD-setup: the LunaBSD mark next to the boot menu
-- (loader_logo="luna" in /boot/loader.conf). Text from branding/make-art.py;
-- on framebuffer consoles the loader draws the picture instead.
--
local color = require("color")
local drawer = require("drawer")

local m = color.escapefg(color.YELLOW)
local d = color.resetfg()

drawer.addLogo("luna", {
	ascii = {
		image = {
			"           " .. "........",
			"       " .. "..'''      '''..",
			"     " .. ".:'  " .. m .. ",,\"          " .. d .. "...",
			"    " .. ":'  " .. m .. ",##\"           " .. d .. "'''",
			"   " .. ":  " .. m .. ",###\"               " .. d .. ":",
			"  " .. ":' " .. m .. ",####                " .. d .. "':",
			"  " .. ":  " .. m .. "######                " .. d .. ":",
			"  " .. ":  " .. m .. "######,               " .. d .. ":",
			"  " .. ":. " .. m .. "\"#######,            " .. d .. ".:",
			"   " .. ":  " .. m .. "\"########,,,,,,,,\"  " .. d .. ":",
			"    " .. ":.  " .. m .. "\"############\"  " .. d .. ".:",
			"     " .. "':.  " .. m .. "\"\"######\"\"  " .. d .. ".:'",
			"       " .. "''...      ...''",
			"           " .. "''''''''",
		},
		requires_color = true,
		shift = {x = 0, y = 0},
	},
	fb = {
		image = "/boot/images/lunabsd-logo.png",
		width = 14,
	},
})
