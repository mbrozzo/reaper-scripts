local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local reautils = require("reautils")
local background = require("background")
local vzoom = require("vzoom")

local function handle_tcp_ctrl_mousewheel(callback)
	callback = callback or function() end
	local tcp = reautils.tcp.get_hwnd()
	if reaper.JS_WindowMessage_Intercept(tcp, "WM_MOUSEWHEEL", false) ~= 1 then
		reaper.ShowMessageBox("Failed to disable TCP Ctrl+Mousewheel zoom.", "Error", 0)
		return
	end
	local prev_time = 0
	background.loop(
		function()
			-- If not only Ctrl is pressed, pass the message through
			local success, passed_through, time, keys, rotate, x, y = reaper.JS_WindowMessage_Peek(tcp, "WM_MOUSEWHEEL")
			if not success then
				reaper.ShowMessageBox("Failed to get TCP Ctrl+Mousewheel zoom message.", "Error", 0)
				return
			end
			if time <= prev_time then
				-- No new mousewheel events
				return
			end
			-- If only ctrl is pressed
			if reaper.JS_Mouse_GetState(60) == 4 then -- Modifier keys bitmask: 0b00111100 = 60; only ctrl pressed: 0b00000100 = 4
				callback(passed_through, time, keys, rotate, x, y)
			else
				-- Pass the message through
				reaper.JS_WindowMessage_Post(tcp, "WM_MOUSEWHEEL", keys, rotate, x, y)
			end
			prev_time = time
		end,
		function()
			reaper.JS_WindowMessage_Release(tcp, "WM_MOUSEWHEEL")
		end,
		true
	)
end

local function main()
	handle_tcp_ctrl_mousewheel(function(_, _, _, rotate, _, _)
		vzoom.zoom_proportionally(function()
			local vzoom_limit_func, vzoom_limit
			if rotate > 0 then
				vzoom_limit_func = math.min
				vzoom_limit = vzoom.get_max_vzoom()
			else
				vzoom_limit_func = math.max
				vzoom_limit = 0
			end
			local new_vzoom = reaper.SNM_GetDoubleConfigVar("vzoom3", -1) + rotate / 120
			reaper.SNM_SetDoubleConfigVar("vzoom3", vzoom_limit_func(new_vzoom, vzoom_limit))
		end)
	end)
end

reaper.set_action_options(1) -- Terminate if run while other instance is running
main()