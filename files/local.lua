--
-- /boot/lua/local.lua - written by FreeBSD-setup.
--
-- Adds the computer's other operating system to FreeBSD's boot menu
-- (press L). /boot/loader.conf names the boot loader to start:
--   fbs_chain_path="/EFI/Microsoft/Boot/bootmgfw.efi"
--   fbs_chain_name="Windows Boot Manager"
-- The partition holding it is looked up at every boot, so the entry keeps
-- working when disks are added or renumbered.
--

local color = require("color")
local menu = require("menu")

local path = loader.getenv("fbs_chain_path")
if path ~= nil and loader.getenv("chain_disk") == nil then
	local found = nil
	for d = 0, 3 do
		for p = 1, 12 do
			local candidate = "disk" .. d .. "p" .. p .. ":" .. path
			local fd = io.open(candidate)
			if fd ~= nil then
				io.close(fd)
				found = candidate
				break
			end
		end
		if found ~= nil then
			break
		end
	end
	if found ~= nil then
		loader.setenv("chain_disk", found)
	end
end

local name = loader.getenv("fbs_chain_name")
if name ~= nil and menu.welcome ~= nil and menu.welcome.all_entries ~= nil and
    menu.welcome.all_entries.chainload ~= nil then
	menu.welcome.all_entries.chainload.name = function()
		return "Start " .. name .. " (" .. color.highlight("L") .. ")"
	end
end
