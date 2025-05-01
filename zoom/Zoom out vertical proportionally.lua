local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local vzoom = require("vzoom")

function main()
	vzoom.zoom_proportionally(function()
		reaper.SNM_SetDoubleConfigVar("vzoom3", math.max(reaper.SNM_GetDoubleConfigVar("vzoom3", -1) - 1, 0))
		reaper.TrackList_AdjustWindows(true)
	end)
end

reaper.defer(main)
