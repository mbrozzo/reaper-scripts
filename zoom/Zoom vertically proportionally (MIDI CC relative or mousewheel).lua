local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local vzoom = require("vzoom")

function main()
	local is_new_value, filename, sectionID, cmdID, mode, resolution, val = reaper.get_action_context()
	if (mode <= 0 or val == 0) then return end

	vzoom.zoom_proportionally(function()
		if val > 0 then
			reaper.SNM_SetDoubleConfigVar("vzoom3", math.min(reaper.SNM_GetDoubleConfigVar("vzoom3", -1) + 1, vzoom.MAX_VZOOM))
		else
			reaper.SNM_SetDoubleConfigVar("vzoom3", math.max(reaper.SNM_GetDoubleConfigVar("vzoom3", -1) - 1, 0))
		end
	end)
end

reaper.defer(main)
