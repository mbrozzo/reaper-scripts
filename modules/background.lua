local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local reautils = require("reautils")

local background = {}

function background.loop(main_function, atexit_function, update_button_state)
	if not main_function then return end
	if update_button_state then reautils.set_button_state(1) end
	local main
	main = function ()
		main_function()
		reaper.defer(main)
	end
	reaper.defer(main)
	reaper.atexit(function()
		if atexit_function then
			atexit_function()
		end
		if update_button_state then reautils.set_button_state(0) end
	end)
end

return background
