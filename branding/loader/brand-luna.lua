--
-- Written by FreeBSD-setup: the LunaBSD name in the boot menu
-- (loader_brand="luna" in /boot/loader.conf). On framebuffer consoles the
-- loader draws the picture instead (branding/make-art.py draws it).
--
local drawer = require("drawer")

drawer.addBrand("luna", {
	ascii = {
		image = {
"|     .   . ,   . ,---.     ,---. ,---. ,--.",
"|     |   | |\\  | |---|     |---. `---. |   |",
"|     |   | | \\ | |   |     |   |     | |   |",
"`---' `---' `  `' `   '     `---' `---' `--'",
		},
	},
	fb = {
		image = "/boot/images/lunabsd-brand.png",
	},
})
