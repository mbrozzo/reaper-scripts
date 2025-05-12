local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local vzoom = require("vzoom")

function main()
	local is_new_value, filename, sectionID, cmdID, mode, resolution, val = reaper.get_action_context()
	if (mode <= 0 or val == 0) then return end

	vzoom.zoom_proportionally(function()
		local vzoom_limit_func, vzoom_limit
		if val > 0 then
			vzoom_limit_func = math.min
			vzoom_limit = vzoom.get_max_vzoom()
		else
			vzoom_limit_func = math.max
			vzoom_limit = 0
		end
		local new_vzoom = reaper.SNM_GetDoubleConfigVar("vzoom3", -1) + val / 15
		reaper.SNM_SetDoubleConfigVar("vzoom3", vzoom_limit_func(new_vzoom, vzoom_limit))
	end)
end

reaper.defer(main)
