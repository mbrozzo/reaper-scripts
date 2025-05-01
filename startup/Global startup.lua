local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local background = require("background")
local vzoom = require("vzoom")

ENABLE_RELATIVE_GRID_SNAP_COMMAND = 41052

local function print_update_track_height_lock_indicators_error()
	reaper.ShowMessageBox(
		"The script to update track height lock indicators exited.",
		"Warning", 0
	)
end

local function main()
	vzoom.handle_tcp_ctrl_mousewheel(function(_, _, _, rotate, _, _)
		vzoom.zoom_proportionally(function()
			if rotate > 0 then
				reaper.SNM_SetDoubleConfigVar("vzoom3",
				math.min(reaper.SNM_GetDoubleConfigVar("vzoom3", -1) + 1, vzoom.MAX_VZOOM))
			else
				reaper.SNM_SetDoubleConfigVar("vzoom3", math.max(reaper.SNM_GetDoubleConfigVar("vzoom3", -1) - 1, 0))
			end
		end)
	end)
	reaper.Main_OnCommand(ENABLE_RELATIVE_GRID_SNAP_COMMAND, 0)
	background.loop(
		vzoom.update_track_height_lock_indicators,
		print_update_track_height_lock_indicators_error,
		false
	)
end

main()
