local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local vzoom = require("vzoom")

function main()
	vzoom.zoom_proportionally(function()
		reaper.Main_OnCommand(vzoom.ZOOM_OUT_COMMAND_ID, 0)
	end)
end

reaper.defer(main)
