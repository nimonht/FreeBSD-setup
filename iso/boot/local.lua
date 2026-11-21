--
-- /boot/lua/local.lua of the LunaBSD live media: a "Troubleshooting"
-- submenu in the boot menu (key T) for computers where the normal start
-- does not work. Each entry sets a variable that the live system reads
-- (iso/live/luna_live) and starts.
--

local color = require("color")
local core = require("core")
local menu = require("menu")

local function start_with(var)
	loader.setenv(var, "1")
	core.boot()
end

menu.luna_troubleshooting = {
	entries = {
		{
			entry_type = core.MENU_RETURN,
			name = "Back to main menu" .. color.highlight(" [Backspace]"),
		},
		{
			entry_type = core.MENU_ENTRY,
			name = "Start with " .. color.highlight("b") ..
			    "asic graphics (black screen or freeze?)",
			func = function() start_with("luna.basic_graphics") end,
			alias = {"b", "B"},
		},
		{
			entry_type = core.MENU_ENTRY,
			name = "Start the " .. color.highlight("t") ..
			    "ext-mode installer (no graphics at all)",
			func = function() start_with("luna.text_installer") end,
			alias = {"t", "T"},
		},
	},
}

menu.welcome.all_entries.vendor = {
	entry_type = core.MENU_SUBMENU,
	name = color.highlight("T") .. "roubleshooting",
	submenu = menu.luna_troubleshooting,
	alias = {"t", "T"},
}
