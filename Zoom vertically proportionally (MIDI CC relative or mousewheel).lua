local script_path = debug.getinfo (1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. 'modules/?.lua;' .. package.path;
local vzoom = require("vzoom")

function main()
	local is_new_value, filename, sectionID, cmdID, mode, resolution, val = reaper.get_action_context()
	if (mode <= 0 or val == 0) then return end

	vzoom.zoom_vertically_preserving_track_heights(val / resolution, 0)
end

reaper.defer(main)
