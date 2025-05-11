local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local background = require("background")
local vzoom = require("vzoom")

local function main()
	background.loop(
		vzoom.update_track_height_lock_indicators,
		function ()
			reaper.ShowConsoleMsg("The script to update track height lock indicators exited.")
		end,
		true
	)
end

main()