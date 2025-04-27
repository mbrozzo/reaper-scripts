local script_path = debug.getinfo (1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. 'modules/?.lua;' .. package.path;
local vzoom = require("vzoom")

function main()
	vzoom.zoom_vertically_preserving_track_heights(1.1, 0)
end

reaper.defer(main)
