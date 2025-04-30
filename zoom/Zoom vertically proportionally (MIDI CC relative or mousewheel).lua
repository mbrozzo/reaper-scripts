local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local vzoom = require("vzoom")

function main()
	local is_new_value, filename, sectionID, cmdID, mode, resolution, val = reaper.get_action_context()
	if (mode <= 0 or val == 0) then return end

	local command_id
	if val > 0 then
		command_id = vzoom.ZOOM_IN_COMMAND_ID
	else
		command_id = vzoom.ZOOM_OUT_COMMAND_ID
	end
	vzoom.zoom_proportionally(function()
		reaper.Main_OnCommand(command_id, 0)
	end)
end

reaper.defer(main)
