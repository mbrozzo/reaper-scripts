local script_path = debug.getinfo(1, 'S').source:match [[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local background = require("background")
local vzoom = require("vzoom")
local ru = require("reautils")

local function main()
	local w = ru.tcp.get_width()
	local h = ru.tcp.get_height()
	local tcp_hwnd = ru.tcp.get_hwnd()
	local bitmap = reaper.JS_LICE_CreateBitmap(true, w, h)
	reaper.JS_Composite(tcp_hwnd, 0, 0, w, h, bitmap, 0, 0, w, h)
	reaper.JS_Composite_Delay(tcp_hwnd, 0.1, 0.1, 1)
	local locked_color =  ru.drawing.theme_color_to_rgb(reaper.GetThemeColor("col_cursor", 0))
	background.loop(
		function()
			reaper.JS_LICE_Line(bitmap,
				w - 1, 0,
				w - 1, h - 1,
				0x00000000, 1, "COPY", false)
			for _, track in ipairs(ru.track.get_all(true)) do
				if ru.track.is_visible(track) then
					local lock_state = reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
					if lock_state == 1 then
						local tcp_y = reaper.GetMediaTrackInfo_Value(track, "I_TCPY")
						local tcp_h = reaper.GetMediaTrackInfo_Value(track, "I_TCPH")
						reaper.JS_LICE_Line(bitmap,
							w - 1, tcp_y,
							w - 1, tcp_y + tcp_h - 1,
							locked_color,
							1, "COPY", false)
					end
				end
			end
			reaper.JS_Window_InvalidateRect(tcp_hwnd, w - 1, 0, w, h, false)
		end,
		function()
			reaper.JS_Composite_Unlink(tcp_hwnd, bitmap)
			reaper.JS_LICE_DestroyBitmap(bitmap)
			reaper.JS_Window_InvalidateRect(tcp_hwnd, w - 1, 0, w, h, false)
		end,
		true
	)
end

reaper.set_action_options(1) -- Terminate if run while other instance is running
main()
