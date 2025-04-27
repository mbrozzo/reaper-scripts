local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local background = require("background")
local vzoom = require("vzoom")

ENABLE_RELATIVE_GRID_SNAP_COMMAND = 41052

local function print_update_track_height_lock_indicators_error(message)
	reaper.ShowConsoleMsg(
		"Error: the script to update track height lock indicators exited unexpectedly\n"
	)
end

local function main()
	reaper.Main_OnCommand(ENABLE_RELATIVE_GRID_SNAP_COMMAND, 0)
	background.run(
		vzoom.update_track_height_lock_indicators,
		print_update_track_height_lock_indicators_error,
		true
	)
end

main()
