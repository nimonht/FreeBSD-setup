--
-- Written by FreeBSD-setup: the LumenBSD sunrise next to the boot menu
-- (loader_logo="lumen" in /boot/loader.conf).
--
local color = require("color")
local drawer = require("drawer")

local y = color.escapefg(color.YELLOW)
local r = color.escapefg(color.RED)
local d = color.resetfg()

drawer.addLogo("lumen", {
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
