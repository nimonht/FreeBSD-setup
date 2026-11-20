--
-- Written by FreeBSD-setup: the LunaBSD name in the boot menu
-- (loader_brand="luna" in /boot/loader.conf).
--
local drawer = require("drawer")

drawer.addBrand("luna", {
	ascii = {
		image = {
"  _                                ____   _____ _____  ",
" | |                              |  _ \\ / ____|  __ \\ ",
" | |    _   _ _ __ ___   ___ _ __ | |_) | (___ | |  | |",
" | |   | | | | '_ ` _ \\ / _ \\ '_ \\|  _ < \\___ \\| |  | |",
" | |___| |_| | | | | | |  __/ | | | |_) |____) | |__| |",
" |______\\__,_|_| |_| |_|\\___|_| |_|____/|_____/|_____/ ",
		},
	},
})
