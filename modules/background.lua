local background = {}

-- Set ToolBar Button State
local function set_button_state(set)
	local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
	reaper.SetToggleCommandState(sec, cmd, set or 0)
	reaper.RefreshToolbar2(sec, cmd)
end

function background.run(main_function, atexit_function)
	if not main_function then return end
	set_button_state(1)
	local main = function ()
		main_function()
		reaper.defer(main)
	end
	main()
	reaper.atexit(function()
		if atexit_function then
			atexit_function()
		end
		set_button_state(0)
	end)
end

return background
