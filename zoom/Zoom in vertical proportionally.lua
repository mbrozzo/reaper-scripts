local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local vzoom = require("vzoom")

function main()
	vzoom.zoom_proportionally(function()
		reaper.SNM_SetDoubleConfigVar("vzoom3", math.min(reaper.SNM_GetDoubleConfigVar("vzoom3", -1) + 1, vzoom.get_max_vzoom()))
	end)
end

reaper.defer(main)
