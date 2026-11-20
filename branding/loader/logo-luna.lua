--
-- Written by FreeBSD-setup: the LunaBSD sunrise next to the boot menu
-- (loader_logo="luna" in /boot/loader.conf).
--
local color = require("color")
local drawer = require("drawer")

local y = color.escapefg(color.YELLOW)
local r = color.escapefg(color.RED)
local d = color.resetfg()

drawer.addLogo("luna", {
	ascii = {
		image = {
y .. "          \\    |    /" .. d,
y .. "      \\    \\   |   /    /" .. d,
y .. "           .-'''''''-." .. d,
y .. "  ---    .'           '.    ---" .. d,
y .. "        /               \\" .. d,
y .. "       |                 |" .. d,
r .. "   ==============================" .. d,
r .. "        =====================" .. d,
r .. "             ===========" .. d,
		},
		requires_color = true,
		shift = {x = 0, y = 2},
	},
})
