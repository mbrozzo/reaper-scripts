local script_path = debug.getinfo (1, 'S').source:match[[^@?(.*[\/])[^\/]-$]]
package.path = script_path .. '../modules/?.lua;' .. package.path;
local background = require("background")

local function set_track_height_lock_indicator(track, lock_state)
	local success, track_name = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
	if not success then
		return
	end
	if lock_state == 0 then
		if track_name:find("^🔒 ") then
			reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_name:gsub("^🔒 ", ""), true)
		end
	else
		if not track_name:find("^🔒 ") then
			reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "🔒 " .. track_name, true)
		end
	end
end

local function update_track_height_lock_indicator()
	for i = 0, reaper.CountSelectedTracks2(0, true) - 1 do
		local track = reaper.GetSelectedTrack2(0, i, true)
		local lock_state = reaper.GetMediaTrackInfo_Value(track, "B_HEIGHTLOCK")
		set_track_height_lock_indicator(track, lock_state)
	end
end

local function print_error_message(message)
	reaper.ShowConsoleMsg("Error: the script to update track height lock indicators exited unexpectedly\n")
end

local function main()
	background.run(update_track_height_lock_indicator, print_error_message)
end

main()
